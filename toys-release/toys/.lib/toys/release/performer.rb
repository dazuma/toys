# frozen_string_literal: true

require "fileutils"
require "json"

require "toys/release/artifact_dir"
require "toys/release/pipeline"
require "toys/release/steps"

module Toys
  module Release
    ##
    # Performs releases
    #
    class Performer
      ##
      # Results to report for a component release
      #
      class Result
        ##
        # Create a new result
        #
        # @param component_name [String] The name of the component
        # @param version [::Gem::Version] The version to release
        #
        def initialize(component_name, version)
          @component_name = component_name
          @version = version
          @successes = []
          @errors = []
        end

        ##
        # @return [boolean] Whether there were no errors
        #
        def succeeded?
          @errors.empty?
        end

        ##
        # @return [boolean] True if there is no content (neither success nor
        #     error) for this result.
        #
        def empty?
          successes.empty? && errors.empty?
        end

        ##
        # @return [String] The name of the component
        #
        attr_reader :component_name

        ##
        # @return [::Gem::Version] The version to release
        #
        attr_reader :version

        ##
        # @return [Array<String>] The success messages
        #
        attr_reader :successes

        ##
        # @return [Array<String>] The error messages
        #
        attr_reader :errors

        ##
        # @return [Array<String>] The success messages, formatted for output.
        #
        def formatted_successes
          successes.map { |line| "* #{line}" }
        end

        ##
        # @return [Array<String>] The error messages, formatted for output.
        #     Returns the empty array if this Result is not capturing errors.
        #
        def formatted_errors
          errors.map { |line| "* ERROR: #{line}" }
        end

        # @private
        attr_writer :version
      end

      ##
      # Create a release performer.
      #
      # @param repository [Repository]
      # @param release_ref [String] Git ref or SHA for the release.
      # @param release_pr [Integer,PullRequest] Pull request for the release.
      # @param enable_prechecks [boolean]
      # @param git_remote [String] Git remote.
      # @param work_dir [String,nil] Directory for temporary artifacts. Uses an
      #     ephemeral temporary directory if not provided.
      # @param dry_run [boolean] If true, doesn't perform permanent operations
      #     such as pushing gems or creating github releases.
      #
      def initialize(repository,
                     release_ref: nil,
                     release_pr: nil,
                     enable_prechecks: true,
                     git_remote: nil,
                     work_dir: nil,
                     dry_run: false)
        @enable_prechecks = enable_prechecks
        @repository = repository
        @settings = repository.settings
        @utils = repository.utils
        @dry_run = dry_run
        @gh_token = ENV["GITHUB_TOKEN"]
        @git_remote = git_remote || "origin"
        @work_dir = work_dir
        @release_sha = @pull_request = @pr_components = nil
        @component_results = []
        @init_result = Result.new(nil, nil)
        @start_time = ::Time.now.utc
        @utils.capture_errors(@init_result.errors) do
          resolve_ref_and_pr(release_ref, release_pr)
          repo_prechecks if @enable_prechecks
        end
      end

      ##
      # @return [PullRequest] the GitHub pull request
      # @return [nil] if this performer was not configured with a pull request
      #
      attr_reader :pull_request

      ##
      # @return [Result] the results of initialization and prechecks
      #
      attr_reader :init_result

      ##
      # @return [Array<Result>] the results of the various releases done
      #
      attr_reader :component_results

      ##
      # Perform a release without pull request direction. Stores the result in a
      # new result appended to the component results.
      #
      # @param component_name [String] the name of the component to release
      # @param assert_version [String] (optional) if provided, asserts that the
      #     released version is the same as what is given
      #
      def perform_adhoc_release(component_name, assert_version: nil)
        @repository.at_sha(@release_sha) do
          result = Result.new(component_name, assert_version)
          @component_results << result
          @utils.capture_errors(result.errors) do
            component = @repository.component_named(component_name)
            version = component.current_changelog_version
            if !component
              @utils.error("Component #{component_name.inspect} not found.")
            elsif assert_version && assert_version != version
              @utils.error("Asserted version #{assert_version} does not match version " \
                          "#{version} found in the changelog for #{component_name.inspect}.")
            else
              result.version = version
              internal_perform_release(component, version, result)
            end
          end
        end
        self
      end

      ##
      # Perform all releases associated with the configured pull request
      #
      def perform_pr_releases
        if @pr_components.nil?
          @utils.capture_errors(@init_result.errors) do
            @utils.error("Cannot perform PR releases because no pull request was found.")
          end
          return self
        end
        @pr_components.each do |component_name, version|
          perform_adhoc_release(component_name, assert_version: version)
        end
        self
      end

      ##
      # Returns true if any errors happened in any of the releases
      #
      # @return [boolean]
      #
      def error?
        !@init_result.errors.empty? || @component_results.any? { |result| !result.errors.empty? }
      end

      ##
      # @return [String] The pull request URL
      # @return [nil] if there is no pull request configured for this performer
      #
      def pr_url
        @pull_request&.url
      end

      ##
      # Updates the pull request (if any) with the release results.
      # Also opens an issue if any failures happened.
      #
      def report_results
        report_text = build_report_text
        puts report_text
        if @dry_run
          @utils.warning("DRY RUN: Skipped updating pull request #{@pull_request.url}") if @pull_request
          @utils.warning("DRY RUN: Skipped opening release failure issue") if error?
        else
          update_pull_request(report_text) if @pull_request
          open_error_issue(report_text) if error?
        end
        self
      end

      ##
      # Builds a report of the release results
      #
      # @return [String]
      #
      def build_report_text
        lines = [
          "## Release job results",
          "",
        ]
        lines.concat(main_report_lines)
        unless @init_result.empty?
          lines << ""
          lines << "### Setup"
          lines << ""
          lines.concat(@init_result.formatted_errors)
          lines.concat(@init_result.formatted_successes)
        end
        @component_results.each do |result|
          next if result.empty?
          lines << ""
          lines << "### #{result.component_name} #{result.version}"
          lines << ""
          lines.concat(result.formatted_errors)
          lines.concat(result.formatted_successes)
        end
        lines.join("\n")
      end

      private

      def main_report_lines
        lines = [
          "* Job started #{@start_time.strftime('%Y-%m-%d %H:%M:%S')} UTC",
          "* Job finished #{::Time.now.utc.strftime('%Y-%m-%d %H:%M:%S')} UTC",
        ]
        lines << "* Release SHA: #{@release_sha}" if @release_sha
        lines << "* Release pull request: #{@pull_request.url}" if @pull_request
        lines << if error?
                   "* **Release job completed with errors.**"
                 else
                   "* **All releases completed successfully.**"
                 end
        if (server_url = ::ENV["GITHUB_SERVER_URL"])
          if (repo = ::ENV["GITHUB_REPOSITORY"])
            if (run_id = ::ENV["GITHUB_RUN_ID"])
              lines << "* Run logs: #{server_url}/#{repo}/actions/runs/#{run_id}"
            end
          end
        end
        lines
      end

      def resolve_ref_and_pr(ref, pr_info)
        @pull_request = nil
        case pr_info
        when ::Integer, ::String
          @pull_request = @repository.load_pr(pr_info.to_i)
          @utils.error("Pull request number #{pr_info} not found.") if @pull_request.nil?
        when PullRequest
          @pull_request = pr_info
        end
        ref = @pull_request.merge_commit_sha if @pull_request && !ref
        @release_sha = @repository.current_sha(ref)
        @utils.log("Release SHA set to #{@release_sha}")
        if @pull_request
          @utils.log("Release pull request is #{@pull_request.url}")
        else
          @utils.warning("Pull request not provided, and will not be updated with the release info.")
        end
        @pr_components = @pull_request ? @repository.released_components_and_versions(@pull_request) : nil
        @utils.exec(["git", "fetch", @git_remote, @release_sha], e: true)
        self
      end

      def repo_prechecks
        @utils.log("Performing repo-level prechecks ...")
        @repository.verify_git_clean
        @repository.verify_repo_identity(remote: @git_remote)
        @repository.verify_github_checks(ref: @release_sha)
        @utils.log("Repo-level prechecks succeeded.")
        self
      end

      def internal_perform_release(component, version, result)
        component_prechecks(component, version) if @enable_prechecks
        artifact_dir = ArtifactDir.new(@work_dir)
        begin
          component.cd do
            pipeline = Pipeline.new(
              repository: @repository, component: component, version: version, performer_result: result,
              artifact_dir: artifact_dir, dry_run: @dry_run, git_remote: @git_remote
            )
            component.settings.steps.each { |step_settings| pipeline.add_step(step_settings) }
            pipeline.resolve_run
            pipeline.run
          end
        ensure
          artifact_dir.cleanup
        end
        self
      end

      def component_prechecks(component, version)
        @utils.log("Running prechecks for #{component.name.inspect} ...")
        component.verify_version(version)
        @utils.log("Completed prechecks for #{component.name.inspect}")
        self
      end

      def update_pull_request(report_text)
        @utils.log("Updating release pull request #{@pull_request.url} ...")
        label = error? ? @settings.release_error_label : @settings.release_complete_label
        @pull_request.update(labels: label)
        @pull_request.add_comment(report_text)
        @utils.log("Updated release pull request #{@pull_request.url}")
      end

      def open_error_issue(report_text)
        @utils.log("Opening a new issue to report the failure ...")
        body = <<~STR
          A release job failed.

          Release PR: #{@pull_request&.url || 'unknown'}
          Commit: https://github.com/#{@settings.repo_path}/commit/#{@release_sha}

          ----

          #{report_text}
        STR
        title = "Release PR ##{@pull_request&.number || 'unknown'} failed with errors"
        issue_number = @repository.open_issue(title, body)["number"]
        @utils.log("Issue ##{issue_number} opened")
      end
    end
  end
end
