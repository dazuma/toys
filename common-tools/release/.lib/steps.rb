# frozen_string_literal: true

require "fileutils"

module ToysReleaser
  ##
  # Set of steps that can be used in a pipeline
  #
  module Steps
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

    class StepExit < ::StandardError
    end

    class AbortingExit < ::StandardError
    end

    class Base
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

      def exit_step(error_message = nil, abort_pipeline: false)
        utils.error(error_message) if error_message
        if abort_pipeline
          raise AbortingExit
        else
          raise StepExit
        end
      end

      def artifact_dir(name = nil)
        @artifact_dir.get(name || self.name)
      end

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

      def pre_clean
        return if option("clean") == false
        count = clean_gitignored(".")
        utils.log("Cleaned #{count} gitignored items")
      end

      def check_gh_pages_enabled(required:)
        if (required || option("require_gh_pages_enabled")) && !component_settings.gh_pages_enabled
          utils.log("Skipping step #{name.inspect} because gh_pages is not enabled.")
          exit_step
        end
      end

      def dry_run?
        @dry_run
      end

      attr_reader :repository
      attr_reader :component
      attr_reader :repo_settings
      attr_reader :component_settings
      attr_reader :utils
      attr_reader :release_version
      attr_reader :performer_result
      attr_reader :name
      attr_reader :git_remote

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

    class Tool < Base
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

    class Command < Base
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

    class Bundle < Base
      def run
        utils.log("Running bundler for #{component.name} ...")
        component.bundle
        utils.log("Completed bundler for #{component.name}")
      end
    end

    class BuildGem < Base
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

    class BuildYard < Base
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

    class ReleaseGem < Base
      def run
        check_existence
        if dry_run?
          push_dry_run
        else
          push_gem
        end
      end

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

    class PushGhPages < Base
      def run
        check_gh_pages_enabled(required: true)
        setup_gh_pages_dir
        check_existence
        copy_docs_dir
        update_docs_404_page
        push_docs_to_git
      end

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
              exit_step("Docs publication failed for #{component.name} #{release_version}. Check the logs for details.")
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

    class GitHubRelease < Base
      def run
        check_existence
        push_tag
      end

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
