# frozen_string_literal: true

require "fileutils"
require "json"

module ToysReleaser
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
      # @param capture_errors [boolean] Whether to capture errors
      #
      def initialize(component_name, version, capture_errors)
        @component_name = component_name
        @version = version
        @successes = []
        @errors = capture_errors ? [] : nil
      end

      ##
      # @return [boolean] Whether the result is capturing errors
      #
      def capture_errors?
        !@errors.nil?
      end

      ##
      # @return [boolean] True if there is no content (neither success nor
      #     error) for this result.
      #
      def empty?
        successes.empty? && (!errors || errors.empty?)
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
      # @return [Array<String>,nil] The error messages, or nil if this Result
      #     is not capturing errors
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
        (errors || []).map { |line| "* ERROR: #{line}" }
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
    # @param enable_tags [boolean]
    # @param enable_gems [boolean]
    # @param enable_docs [boolean]
    # @param capture_errors [boolean] If true, captures errors into the
    #     results objects instead of raising.
    # @param git_remote [String] Git remote.
    #
    def initialize(repository,
                   release_ref: nil,
                   release_pr: nil,
                   enable_prechecks: true,
                   enable_tags: true,
                   enable_gems: true,
                   enable_docs: true,
                   capture_errors: false,
                   git_remote: nil,
                   gh_pages_dir: nil,
                   dry_run: false)
      @capture_errors = capture_errors
      @enable_prechecks = enable_prechecks
      @enable_tags = enable_tags
      @enable_gems = enable_gems
      @enable_docs = enable_docs
      @repository = repository
      @settings = repository.settings
      @utils = repository.utils
      @dry_run = dry_run
      @gh_token = ENV["GITHUB_TOKEN"]
      @git_remote = git_remote || "origin"
      @gh_pages_dir = gh_pages_dir
      @gh_pages_setup_done = false
      @release_sha = @pull_request = @pr_components = nil
      @component_results = []
      @init_result = Result.new(nil, nil, @capture_errors)
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
        result = Result.new(component_name, assert_version, @capture_errors)
        @component_results << result
        @utils.capture_errors(result.errors) do
          component = @repository.component(component_name)
          if !component
            @utils.error("Component #{component_name.inspect} not found.")
          elsif assert_version && assert_version != component.current_changelog_version
            @utils.error("Asserted version #{assert_version} does not match version " \
                         "#{component.current_changelog_version} found in the changelog.")
          else
            result.version = component.current_changelog_version
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
      !Array(@init_result.errors).empty? || @component_results.any? { |result| !Array(result.errors).empty? }
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
      if @pull_request
        @utils.log("Updating release pull request #{@pull_request.url} ...")
        label = error? ? @settings.release_error_label : @settings.release_complete_label
        @pull_request.update(labels: label)
        @pull_request.add_comment(report_text)
        @utils.log("Updated release pull request #{@pull_request.url}")
      end
      if error?
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
      self
    end

    ##
    # Builds a report of the release results
    #
    # @return [String]
    #
    def build_report_text
      finish_time = ::Time.now.utc
      lines = [
        "## Release job results",
        "",
        "* Job started #{@start_time.strftime('%Y-%m-%d %H:%M:%S')} UTC",
        "* Job finished #{finish_time.strftime('%Y-%m-%d %H:%M:%S')} UTC",
      ]
      lines << "* Release SHA: #{@release_sha}" if @release_sha
      lines << "* Release pull request: #{@pull_request.url}" if @pull_request
      lines << if error?
                 "* **Release job completed with errors.**"
               else
                 "* **All releases completed successfully.**"
               end
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
      @pull_request ||= @repository.find_release_prs(merge_sha: @release_sha)
      if @pull_request
        @utils.log("Release pull request is #{@pull_request.url}")
      else
        @utils.warning("No unique release pull request found")
      end
      @pr_components = @pull_request ? @repository.released_components_and_versions(@pull_request) : nil
      @utils.exec(["git", "fetch", @git_remote, @release_sha], e: true)
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
      bundle(component)
      component_prechecks(component, version) if @enable_prechecks
      setup_gh_pages if @enable_docs
      enable_gems = @enable_gems && !gem_already_exists?(component, version, result)
      enable_docs = @enable_docs && !docs_already_exists?(component, version, result)
      enable_tags = @enable_tags && !tag_already_exists?(component, version, result)
      return unless enable_gems || enable_docs || enable_tags
      pre_build(component)
      if component.is_a?(GemComponent)
        build_gem(component, version) if enable_gems
        docs_built = build_docs(component) if enable_docs
        push_gem(component, version, result) if enable_gems
        push_docs(component, version, result) if enable_docs && docs_built
      end
      github_release(component, version, result) if enable_tags
      post_build(component)
    end

    def bundle(component)
      @utils.log("Running bundler for #{component.name.inspect} ...")
      component.bundle
      @utils.log("Completed bundler for #{component.name.inspect}")
      self
    end

    def component_prechecks(component, version)
      @utils.log("Running prechecks for #{component.name.inspect} ...")
      component.verify_version(version)
      @utils.log("Completed prechecks for #{component.name.inspect}")
      self
    end

    def setup_gh_pages
      return if @gh_pages_setup_done
      @utils.log("Setting up gh-pages access ...")
      @gh_pages_dir = @repository.checkout_sparate_dir(
        branch: "gh-pages", remote: @git_remote, dir: @gh_pages_dir, gh_token: @gh_token
      )
      @gh_pages_setup_done = true
      @utils.log("Completed gh-pages access setup")
      self
    end

    def gem_already_exists?(component, version, result)
      return false unless component.released_versions.include?(version)
      @utils.warning("Gem already pushed for #{component.name.inspect} #{version}. Skipping.")
      result.successes << "Gem already pushed for #{component.name.inspect} #{version}"
      true
    end

    def docs_already_exists?(component, version, result)
      dir = ::File.join(::File.expand_path(component.gh_pages_directory, @gh_pages_dir), "v#{version}")
      return false unless ::File.directory?(dir)
      @utils.warning("Docs already published for #{component.name.inspect} #{version}. Skipping.")
      result.successes << "Docs already published for #{component.name.inspect} #{version}"
      true
    end

    def tag_already_exists?(component, version, result)
      cmd = [
        "gh", "api", "repos/#{@settings.repo_path}/releases/tags/#{component.name}/v#{version}",
        "-H", "Accept: application/vnd.github.v3+json"
      ]
      exec_result = @utils.exec(cmd, out: :null)
      return false unless exec_result.success?
      @utils.warning("GitHub release already exists for #{component.name.inspect} #{version}. Skipping.")
      result.successes << "GitHub release already exists for #{component.name.inspect} #{version}"
      true
    end

    def pre_build(component)
      component.cd do
        Array(component.settings.pre_clean_dirs).each do |dir|
          ::FileUtils.rm_rf(dir)
        end
      end
      tool_spec = component.settings.pre_builder_tool
      return unless tool_spec
      @utils.log("Running pre-build tool for #{component.name} ...")
      component.cd do
        exec_result = @utils.exec_separate_tool(tool_spec)
        @utils.error("Pre-build failed for #{component.name}. Check the logs for details.") unless exec_result.success?
      end
      @utils.log("Completed pre-build tool for #{component.name}")
    end

    def build_gem(component, version)
      @utils.log("Running gem build for #{component.name} ...")
      component.cd do
        ::FileUtils.mkdir_p("pkg")
        cmd = ["gem", "build", "#{component.name}.gemspec", "-o", "pkg/#{component.name}-#{version}.gem"]
        exec_result = @utils.exec(cmd)
        @utils.error("Gem build failed for #{component.name}. Check the logs for details.") unless exec_result.success?
      end
      @utils.log("Completed gem build for #{component.name}")
    end

    def build_docs(component)
      return false unless component.gh_pages_enabled
      component.cd do
        tool_spec = component.settings.docs_builder_tool
        exec_result =
          if tool_spec
            @utils.log("Running custom docs build tool for #{component.name} ...")
            @utils.exec_separate_tool(tool_spec)
          else
            @utils.log("Running standard docs build for #{component.name} ...")
            ::FileUtils.rm_rf(".yardoc")
            ::FileUtils.rm_rf("doc")
            @utils.exec(["bundle", "exec", "yard", "doc"])
          end
        @utils.error("Docs build failed for #{component.name}. Check the logs for details.") unless exec_result.success?
      end
      @utils.log("Completed docs build for #{component.name}")
      true
    end

    def push_gem(component, version, result)
      @utils.log("Running gem push for #{component.name} ...")
      if @dry_run
        @utils.log("DRY RUN: Gem not actually pushed to Rubygems")
        result.successes << "DRY RUN Rubygems push for #{component.name} #{version}."
      else
        component.cd do
          exec_result = @utils.exec(["gem", "push", "pkg/#{component.name}-#{version}.gem"])
          if exec_result.success?
            result.successes << "Pushed #{component.name} #{version} to Rubygems."
          else
            @utils.error("Gem push failed for #{component.name}. Check the logs for details.")
          end
        end
      end
      @utils.log("Completed gem push for #{component.name}")
    end

    def push_docs(component, version, result)
      @utils.log("Running docs push for #{component.name} ...")
      copy_docs_dir(component, version)
      update_docs_404_page(component, version)
      push_docs_to_git(component, version, result)
      @utils.log("Completed docs push for #{component.name}")
    end

    def copy_docs_dir(component, version)
      from_dir = ::File.join(component.directory(from: :absolute), "doc")
      to_dir = ::File.join(::File.expand_path(component.gh_pages_directory, @gh_pages_dir), "v#{version}")
      ::FileUtils.rm_rf(to_dir)
      ::FileUtils.mkdir_p(to_dir)
      ::FileUtils.cp_r(from_dir, to_dir)
    end

    def update_docs_404_page(component, version)
      path = ::File.join(@gh_pages_dir, "404.html")
      content = ::File.read(path)
      content.sub!(/#{component.gh_pages_version_var} = "[\w.]+";/,
                   "#{component.gh_pages_version_var} = \"#{version}\";")
      ::File.write(path, content)
    end

    def push_docs_to_git(component, version, result)
      ::Dir.chdir(@gh_pages_dir) do
        @repository.git_commit("Generated docs for #{component.name} #{version}",
                               signoff: @repository.settings.signoff_commits?)
        if @dry_run
          @utils.log("DRY RUN: Documentation not actually published to gh-pages.")
          result.successes << "DRY RUN documentation publish for #{component.name} #{version}."
        else
          exec_result = @utils.exec(["git", "push", @git_remote, "gh-pages"])
          if exec_result.success?
            result.successes << "Published documentation for #{component.name} #{version}."
          else
            @utils.error("Docs publication failed for #{component.name}. Check the logs for details.")
          end
        end
      end
    end

    def github_release(component, version, result)
      @utils.log("Running github release for #{component.name} ...")
      if @dry_run
        @utils.log("DRY RUN: GitHub release not actually done.")
        result.successes << "DRY RUN GitHub release for #{component.name} #{version}."
      else
        component.cd do
          changelog_content = component.changelog_file.read_and_verify_latest_entry(version)
          body = ::JSON.dump(tag_name: "#{component.name}/v#{version}",
                             target_commitish: @release_sha,
                             name: "#{component.name} #{version}",
                             body: changelog_content.to_s.strip)
          cmd = ["gh", "api", "repos/#{@settings.repo_path}/releases", "--input", "-",
                 "-H", "Accept: application/vnd.github.v3+json"]
          exec_result = @utils.exec(cmd, in: [:string, body], out: :null)
          if exec_result.success?
            result.successes << "Created GitHub release for #{component.name} #{version}."
          else
            @utils.error("GitHub release failed for #{component.name}. Check the logs for details.")
          end
        end
      end
      @utils.log("Completed github release for #{component.name}")
    end

    def post_build(component)
      tool_spec = component.settings.post_builder_tool
      if tool_spec
        @utils.log("Running post-build tool for #{component.name} ...")
        component.cd do
          exec_result = @utils.exec_separate_tool(tool_spec)
          unless exec_result.success?
            @utils.error("Post-build failed for #{component.name}. Check the logs for details.")
          end
        end
        @utils.log("Completed post-build tool for #{component.name}")
      end
      component.cd do
        Array(component.settings.post_clean_dirs).each do |dir|
          ::FileUtils.rm_rf(dir)
        end
      end
    end
  end
end
