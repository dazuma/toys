# frozen_string_literal: true

require "fileutils"
require "toys/utils/gems"

module Toys
  module Release
    ##
    # A namespace for steps that can be used in a pipeline
    #
    module Steps
      ##
      # The interface that steps must implement.
      #
      # This module is primarily for documentation. It need not actually be
      # included in a step implementation.
      #
      module Interface
        ##
        # Whether this step is a primary step (i.e. always runs.)
        #
        # @param step_context [Toys::Release::Pipeline::StepContext] Context
        #     provided for the step
        # @return [boolean]
        #
        def primary?(step_context)
          raise "Unimplemented #{step_context}"
        end

        ##
        # Return the names of the standard dependencies of this step
        #
        # @param step_context [Toys::Release::Pipeline::StepContext] Context
        #     provided for the step
        # @return [Array<String>]
        #
        def dependencies(step_context)
          raise "Unimplemented #{step_context}"
        end

        ##
        # Run the step.
        #
        # @param step_context [Toys::Release::Pipeline::StepContext] Context
        #     provided for the step
        #
        def run(step_context)
          raise "Unimplemented #{step_context}"
        end
      end

      ##
      # A step that does nothing.
      #
      NOOP = ::Object.new

      ##
      # A step that runs a toys tool.
      # The tool must be specified as a string array in the `"tool"` option.
      #
      TOOL = ::Object.new
      class << TOOL
        # @private
        def run(step_context)
          tool = Array(step_context.option("tool", required: true))
          step_context.log("Running tool #{tool.inspect}...")
          result = step_context.utils.exec_separate_tool(tool, out: [:child, :err])
          unless result.success?
            step_context.abort_pipeline("Tool failed: #{tool.inspect}. Check the logs for details.")
          end
          step_context.log("Completed tool")
        end
      end

      ##
      # A step that runs an arbitrary command.
      # The command must be specified as a string array in the `"command"`
      # option.
      #
      COMMAND = ::Object.new
      class << COMMAND
        # @private
        def run(step_context)
          command = Array(step_context.option("command", required: true))
          step_context.log("Running command #{command.inspect}...")
          result = step_context.utils.exec(command, out: [:child, :err])
          unless result.success?
            step_context.abort_pipeline("Command failed: #{command.inspect}. Check the logs for details.")
          end
          step_context.log("Completed command")
        end
      end

      ##
      # A step that runs bundler
      #
      BUNDLE = ::Object.new
      class << BUNDLE
        # @private
        def run(step_context)
          component = step_context.component
          step_context.log("Running bundler for #{component.name} ...")
          component.bundle
          step_context.log("Completed bundler for #{component.name}")
          step_context.copy_to_output(source_path: "Gemfile.lock")
        end
      end

      ##
      # A step that builds the gem, and leaves the built gem file in the step's
      # artifact directory. This step can also run a pre_command and/or a
      # pre_tool.
      #
      BUILD_GEM = ::Object.new
      class << BUILD_GEM
        # @private
        def run(step_context)
          step_context.log("Building gem: #{step_context.release_description}...")
          pkg_dir = ::File.join(step_context.output_dir, "pkg")
          ::FileUtils.mkdir_p(pkg_dir)
          pkg_path = ::File.join(pkg_dir, step_context.gem_package_name)
          result = step_context.utils.exec(
            ["gem", "build", "#{step_context.component.name}.gemspec", "-o", pkg_path],
            out: [:child, :err]
          )
          unless result.success?
            step_context.abort_pipeline("Gem build failed for #{step_context.release_description}." \
                                        " Check the logs for details.")
          end
          step_context.log("Gem built to #{pkg_path}.")
          step_context.log("Completed gem build.")
        end
      end

      ##
      # A step that builds yardocs, and leaves the built documentation file in
      # the step's artifact directory. This step can also run a pre_command
      # and/or a pre_tool.
      #
      BUILD_YARD = ::Object.new
      class << BUILD_YARD
        # @private
        def run(step_context)
          step_context.log("Building yard: #{step_context.release_description}...")
          doc_dir = ::File.join(step_context.output_dir, "doc")
          ::Toys::Utils::Gems.activate("yard")
          code = <<~CODE
            gem 'yard'
            require 'yard'
            ::YARD::CLI::Yardoc.run("--no-cache", "-o", "#{doc_dir}")
          CODE
          result = step_context.utils.ruby(code, out: [:child, :err])
          if !result.success? || !::File.directory?(doc_dir)
            step_context.abort_pipeline("Yard build failed for #{step_context.release_description}." \
                                        " Check the logs for details.")
          end
          step_context.log("Docs built to #{doc_dir}.")
          step_context.log("Completed yard build.")
        end
      end

      ##
      # A step that releases a gem built by a previous run of BuildGem. The
      # `"input"` option provides the name of the artifact directory containing
      # the built gem.
      #
      RELEASE_GEM = ::Object.new
      class << RELEASE_GEM
        # @private
        def primary?(_step_context)
          true
        end

        # @private
        def dependencies(step_context)
          [source_step(step_context)]
        end

        # @private
        def run(step_context)
          check_existence(step_context)
          pkg_path = find_package(step_context)
          if step_context.dry_run?
            push_dry_run(step_context)
          else
            push_gem(step_context, pkg_path)
          end
        end

        private

        def source_step(step_context)
          step_context.option("source", default: "build_gem")
        end

        def check_existence(step_context)
          step_context.log("Checking whether #{step_context.release_description} already exists...")
          if step_context.component.version_released?(step_context.release_version)
            step_context.warning("Gem already pushed for #{step_context.release_description}. Skipping.")
            step_context.add_success("Gem already pushed for #{step_context.release_description}")
            step_context.exit_step
          end
          step_context.log("Gem has not yet been released.")
        end

        def find_package(step_context)
          step_name = source_step(step_context)
          source_dir = step_context.output_dir(step_name)
          source_path = ::File.join(source_dir, "pkg", step_context.gem_package_name)
          unless ::File.file?(source_path)
            step_context.abort_pipeline("The output of step #{step_name} did not include a built gem at #{source_path}")
          end
          source_path
        end

        def push_dry_run(step_context)
          step_context.add_success("DRY RUN Rubygems push for #{step_context.release_description}.")
          step_context.log("DRY RUN: Gem not actually pushed to Rubygems.")
        end

        def push_gem(step_context, pkg_path)
          step_context.log("Pushing gem: #{step_context.release_description}...")
          result = step_context.utils.exec(["gem", "push", pkg_path], out: [:child, :err])
          unless result.success?
            step_context.abort_pipeline("Rubygems push failed for #{step_context.release_description}." \
                                        " Check the logs for details.")
          end
          step_context.add_success("Rubygems push for #{step_context.release_description}.")
          step_context.log("Gem push successful.")
        end
      end

      ##
      # A step that pushes to gh-pages documentation built by a previous run of
      # BuildYard. The `"input"` option provides the name of the artifact
      # directory containing the built documentation.
      #
      PUSH_GH_PAGES = ::Object.new
      class << PUSH_GH_PAGES
        # @private
        def primary?(step_context)
          step_context.component.settings.gh_pages_enabled
        end

        # @private
        def dependencies(step_context)
          [source_step(step_context)]
        end

        # @private
        def run(step_context)
          gh_pages_dir = setup_gh_pages_dir(step_context)
          component_dir = ::File.expand_path(step_context.component.settings.gh_pages_directory, gh_pages_dir)
          dest_dir = ::File.join(component_dir, "v#{step_context.release_version}")
          check_existence(step_context, dest_dir)
          copy_docs_dir(step_context, dest_dir)
          update_docs_404_page(step_context, gh_pages_dir)
          push_docs_to_git(step_context, gh_pages_dir)
        end

        private

        def source_step(step_context)
          step_context.option("source", default: "build_yard")
        end

        def setup_gh_pages_dir(step_context)
          step_context.log("Setting up gh-pages access ...")
          gh_token = ::ENV["GITHUB_TOKEN"]
          gh_pages_dir = step_context.repository.checkout_separate_dir(
            branch: "gh-pages", remote: step_context.git_remote, dir: step_context.temp_dir, gh_token: gh_token
          )
          step_context.abort_pipeline("Unable to access the gh-pages branch.") unless gh_pages_dir
          step_context.log("Checked out gh-pages")
          gh_pages_dir
        end

        def check_existence(step_context, dest_dir)
          if ::File.directory?(dest_dir)
            step_context.warning("Docs already published for #{step_context.release_description}. Skipping.")
            step_context.add_success("Docs already published for #{step_context.release_description}")
            step_context.exit_step
          end
          step_context.log("Verified docs not yet published for #{step_context.release_description}")
        end

        def copy_docs_dir(step_context, dest_dir)
          step_name = source_step(step_context)
          source_dir = ::File.join(step_context.output_dir(step_name), "doc")
          unless ::File.directory?(source_dir)
            step_context.abort_pipeline("The output of step #{step_name} did not include built docs at #{source_dir}")
          end
          ::FileUtils.mkdir_p(::File.dirname(dest_dir))
          ::FileUtils.cp_r(source_dir, dest_dir)
        end

        def update_docs_404_page(step_context, gh_pages_dir)
          path = ::File.join(gh_pages_dir, "404.html")
          content = ::File.read(path)
          version_var = step_context.component.settings.gh_pages_version_var
          content.sub!(/#{version_var} = "[\w.]+";/,
                       "#{version_var} = \"#{step_context.release_version}\";")
          ::File.write(path, content)
        end

        def push_docs_to_git(step_context, gh_pages_dir)
          ::Dir.chdir(gh_pages_dir) do
            step_context.repository.git_commit("Generated docs for #{step_context.release_description}",
                                               signoff: step_context.repository.settings.signoff_commits?)
            if step_context.dry_run?
              step_context.add_success("DRY RUN documentation published for #{step_context.release_description}.")
              step_context.log("DRY RUN: Documentation not actually published to gh-pages.")
            else
              result = step_context.utils.exec(["git", "push", step_context.git_remote, "gh-pages"],
                                               out: [:child, :err])
              unless result.success?
                step_context.abort_pipeline("Docs publication failed for #{step_context.release_description}." \
                                            " Check the logs for details.")
              end
              step_context.add_success("Published documentation for #{step_context.release_description}.")
              step_context.log("Documentation publish successful.")
            end
          end
        end
      end

      ##
      # A step that creates a GitHub tag and release.
      #
      RELEASE_GITHUB = ::Object.new
      class << RELEASE_GITHUB
        # @private
        def primary?(_step_context)
          true
        end

        # @private
        def run(step_context)
          check_existence(step_context)
          push_tag(step_context)
        end

        private

        def check_existence(step_context)
          tag_name = step_context.tag_name
          repo_path = step_context.repository.settings.repo_path
          step_context.log("Checking whether #{tag_name} already exists...")
          cmd = ["gh", "api", "repos/#{repo_path}/releases/tags/#{tag_name}",
                 "-H", "Accept: application/vnd.github.v3+json"]
          result = step_context.utils.exec(cmd, out: :null, err: :null)
          if result.success?
            step_context.warning("GitHub tag #{tag_name} already exists. Skipping.")
            step_context.add_success("GitHub tag #{tag_name} already exists.")
            step_context.exit_step
          end
          step_context.log("GitHub tag #{tag_name} has not yet been created.")
        end

        def push_tag(step_context)
          tag_name = step_context.tag_name
          repo_path = step_context.repository.settings.repo_path
          step_context.log("Creating GitHub release #{tag_name}...")
          changelog_file = step_context.component.changelog_file
          changelog_content = changelog_file.read_and_verify_latest_entry(step_context.release_version)
          release_sha = step_context.repository.current_sha
          body = ::JSON.dump(tag_name: tag_name,
                             target_commitish: release_sha,
                             name: step_context.release_description,
                             body: changelog_content)
          if step_context.dry_run?
            step_context.add_success("DRY RUN GitHub tag #{tag_name}.")
            step_context.log("DRY RUN: GitHub tag #{tag_name} not actually created.")
          else
            cmd = ["gh", "api", "repos/#{repo_path}/releases", "--input", "-",
                   "-H", "Accept: application/vnd.github.v3+json"]
            result = step_context.utils.exec(cmd, in: [:string, body], out: :null)
            unless result.success?
              step_context.abort_pipeline("Unable to create release #{tag_name}. Check the logs for details.")
            end
            step_context.add_success("Created release with tag #{tag_name} on GitHub.")
            step_context.log("GitHub release successful.")
          end
        end
      end
    end
  end
end
