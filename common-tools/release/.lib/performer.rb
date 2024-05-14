# frozen_string_literal: true

module ToysReleaser
  ##
  # Performs releases
  #
  class Performer
    ##
    # Results to report for a unit release
    #
    class Result
      ##
      # Create a new result
      #
      # @param unit_name [String] The name of the unit
      # @param version [::Gem::Version] The version to release
      # @param capture_errors [boolean] Whether to capture errors
      #
      def initialize(unit_name, version, capture_errors)
        @unit_name = unit_name
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
      # @return [String] The name of the releasable unit
      #
      attr_reader :unit_name

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
        successes.map{ |line| "* #{line}" }
      end

      ##
      # @return [Array<String>] The error messages, formatted for output.
      #     Returns the empty array if this Result is not capturing errors.
      #
      def formatted_errors
        (errors || []).map{ |line| "* ERROR: #{line}" }
      end

      # @private
      attr_writer :version
    end

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
      @release_sha = @pr_info = @pr_units = nil
      @unit_results = []
      @init_result = Result.new(nil, nil, @capture_errors)
      @start_time = Time.now.utc
      @utils.capture_errors(@init_result.errors) do
        resolve_ref_and_pr(release_ref, release_pr)
        repo_prechecks if @enable_prechecks
      end
    end

    attr_reader :pr_info

    attr_reader :init_result

    attr_reader :results

    def perform_adhoc_release(unit_name, assert_version: nil)
      @repository.at_sha(@release_sha) do
        result = Result.new(unit_name, assert_version, @capture_errors)
        @unit_results << result
        @utils.capture_errors(result.errors) do
          unit = @repository.releasable_unit(unit_name)
          if !unit
            @utils.error("Releasable unit #{unit_name.inspect} not found.")
          elsif assert_version && assert_version != unit.current_changelog_version
            @utils.error("Asserted version #{assert_version} does not match version #{unit.current_changelog_version} found in the changelog.")
          else
            result.version = unit.current_changelog_version
            internal_perform_release(unit, version, result)
          end
        end
      end
      self
    end

    def perform_pr_releases
      if @pr_units.nil?
        @utils.capture_errors(@init_result.errors) do
          @utils.error("Cannot perform PR releases because no pull request was found.")
        end
        return self
      end
      @pr_units.each do |unit_name, version|
        perform_adhoc_release(unit_name, assert_version: version)
      end
      self
    end

    def error?
      !Array(@init_result.errors).empty? || @unit_results.any?{ |result| !Array(result.errors).empty? }
    end

    def pr_url
      return nil unless @pr_info
      pr_number = @pr_info["number"]
      "https://github.com/#{@repository.settings.repo_path}/pull/#{pr_number}"
    end

    def report_results
      report_text = build_report_text
      if @pr_info
        @utils.log("Updating release pull request #{pr_url} ...")
        pr_number = @pr_info["number"]
        label = error? ? @settings.release_error_label : @settings.release_complete_label
        @repository.update_release_pr(pr_number, message: report_text, labels: label, cur_pr: @pr_info)
        @utils.log("Updated release pull request #{pr_url}")
      end
      if error?
        @utils.log("Opening a new issue to report the failure ...")
        body = <<~STR
          A release job failed.

          Release PR: #{pr_url || "unknown"}
          Commit: https://github.com/#{@settings.repo_path}/commit/#{@release_sha}

          ----

          #{report_text}
        STR
        title = "Release PR ##{pr_number} failed with errors"
        issue_number = @repository.open_issue(title, body)["number"]
        @utils.log("Issue ##{issue_number} opened")
      end
      self
    end

    def build_report_text
      finish_time = Time.now.utc
      lines = [
        "## Release job results",
        "",
        "* Job started #{@start_time.strftime('%Y-%m-%d %H:%M:%S')} UTC",
        "* Job finished #{finish_time.strftime('%Y-%m-%d %H:%M:%S')} UTC",
      ]
      lines << "* Release SHA: #{@release_sha}" if @release_sha
      lines << "* Release pull request: #{pr_url}" if @pr_info
      if error?
        lines << "* **Release job completed with errors.**"
      else
        lines << "* **All releases completed successfully.**"
      end
      unless @init_result.empty?
        lines << ""
        lines << "### Setup"
        lines << ""
        lines.concat(@init_result.formatted_errors)
        lines.concat(@init_result.formatted_successes)
      end
      @unit_results.each do |result|
        next if result.empty?
        lines << ""
        lines << "### #{result.unit_name} #{result.version}"
        lines << ""
        lines.concat(result.formatted_errors)
        lines.concat(result.formatted_successes)
      end
      lines.join("\n")
    end

    private

    def resolve_ref_and_pr(ref, pr)
      @pr_info = nil
      case pr
      when ::Integer, ::String
        pr = pr.to_i
        @pr_info = @repository.load_pr(pr)
        @utils.error("Pull request number #{pr} not found.") if @pr_info.nil?
      when ::Hash
        @pr_info = pr
      end
      ref = @pr_info["merge_commit_sha"] if @pr_info && !ref
      @release_sha = @repository.current_sha(ref)
      @utils.log("Release SHA set to #{@release_sha}")
      @pr_info ||= @repository.find_release_prs(merge_sha: @release_sha)
      if @pr_info
        @utils.log("Release pull request is #{pr_url}")
      else
        @utils.warn("No release pull request found")
      end
      @pr_units = @pr_info ? @repository.released_units_and_versions(@pr_info) : nil
      @utils.exec(["git", "fetch", @git_remote, @release_sha])
    end

    def repo_prechecks
      @utils.info("Performing repo-level prechecks ...")
      @repository.verify_git_clean
      @repository.verify_repo_identity(git_remote: @git_remote)
      @repository.verify_github_checks(ref: @release_sha)
      @utils.info("Repo-level prechecks succeeded.")
      self
    end

    def internal_perform_release(unit, version, result)
      bundle(unit)
      unit_prechecks(unit, version, result) if @enable_prechecks
      setup_gh_pages if @enable_docs
      enable_gems = @enable_gems && !gem_already_exists?(unit, version, result)
      enable_docs = @enable_docs && !docs_already_exists?(unit, version, result)
      enable_tags = @enable_tags && !tag_already_exists?(unit, version, result)
      return unless enable_gems || enable_docs || enable_tags
      pre_build(unit, version)
      if unit.is_a?(ReleasableGem)
        build_gem(unit, version) if enable_gems
        docs_built = build_docs(unit, version) if enable_docs
        push_gem(unit, version, result) if enable_gems
        push_docs(unit, version, result) if enable_docs && docs_built
      end
      github_release(unit, version, result) if enable_tags
      post_build(unit, version)
    end

    def bundle(unit)
      @utils.log("Running bundler for #{unit.name} ...")
      unit.bundle
      @utils.log("Completed bundler for #{unit.name}")
      self
    end

    def unit_prechecks(unit, version, result)
      @utils.log("Running prechecks for #{unit.name} ...")
      unit.verify_version(version)
      @utils.log("Completed prechecks for #{unit.name}")
      self
    end

    def setup_gh_pages
      return if @gh_pages_setup_done
      @utils.log("Setting up gh-pages access ...")
      @gh_pages_dir = @repository.checkout_sparate_dir(
        branch: "gh-pages", remote: @git_remote, dir: @gh_pages_dir, gh_token: @gh_token)
      @gh_pages_setup_done = true
      @utils.log("Completed gh-pages access setup")
      self
    end

    def gem_already_exists?(unit, version, result)
      return false unless unit.released_versions.include?(version)
      @utils.warn("Gem already pushed for #{unit.name} #{version}. Skipping.")
      result.successes << "Gem already pushed for #{unit.name} #{version}"
      true
    end

    def docs_already_exists?(unit, version, result)
      dir = ::File.join(::File.expand_path(unit.gh_pages_directory, @gh_pages_dir), "v#{version}")
      return false unless ::File.directory?(dir)
      @utils.warn("Docs already published for #{unit.name} #{version}. Skipping.")
      result.successes << "Docs already published for #{unit.name} #{version}"
      true
    end

    def tag_already_exists?(unit, version, result)
      cmd = [
        "gh", "api", "repos/#{@settings.repo_path}/releases/tags/#{unit.name}/v#{version}",
        "-H", "Accept: application/vnd.github.v3+json"
      ]
      result = @utils.exec(cmd, out: :null, e: false)
      return false unless result.success?
      @utils.warn("GitHub release already exists for #{unit.name} #{version}. Skipping.")
      result.successes << "GitHub release already exists for #{unit.name} #{version}"
      true
    end

    def pre_build(unit, version)
      unit.cd do
        Array(unit.settings.pre_clean_dirs).each do |dir|
          ::FileUtils.rm_rf(dir)
        end
      end
      tool_spec = unit.settings.pre_builder_tool
      return unless tool_spec
      @utils.log("Running pre-build tool for #{unit.name} ...")
      unit.cd do
        exec_result = @utils.exec_separate_tool(tool_spec, e: false)
        @utils.error("Pre-build failed for #{unit.name}. Check the logs for details.") unless exec_result.success?
      end
      @utils.log("Completed pre-build tool for #{unit.name}")
    end

    def build_gem(unit, version)
      @utils.log("Running gem build for #{unit.name} ...")
      unit.cd do
        ::FileUtils.mkdir_p("pkg")
        cmd = ["gem", "build", "#{unit.name}.gemspec", "-o", "pkg/#{unit.name}-#{version}.gem"]
        exec_result = @utils.exec(cmd, e: false)
        @utils.error("Gem build failed for #{unit.name}. Check the logs for details.") unless exec_result.success?
      end
      @utils.log("Completed gem build for #{unit.name}")
    end

    def build_docs(unit, version)
      return false unless unit.gh_pages_enabled
      unit.cd do
        tool_spec = unit.settings.docs_builder_tool
        exec_result = 
          if tool_spec
            @utils.log("Running custom docs build tool for #{unit.name} ...")
            @utils.exec_separate_tool(tool_spec, e: false)
          else
            @utils.log("Running standard docs build for #{unit.name} ...")
            ::FileUtils.rm_rf(".yardoc")
            ::FileUtils.rm_rf("doc")
            @utils.exec(["bundle", "exec", "yard", "doc"], e: false)
          end
        @utils.error("Docs build failed for #{unit.name}. Check the logs for details.") unless exec_result.success?
      end
      @utils.log("Completed docs build for #{unit.name}")
      true
    end

    def push_gem(unit, version, result)
      @utils.log("Running gem push for #{unit.name} ...")
      if @dry_run
        @utils.log("DRY RUN: Gem not actually pushed to Rubygems")
        result.successes << "DRY RUN Rubygems push for #{unit.name} #{version}."
      else
        unit.cd do
          exec_result = @utils.exec(["gem", "push", "pkg/#{unit.name}-#{version}.gem"], e: false)
          if exec_result.success?
            result.successes << "Pushed #{unit.name} #{version} to Rubygems."
          else
            @utils.error("Gem push failed for #{unit.name}. Check the logs for details.")
          end
        end
      end
      @utils.log("Completed gem push for #{unit.name}")
    end

    def push_docs(unit, version, result)
      @utils.log("Running docs push for #{unit.name} ...")
      from_dir = ::File.join(unit.directory(from: :absolute), "doc")
      to_dir = ::File.join(::File.expand_path(unit.gh_pages_directory, @gh_pages_dir), "v#{version}")
      ::FileUtils.rm_rf(to_dir)
      ::FileUtils.mkdir_p(to_dir)
      ::FileUtils.cp_r(from_dir, to_dir)
      path_404 = ::File.join(@gh_pages_dir, "404.html")
      content = ::File.read(path_404)
      content.sub!(/#{unit.gh_pages_version_var} = "[\w.]+";/, "#{unit.gh_pages_version_var} = \"#{version}\";")
      ::File.write(path_404, content)
      ::Dir.chdir(@gh_pages_dir) do
        @repository.git_commit("Generated docs for #{unit.name} #{version}",
                               signoff: @repository.settings.signoff_commits?)
        if @dry_run
          @utils.log("DRY RUN: Documentation not actually published to gh-pages.")
          result.successes << "DRY RUN documentation publish for #{unit.name} #{version}."
        else
          exec_result = @utils.exec(["git", "push", @git_remote, "gh-pages"], e: false)
          if exec_result.success?
            result.successes << "Published documentation for #{unit.name} #{version}."
          else
            @utils.error("Docs publication failed for #{unit.name}. Check the logs for details.")
          end
        end
      end
      @utils.log("Completed docs push for #{unit.name}")
    end

    def github_release(unit, version, result)
      @utils.log("Running github release for #{unit.name} ...")
      if @dry_run
        @utils.log("DRY RUN: GitHub release not actually done.")
        result.successes << "DRY RUN GitHub release for #{unit.name} #{version}."
      else
        unit.cd do
          changelog_content = unit.changelog_file.read_and_verify_latest_entry(version)
          body = ::JSON.dump(tag_name: "#{unit.name}/v#{version}",
                            target_commitish: @release_sha,
                            name: "#{unit.name} #{version}",
                            body: changelog_content.to_s.strip)
          cmd = ["gh", "api", "repos/#{@settings.repo_path}/releases", "--input", "-",
                "-H", "Accept: application/vnd.github.v3+json"]
          exec_result = @utils.exec(cmd, in: [:string, body], out: :null, e: false)
          if exec_result.success?
            result.successes << "Created GitHub release for #{unit.name} #{version}."
          else
            @utils.error("GitHub release failed for #{unit.name}. Check the logs for details.")
          end
        end
      end
      @utils.log("Completed github release for #{unit.name}")
    end

    def post_build(unit, version)
      tool_spec = unit.settings.post_builder_tool
      if tool_spec
        @utils.log("Running post-build tool for #{unit.name} ...")
        unit.cd do
          exec_result = @utils.exec_separate_tool(tool_spec, e: false)
          @utils.error("Post-build failed for #{unit.name}. Check the logs for details.") unless exec_result.success?
        end
        @utils.log("Completed post-build tool for #{unit.name}")
      end
      unit.cd do
        Array(unit.settings.post_clean_dirs).each do |dir|
          ::FileUtils.rm_rf(dir)
        end
      end
    end
  end
end
