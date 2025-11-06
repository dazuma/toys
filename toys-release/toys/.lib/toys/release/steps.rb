# frozen_string_literal: true

require "fileutils"

module Toys
  module Release
    ##
    # A namespace for steps that can be used in a pipeline
    #
    module Steps
      ##
      # Entrypoint for running a step.
      #
      # @param type [String] Name of the step class
      # @param name [String,nil] An optional unique name for the step
      # @param options [Hash{String=>String}] Options to pass to the step
      # @param repository [Toys::Release::Repository]
      # @param component [Toys::Release::Component] The component to release
      # @param version [Gem::Version] The version to release
      # @param artifact_dir [Toys::Release::ArtifactDir]
      # @param dry_run [boolean] Whether to do a dry run release
      # @param git_remote [String] The git remote to push gh-pages to
      #
      # @return [:continue] if the step finished and the next step should run
      # @return [:abort] if the pipeline should be aborted
      #
      def self.run(type:, name:, options:,
                   repository:, component:, version:, performer_result:,
                   artifact_dir:, dry_run:, git_remote:)
        step_class = nil
        begin
          step_class = const_get(type)
        rescue ::NameError
          repository.utils.error("Unknown step type: #{type}")
          return
        end
        step = step_class.new(repository: repository, component: component, version: version,
                              artifact_dir: artifact_dir, dry_run: dry_run, git_remote: git_remote,
                              name: name, options: options, performer_result: performer_result)
        begin
          step.run
          :continue
        rescue StepExit
          :continue
        rescue AbortingExit
          :abort
        end
      end

      ##
      # Internal exception signaling that the step should end immediately but
      # the pipeline should continue.
      # @private
      #
      class StepExit < ::StandardError
      end

      ##
      # Internal exception signaling that the step should end immediately and
      # the pipeline should be aborted.
      # @private
      #
      class AbortingExit < ::StandardError
      end

      ##
      # Base class for steps
      #
      class Base
        ##
        # Construct a base step.
        # @private
        #
        def initialize(repository:, component:, version:, performer_result:,
                       artifact_dir:, dry_run:, git_remote:, name:, options:)
          @repository = repository
          @component = component
          @release_version = version
          @performer_result = performer_result
          @artifact_dir = artifact_dir
          @dry_run = dry_run
          @git_remote = git_remote || "origin"
          @utils = repository.utils
          @repo_settings = repository.settings
          @component_settings = component.settings
          @name = name
          @options = options
        end

        ##
        # Get the option with the given key.
        #
        # @param key [String] Option name to fetch
        # @param required [boolean] Whether to exit with an error if the option
        #     is not set. Defaults to false, which instead returns the default.
        # @param default [Object] Default value to return if the option is not
        #     set and required is set to false.
        #
        # @return [Object] The option value
        #
        def option(key, required: false, default: nil)
          value = @options[key]
          if !value.nil?
            value
          elsif required
            exit_step("Missing option: #{key.inspect} for step #{self.class} (name = #{name.inspect})")
          else
            default
          end
        end

        ##
        # Exit the step immediately. If an error message is given, it is added
        # to the error stream.
        # Raises an error and not return.
        #
        # @param error_message [String] Optional error message
        # @param abort_pipeline [boolean] Whether to abort the pipeline.
        #     Default is false.
        #
        def exit_step(error_message = nil, abort_pipeline: false)
          utils.error(error_message) if error_message
          if abort_pipeline
            raise AbortingExit
          else
            raise StepExit
          end
        end

        ##
        # Get the path to an artifact directory for this step.
        #
        # @param name [String] Optional name that can be used to point to the
        #     same directory from multiple steps. If not specified, the step
        #     name is used.
        #
        def artifact_dir(name = nil)
          @artifact_dir.get(name || self.name)
        end

        ##
        # Run any pre-tool configured using the `"pre_tool"` option.
        # The option value must be an array of strings representing the command.
        #
        def pre_tool
          cmd = option("pre_tool")
          return unless cmd
          utils.log("Running pre-build tool...")
          result = utils.exec_separate_tool(cmd, out: [:child, :err])
          unless result.success?
            exit_step("Pre-build tool failed: #{cmd}. Check the logs for details.")
          end
          utils.log("Completed pre-build tool.")
        end

        ##
        # Run any pre-command configured using the `"pre_command"` option.
        # The option value must be an array of strings representing the command.
        #
        def pre_command
          cmd = option("pre_command")
          return unless cmd
          utils.log("Running pre-build command...")
          result = utils.exec(cmd, out: [:child, :err])
          unless result.success?
            exit_step("Pre-build command failed: #{cmd.inspect}. Check the logs for details.")
          end
          utils.log("Completed pre-build command.")
        end

        ##
        # Clean any files not part of the git repository, unless the `"clean"`
        # option is explicitly set to false.
        #
        def pre_clean
          return if option("clean") == false
          count = clean_gitignored(".")
          utils.log("Cleaned #{count} gitignored items")
        end

        ##
        # Check whether gh_pages is enabled for this component. If not enabled
        # and the step requires it, exit the step.
        #
        # @param required [boolean] Force this step to require gh_pages. If
        #     false, the `"require_gh_pages_enabled"` option can still specify
        #     that the step requires gh_pages.
        #
        def check_gh_pages_enabled(required:)
          if (required || option("require_gh_pages_enabled")) && !component_settings.gh_pages_enabled
            utils.log("Skipping step #{name.inspect} because gh_pages is not enabled.")
            exit_step
          end
        end

        ##
        # @return [boolean] Whether this step is being run in dry run mode
        #
        def dry_run?
          @dry_run
        end

        ##
        # @return [Toys::Release::Repository]
        #
        attr_reader :repository

        ##
        # @return [Toys::Release::Component]
        #
        attr_reader :component

        ##
        # @return [Toys::Release::RepoSettings]
        #
        attr_reader :repo_settings

        ##
        # @return [Toys::Release::ComponentSettings]
        #
        attr_reader :component_settings

        ##
        # @return [Toys::Release::EnvironmentUtils]
        #
        attr_reader :utils

        ##
        # @return [Gem::Version]
        #
        attr_reader :release_version

        ##
        # @return [Toys::Release::Performer::Result]
        #
        attr_reader :performer_result

        ##
        # @return [String]
        #
        attr_reader :name

        ##
        # @return [String]
        #
        attr_reader :git_remote

        ##
        # Run the step.
        # This method must be overridden in a subclass.
        #
        def run
          raise "Cannot run base step"
        end

        private

        def clean_gitignored(dir)
          count = 0
          children = dir_children(dir)
          result = utils.exec(["git", "check-ignore", "--stdin"], in: :controller, out: :capture) do |controller|
            children.each { |child| controller.in.puts(child) }
          end
          result.captured_out.split("\n").each do |path|
            ::FileUtils.rm_rf(path)
            utils.log("Cleaning: #{path}")
            count += 1
          end
          dir_children(dir).each do |child|
            count += clean_gitignored(child) if ::File.directory?(child)
          end
          count
        end

        def dir_children(dir)
          ::Dir.entries(dir)
               .grep_v(/^\.\.?$/)
               .sort
               .map { |entry| ::File.join(dir, entry) }
        end
      end

      ##
      # A step that runs a toys tool.
      # The tool must be specified as a string array in the `"tool"` option.
      #
      class Tool < Base
        ##
        # Run this step
        #
        def run
          tool = Array(option("tool", required: true))
          utils.log("Running tool #{tool.inspect}...")
          result = utils.exec_separate_tool(tool, out: [:child, :err])
          unless result.success?
            exit_step("Tool failed: #{tool.inspect}. Check the logs for details.",
                      abort_pipeline: option("abort_pipeline_on_error"))
          end
          utils.log("Completed tool")
        end
      end

      ##
      # A step that runs an arbitrary command.
      # The command must be specified as a string array in the `"command"`
      # option.
      #
      class Command < Base
        ##
        # Run this step
        #
        def run
          command = Array(option("command", required: true))
          utils.log("Running command #{command.inspect}...")
          result = utils.exec(command, out: [:child, :err])
          unless result.success?
            exit_step("Command failed: #{command.inspect}. Check the logs for details.",
                      abort_pipeline: option("abort_pipeline_on_error"))
          end
          utils.log("Completed command")
        end
      end

      ##
      # A step that runs bundler
      #
      class Bundle < Base
        ##
        # Run this step
        #
        def run
          utils.log("Running bundler for #{component.name} ...")
          component.bundle
          utils.log("Completed bundler for #{component.name}")
        end
      end

      ##
      # A step that builds the gem, and leaves the built gem file in the step's
      # artifact directory. This step can also run a pre_command and/or a
      # pre_tool.
      #
      class BuildGem < Base
        ##
        # Run this step
        #
        def run
          pre_clean
          utils.log("Building gem: #{component.name} #{release_version}...")
          pre_command
          pre_tool
          pkg_path = ::File.join(artifact_dir, "#{component.name}-#{release_version}.gem")
          result = utils.exec(["gem", "build", "#{component.name}.gemspec", "-o", pkg_path], out: [:child, :err])
          unless result.success?
            exit_step("Gem build failed for #{component.name} #{release_version}. Check the logs for details.")
          end
          utils.log("Gem built to #{pkg_path}.")
          utils.log("Completed gem build.")
        end
      end

      ##
      # A step that builds yardocs, and leaves the built documentation file in
      # the step's artifact directory. This step can also run a pre_command
      # and/or a pre_tool.
      #
      class BuildYard < Base
        ##
        # Run this step
        #
        def run
          check_gh_pages_enabled(required: false)
          pre_clean
          utils.log("Building yard: #{component.name} #{release_version}...")
          pre_command
          pre_tool
          ::FileUtils.rm_rf(".yardoc")
          ::FileUtils.rm_rf("doc")
          result = utils.exec(["bundle", "exec", "yard", "doc"], out: [:child, :err])
          if !result.success? || !::File.directory?("doc")
            exit_step("Yard build failed for #{component.name} #{release_version}. Check the logs for details.")
          end
          dest_path = ::File.join(artifact_dir, "doc")
          ::FileUtils.mv("doc", dest_path)
          utils.log("Docs built to #{dest_path}.")
          utils.log("Completed yard build.")
        end
      end

      ##
      # A step that releases a gem built by a previous run of BuildGem. The
      # `"input"` option provides the name of the artifact directory containing
      # the built gem.
      #
      class ReleaseGem < Base
        ##
        # Run this step
        #
        def run
          check_existence
          if dry_run?
            push_dry_run
          else
            push_gem
          end
        end

        private

        def check_existence
          utils.log("Checking whether #{component.name} #{release_version} already exists...")
          if component.version_released?(release_version)
            utils.warning("Gem already pushed for #{component.name} #{release_version}. Skipping.")
            performer_result.successes << "Gem already pushed for #{component.name} #{release_version}"
            exit_step
          end
          utils.log("Gem has not yet been released.")
        end

        def push_dry_run
          unless ::File.file?(pkg_path)
            exit_step("DRY RUN: Package not found at #{pkg_path}")
          end
          performer_result.successes << "DRY RUN Rubygems push for #{component.name} #{release_version}."
          utils.log("DRY RUN: Gem not actually pushed to Rubygems.")
        end

        def push_gem
          utils.log("Pushing gem: #{component.name} #{release_version}...")
          result = utils.exec(["gem", "push", pkg_path], out: [:child, :err])
          unless result.success?
            exit_step("Rubygems push failed for #{component.name} #{release_version}. Check the logs for details.")
          end
          performer_result.successes << "Rubygems push for #{component.name} #{release_version}."
          utils.log("Gem push successful.")
        end

        def pkg_path
          @pkg_path ||= ::File.join(artifact_dir(option("input")), "#{component.name}-#{release_version}.gem")
        end
      end

      ##
      # A step that pushes to gh-pages documentation built by a previous run of
      # BuildYard. The `"input"` option provides the name of the artifact
      # directory containing the built documentation.
      #
      class PushGhPages < Base
        ##
        # Run this step
        #
        def run
          check_gh_pages_enabled(required: true)
          setup_gh_pages_dir
          check_existence
          copy_docs_dir
          update_docs_404_page
          push_docs_to_git
        end

        private

        def setup_gh_pages_dir
          utils.log("Setting up gh-pages access ...")
          gh_token = ::ENV["GITHUB_TOKEN"]
          @gh_pages_dir = repository.checkout_separate_dir(
            branch: "gh-pages", remote: git_remote, dir: artifact_dir("gh-pages"), gh_token: gh_token
          )
          exit_step("Unable to access the gh-pages branch.") unless @gh_pages_dir
          utils.log("Checked out gh-pages")
        end

        def check_existence
          if ::File.directory?(dest_dir)
            utils.warning("Docs already published for #{component.name} #{release_version}. Skipping.")
            performer_result.successes << "Docs already published for #{component.name} #{release_version}"
            exit_step
          end
          utils.log("Verified docs not yet published for #{component.name} #{release_version}")
        end

        def copy_docs_dir
          from_dir = ::File.join(artifact_dir(option("input")), "doc")
          ::FileUtils.mkdir_p(component_dir)
          ::FileUtils.cp_r(from_dir, dest_dir)
        end

        def update_docs_404_page
          path = ::File.join(@gh_pages_dir, "404.html")
          content = ::File.read(path)
          content.sub!(/#{component.settings.gh_pages_version_var} = "[\w.]+";/,
                       "#{component.settings.gh_pages_version_var} = \"#{release_version}\";")
          ::File.write(path, content)
        end

        def push_docs_to_git # rubocop:disable Metrics/AbcSize
          ::Dir.chdir(@gh_pages_dir) do
            repository.git_commit("Generated docs for #{component.name} #{release_version}",
                                  signoff: repository.settings.signoff_commits?)
            if dry_run?
              performer_result.successes << "DRY RUN documentation published for #{component.name} #{release_version}."
              utils.log("DRY RUN: Documentation not actually published to gh-pages.")
            else
              result = utils.exec(["git", "push", git_remote, "gh-pages"], out: [:child, :err])
              unless result.success?
                exit_step("Docs publication failed for #{component.name} #{release_version}." \
                          " Check the logs for details.")
              end
              performer_result.successes << "Published documentation for #{component.name} #{release_version}."
              utils.log("Documentation publish successful.")
            end
          end
        end

        def component_dir
          @component_dir ||= ::File.expand_path(component.settings.gh_pages_directory, @gh_pages_dir)
        end

        def dest_dir
          @dest_dir ||= ::File.join(component_dir, "v#{release_version}")
        end
      end

      ##
      # A step that creates a GitHub tag and release.
      #
      class GitHubRelease < Base
        ##
        # Run this step
        #
        def run
          check_existence
          push_tag
        end

        private

        def check_existence
          utils.log("Checking whether #{tag_name} already exists...")
          cmd = ["gh", "api", "repos/#{repo_settings.repo_path}/releases/tags/#{tag_name}",
                 "-H", "Accept: application/vnd.github.v3+json"]
          result = utils.exec(cmd, out: :null, err: :null)
          if result.success?
            utils.warning("GitHub tag #{tag_name} already exists. Skipping.")
            performer_result.successes << "GitHub tag #{tag_name} already exists."
            exit_step
          end
          utils.log("GitHub tag #{tag_name} has not yet been created.")
        end

        def push_tag # rubocop:disable Metrics/AbcSize
          utils.log("Creating GitHub release #{tag_name}...")
          changelog_content = component.changelog_file.read_and_verify_latest_entry(release_version)
          release_sha = repository.current_sha
          body = ::JSON.dump(tag_name: tag_name,
                             target_commitish: release_sha,
                             name: "#{component.name} #{release_version}",
                             body: changelog_content)
          if dry_run?
            performer_result.successes << "DRY RUN GitHub tag #{tag_name}."
            utils.log("DRY RUN: GitHub tag #{tag_name} not actually created.")
          else
            cmd = ["gh", "api", "repos/#{repo_settings.repo_path}/releases", "--input", "-",
                   "-H", "Accept: application/vnd.github.v3+json"]
            result = utils.exec(cmd, in: [:string, body], out: :null)
            unless result.success?
              exit_step("Unable to create release #{tag_name}. Check the logs for details.")
            end
            performer_result.successes << "Created release with tag #{tag_name} on GitHub."
            utils.log("GitHub release successful.")
          end
        end

        def tag_name
          "#{component.name}/v#{release_version}"
        end
      end
    end
  end
end
