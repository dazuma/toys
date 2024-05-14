# frozen_string_literal: true

require "json"
require "yaml"
require_relative "releasable_unit"

module ToysReleaser
  ##
  # Represents a repository in the release system
  #
  class Repository
    ##
    # Create a repository
    #
    # @param environment_utils [ToysReleaser::EnvrionmentUtils]
    # @param settings [ToysReleaser::RepoSettings]
    #
    def initialize(environment_utils, settings)
      @utils = environment_utils
      @settings = settings
      build_releasable_units
      ensure_gh_binary
      ensure_git_binary
    end

    ##
    # @return [ToysReleaser::RepoSettings] The repo settings
    #
    attr_reader :settings

    ##
    # @return [ToysReleaser::EnvironmentUtils] The environment utils
    #
    attr_reader :utils

    ##
    # @return [Array<Array<ToysReleaser::ReleasableUnit>>] All coordination
    #     groups
    #
    attr_reader :coordination_groups

    ##
    # @return [ToysReleaser::ReleasableUnit,nil] The releasable unit for the
    #     given name, or nil if the name is not known.
    #
    def releasable_unit(name)
      @releasable_units[name]
    end

    ##
    # @return [Array<ToysReleaser::ReleasableUnit>] All releasable units
    #
    def all_releasable_units
      @releasable_units.values
    end

    ##
    # @return [String] The name of the release branch for a given unit name
    #
    def release_branch_name(unit_name)
      "#{settings.release_branch_prefix}/#{unit_name}"
    end

    ##
    # @return [String] A unique branch name for a multi-release
    #
    def multi_release_branch_name
      timestamp = ::Time.now.strftime("%Y%m%d%H%M%S")
      "#{settings.release_branch_prefix}/multi/#{timestamp}"
    end

    ##
    # Recover a unit name from a release branch name
    #
    # @param name [String] The branch name
    # @return [String,nil] The unit name, or nil if not a release branch
    #
    def unit_name_from_release_branch(name)
      match = %r{^#{settings.release_branch_prefix}/([^/]+)$}.match(name)
      match ? match[1] : nil
    end

    ##
    # @return [boolean] Whether the given branch name is release-related
    #
    def release_related_branch?(ref)
      %r{^#{settings.release_branch_prefix}/([^/]+|multi/\d+)$}.match(ref) ? true : false
    end

    ##
    # @return [boolean] Whether the given label name is release-related
    #
    def release_related_label?(name)
      [
        settings.release_pending_label,
        settings.release_error_label,
        settings.release_aborted_label,
        settings.release_complete_label
      ].include?(name)
    end

    ##
    # Return the SHA of the given ref
    #
    # @param ref [String,nil] Optional ref. Defaults to HEAD.
    # @return [String] the SHA
    #
    def current_sha(ref = nil)
      @utils.capture(["git", "rev-parse", ref || "HEAD"]).strip
    end

    ##
    # Return the current branch
    #
    # @return [String,nil] the branch name, or nil if no branch is checked out
    #
    def current_branch
      branch = @utils.capture(["git", "branch", "--show-current"]).strip
      branch.empty? ? nil : branch
    end

    ##
    # Return the url of the given git remote
    #
    # @param remote [String] The name of the remote
    # @return [String] the URL of the remote
    #
    def git_remote_url(remote)
      @utils.capture(["git", "remote", "get-url", remote]).strip
    end
  
    ##
    # Searches for existing release pull requests
    #
    # @param unit_name [String,nil] Optional unit name
    # @param merge_sha [String,nil] Optional sha of the merge point.
    #     If provided, returns the single unique pull request, otherwise
    #     returns an array of matching pull requests.
    # @param label [String,nil] Optional label to look for. Defaults to the
    #     release-pending label.
    #
    # @return [Hash,nil] Pull request info for the PR matching the merge_sha,
    #     or nil if none match.
    # @return [Array<Hash>] Array of matching pull request infos if merge_sha
    #     is not provided.
    #
    def find_release_prs(unit_name: nil, merge_sha: nil, label: nil)
      label ||= settings.release_pending_label
      args = {
        state: merge_sha ? "closed" : "open",
        sort: "updated",
        direction: "desc",
        per_page: 20,
      }
      if unit_name
        args[:head] = "#{repo_owner}:#{release_branch_name(unit_name)}"
        args[:sort] = "created"
      end
      query = args.map { |k, v| "#{k}=#{v}" }.join("&")
      output = @utils.capture(["gh", "api", "repos/#{settings.repo_path}/pulls?#{query}",
                               "-H", "Accept: application/vnd.github.v3+json"])
      prs = ::JSON.parse(output)
      if merge_sha
        prs.find do |pr_info|
          pr_info["merged_at"] && pr_info["merge_commit_sha"] == merge_sha
        end
      else
        prs.find_all do |pr_info|
          pr_info["labels"].any? { |label_info| label_info["name"] == label }
        end
      end
    end

    ##
    # Load a pull request by number
    #
    # @param pr_number [String,Integer] Pull request number
    # @return [Hash,nil] Pull request info, or nil if not found
    #
    def load_pr(pr_number)
      result = @utils.exec(["gh", "api", "repos/#{settings.repo_path}/pulls/#{pr_number}",
                            "-H", "Accept: application/vnd.github.v3+json"],
                           out: :capture, exit_on_nonzero_status: false)
      return nil unless result.success?
      ::JSON.parse(result.captured_out)
    end

    ##
    # Perform various updates to a pull request
    #
    # @param pr_number [String,Integer] The pull request number
    # @param labels [String,Array<String>,nil] One or more release-related
    #     labels that should be applied. All existing release-related labels
    #     are replaced with this list. Optional; no label updates are applied
    #     if not present.
    # @param state [String,nil] New pull request state. Optional; the state is
    #     not modified if not present.
    # @param message [String,nil] A comment to add to the pull request.
    #     Optional.
    # @param cur_pr [Hash,nil] The current pull request info if available.
    #     Optional; the pull request will be loaded if not provided.
    #
    def update_release_pr(pr_number, labels: nil, state: nil, message: nil, cur_pr: nil)
      cur_pr ||= load_pr(pr_number)
      labels = Array(labels)
      update_pr_labels(cur_pr, labels) unless labels.empty?
      update_pr_state(cur_pr, state) if state
      add_pr_message(pr_number, message) if message
      self
    end

    ##
    # Open a GitHub issue
    #
    # @param title [String] The issue title
    # @param body [String] The issue body
    # @return [Hash] The issue resource
    #
    def open_issue(title, body)
      input = ::JSON.dump(title: title, body: body)
      cmd = [
        "gh", "api", "repos/#{settings.repo_path}/issues",
        "--input", "-",
        "-H", "Accept: application/vnd.github.v3+json"
      ]
      response = @utils.capture(cmd, in: [:string, input])
      ::JSON.parse(response)
    end

    ##
    # Verify that the given git remote points at the correct repo.
    # Raises errors if not.
    #
    # @param remote [String] The remote name. Defaults to `origin`.
    # @return [String] The repo in `owner/repo` form
    #
    def verify_repo_identity(remote: "origin")
      @utils.log("Verifying git repo identity ...")
      url = git_remote_url(remote)
      cur_repo =
        case url
        when %r{^git@github.com:(?<git_repo>[^/]+/[^/]+)\.git$}
          ::Regexp.last_match[:git_repo]
        when %r{^https://github.com/(?<http_repo>[^/]+/[^/.]+)(?:/|\.git)?$}
          ::Regexp.last_match[:http_repo]
        else
          @utils.error("Unrecognized remote url: #{url.inspect}")
        end
      if cur_repo == settings.repo_path
        @utils.log("Git repo is correct.")
      else
        @utils.error("Remote repo is #{cur_repo}, expected #{settings.repo_path}")
      end
      cur_repo
    end

    ##
    # @return [boolean] Whether the current git checkout is clean
    #
    def git_clean?
      @utils.capture(["git", "status", "-s"]).strip.empty?
    end

    ##
    # Verify that the git checkout is clean.
    # Raises errors if not.
    #
    def verify_git_clean
      if git_clean?
        @utils.log("Git working directory verified as clean.")
      else
        @utils.error("There are local git changes that are not committed.")
      end
      self
    end

    ##
    # Verify that github checks have succeeded.
    # Raises errors if not.
    #
    # @param ref [String,nil] The ref to check. Optional, defaults to HEAD.
    #
    def verify_github_checks(ref: nil)
      if @settings.required_checks_regexp.nil?
        @utils.log("GitHub checks disabled")
        return self
      end
      ref = current_sha(ref)
      @utils.log("Verifying GitHub checks ...")
      errors = github_check_errors(ref)
      @utils.error(*errors) unless errors.empty?
      @utils.log("GitHub checks all passed.")
      self
    end

    ##
    # Wait until github checks have finished.
    # Returns a set of errors or the empty array if succeeded.
    #
    # @param ref [String,nil] The ref to check. Optional, defaults to HEAD.
    # @return [Array<String>] Errors
    #
    def wait_github_checks(ref: nil)
      if @settings.required_checks_regexp.nil?
        @utils.log("GitHub checks disabled")
        return self
      end
      deadline = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC) + @settings.required_checks_timeout
      wait_github_checks_internal(current_sha(ref), deadline)
    end

    ##
    # Ensure that the git user name and email are set.
    #
    def git_set_user_info
      if @settings.git_user_name
        unless @utils.exec(["git", "config", "--get", "user.name"], out: :null, e: false).success?
          @utils.exec(["git", "config", "--local", "user.name", @settings.git_user_name])
        end
      end
      if @settings.git_user_email
        unless @utils.exec(["git", "config", "--get", "user.email"], out: :null, e: false).success?
          @utils.exec(["git", "config", "--local", "user.email", @settings.git_user_email])
        end
      end
      self
    end

    ##
    # Fetch the repository history and tags for the given ref
    #
    # @param remote [String] The remote to fetch from.
    # @param branch [String,nil] The head branch to fetch, or nil to use the
    #     current branch.
    # @return [String] The actual branch
    #
    def git_prepare_branch(remote, branch: nil)
      git_unshallow(remote, branch: branch)
      @utils.exec(["git", "fetch", remote, "--tags"])
      if branch && branch != current_branch
        @utils.exec(["git", "switch", branch])
        branch
      else
        current_branch
      end
    end

    ##
    # Ensure the given branch is fully fetched including all history
    #
    # @param remote [String] The remote to fetch from.
    # @param branch [String,nil] The head branch to fetch, or nil to use the
    #     current branch.
    # @return [boolean] Whether commits needed to be fetched.
    #
    def git_unshallow(remote, branch: nil)
      if @utils.capture(["git", "rev-parse", "--is-shallow-repository"]).strip == "true"
        @utils.exec(["git", "fetch", "--unshallow", remote, branch || "HEAD"])
        true
      else
        false
      end
    end

    ##
    # Returns what units and versions are being released in the pull request
    #
    # @param pr_info [Hash] pull request info
    # @return [Hash{String=>String}] Map of unit names to versions
    #
    def released_units_and_versions(pr_info)
      single_released_unit_and_version(pr_info) || multiple_released_units_and_versions(pr_info)
    end

    ##
    # Switch to the given SHA temporarily and execute the given block.
    #
    # @param sha [String] The SHA to switch to
    # @return [Object] Whatever the block returns
    #
    def at_sha(sha, quiet: false)
      out = quiet ? :null : :inherit
      original_branch = current_branch
      original_sha = current_sha
      if sha != original_sha
        @utils.exec(["git", "switch", "--detach", sha], out: out, err: out)
      end
      yield
    ensure
      if sha != original_sha
        if original_branch
          @utils.exec(["git", "switch", original_branch], out: out, err: out)
        else
          @utils.exec(["git", "switch", "--detach", original_sha], out: out, err: out)
        end
      end
    end

    ##
    # Returns the commit message for the given ref
    #
    # @param ref [String] Git ref. Defaults to "HEAD" if not provided.
    # @return [String] The full commit message
    #
    def last_commit_message(ref: nil)
      ref ||= "HEAD"
      @utils.capture(["git", "log", "#{ref}^..#{ref}", "--format=%B"]).strip
    end

    ##
    # Create and switch to a new branch. Deletes and overwrites any existing
    # branch of that name.
    #
    # @param branch [String] Name for the branch
    #
    def create_branch(branch, quiet: false)
      out = quiet ? :null : :inherit
      if current_branch == branch
        @utils.exec(["git", "switch", settings.main_branch], out: out, err: out)
      end
      if @utils.exec(["git", "rev-parse", "--verify", "--quiet", branch], out: :null, e: false).success?
        @utils.warning("Branch #{branch} already exists. Deleting it.")
        @utils.exec(["git", "branch", "-D", branch], out: out, err: out)
      end
      @utils.exec(["git", "switch", "-c", branch], out: out, err: out)
      self
    end

    ##
    # Commit the current changes.
    #
    # @param commit_title [String] Title for the commit
    # @param commit_details [String] Multi-line commit details
    # @param signoff [boolean] Whether to sign off
    #
    def git_commit(commit_title,
                   commit_details: nil,
                   signoff: false)
      @utils.exec(["git", "add", "."])
      commit_cmd = ["git", "commit", "-a", "-m", commit_title]
      commit_cmd << "-m" << commit_details if commit_details
      commit_cmd << "--signoff" if signoff
      @utils.exec(commit_cmd)
      self
    end

    ##
    # Create a pull request for the current branch.
    #
    # @param base_branch [String] Base branch. Defaults to the main branch.
    # @param remote [String] Name of the git remote. Defaults to "origin".
    # @param title [String] Pull request title. Defaults to the last commit
    #     message.
    # @param body [String] Pull request body. Defaults to empty.
    # @param labels [Array<String>] Any labels to apply. Defaults to none.
    # @return [Hash] Pull request resource.
    #
    def create_pull_request(base_branch: nil,
                            remote: nil,
                            title: nil,
                            body: nil,
                            labels: nil)
      base_branch ||= settings.main_branch
      remote ||= "origin"
      if !title || !body
        message = last_commit_message.split(/(?:\r?\n)+/, 2)
        title ||= message.first
        body ||= message[1] || ""
      end
      head_branch = current_branch
      @utils.exec(["git", "push", "-f", remote, head_branch])
      body = ::JSON.dump(title: title,
                         head: head_branch,
                         base: base_branch,
                         body: body,
                         maintainer_can_modify: true)
      response = @utils.capture(["gh", "api", "repos/#{settings.repo_path}/pulls", "--input", "-",
                                "-H", "Accept: application/vnd.github.v3+json"],
                                in: [:string, body])
      pr_info = ::JSON.parse(response)
      pr_number = pr_info["number"]
      labels = Array(labels)
      update_release_pr(pr_number, labels: labels, cur_pr: pr_info) unless labels.empty?
      pr_number
    end

    ##
    # Check out to a separate directory
    #
    # @param branch [String] The branch to check out. Defaults to "main".
    # @param remote [String] The remote to pull from. Defaults to "origin".
    # @param dir [String] The diretory to checkout to. If not provided, creates
    #     a temporary directory and removes it at process termination.
    # @param gh_token [String] A GitHub token to use for authenticating to
    #     GitHub when the remote has an https URL.
    #
    # @return [String] The path to the directory.
    #
    def checkout_separate_dir(branch: nil, remote: nil, dir: nil, gh_token: nil)
      branch ||= "main"
      remote ||= "origin"
      if dir
        ::FileUtils.remove_entry(dir, true)
        ::FileUtils.mkdir_p(dir)
      else
        dir = ::Dir.mktmpdir
        at_exit { ::FileUtils.remove_entry(dir, true) }
      end
      remote_url = git_remote_url(remote)
      ::Dir.chdir(dir) do
        @utils.exec(["git", "init"])
        @repository.git_set_user_info
        if remote_url.start_with?("https://github.com/") && gh_token
          encoded_token = ::Base64.strict_encode64("x-access-token:#{gh_token}")
          log_cmd = '["git", "config", "--local", "http.https://github.com/.extraheader", "****"]'
          @utils.exec(["git", "config", "--local", "http.https://github.com/.extraheader",
                       "Authorization: Basic #{encoded_token}"],
                      log_cmd: log_cmd)
        end
        @utils.exec(["git", "remote", "add", remote, remote_url])
        @utils.exec(["git", "fetch", "--no-tags", "--depth=1", "--no-recurse-submodules",
                     remote, branch])
        @utils.exec(["git", "branch", branch, "#{remote}/#{branch}"])
        @utils.exec(["git", "switch", branch])
      end
      dir
    end

    private

    def build_releasable_units
      @releasable_units = {}
      @utils.accumulate_errors("Errors while validating releasable units") do
        settings.all_unit_names.each do |name|
          releasable = ReleasableUnit.build(settings, name, @utils)
          releasable.validate
          @releasable_units[releasable.name] = releasable
        end
      end
      @coordination_groups = []
      settings.coordination_groups.each do |name_group|
        unit_group = name_group.map { |name| @releasable_units[name] }
        unit_group.each { |unit| unit.coordination_group = unit_group }
        @coordination_groups << unit_group
      end
      @releasable_units.each_value do |unit|
        next if unit.coordination_group
        @coordination_groups << (unit.coordination_group = [unit])
      end
      self
    end

    def ensure_gh_binary
      result = @utils.exec(["gh", "--version"], out: :capture, e: false)
      match = /^gh version (\d+)\.(\d+)\.(\d+)/.match(result.captured_out.to_s)
      if !result.success? || !match
        @utils.error("gh not installed.",
                     "See https://cli.github.com/manual/installation for install instructions.")
      end
      version_val = match[1].to_i * 1_000_000 + match[2].to_i * 1000 + match[3].to_i
      version_str = "#{match[1]}.#{match[2]}.#{match[3]}"
      if version_val < 10_000
        @utils.error("gh version 0.10 or later required but #{version_str} found.",
                     "See https://cli.github.com/manual/installation for install instructions.")
      end
      @utils.log("gh version #{version_str} found")
      self
    end
  
    def ensure_git_binary
      result = @utils.exec(["git", "--version"], out: :capture, e: false)
      match = /^git version (\d+)\.(\d+)\.(\d+)/.match(result.captured_out.to_s)
      if !result.success? || !match
        @utils.error("git not installed.",
                     "See https://git-scm.com/downloads for install instructions.")
      end
      version_val = match[1].to_i * 1_000_000 + match[2].to_i * 1000 + match[3].to_i
      version_str = "#{match[1]}.#{match[2]}.#{match[3]}"
      if version_val < 2_022_000
        @utils.error("git version 2.22 or later required but #{version_str} found.",
                     "See https://git-scm.com/downloads for install instructions.")
      end
      @utils.log("git version #{version_str} found")
      self
    end

    def update_pr_labels(cur_pr, labels)
      labels = Array(labels)
      cur_labels = cur_pr["labels"].map { |label_info| label_info["name"] }
      release_labels, other_labels = cur_labels.partition { |name| release_related_label?(name) }
      return if release_labels.sort == labels.sort
      body = ::JSON.dump(labels: other_labels + labels)
      pr_number = cur_pr["number"]
      @utils.exec(["gh", "api", "-XPATCH", "repos/#{settings.repo_path}/issues/#{pr_number}",
                   "--input", "-", "-H", "Accept: application/vnd.github.v3+json"],
                  in: [:string, body], out: :null)
      self
    end

    def update_pr_state(cur_pr, state)
      return if cur_pr["state"] == state
      body = ::JSON.dump(state: state)
      pr_number = cur_pr["number"]
      @utils.exec(["gh", "api", "-XPATCH", "repos/#{settings.repo_path}/pulls/#{pr_number}",
                   "--input", "-", "-H", "Accept: application/vnd.github.v3+json"],
                  in: [:string, body], out: :null)
      self
    end

    def add_pr_message(pr_number, message)
      body = ::JSON.dump(body: message)
      @utils.exec(["gh", "api", "repos/#{settings.repo_path}/issues/#{pr_number}/comments",
                   "--input", "-", "-H", "Accept: application/vnd.github.v3+json"],
                  in: [:string, body], out: :null)
      self
    end

    def wait_github_checks_internal(ref, deadline)
      interval = 10
      loop do
        @utils.log("Polling GitHub checks ...")
        errors = github_check_errors(ref)
        if errors.empty?
          @utils.log("GitHub checks all passed.")
          return []
        end
        errors.each { |msg| @utils.log(msg) }
        if ::Process.clock_gettime(::Process::CLOCK_MONOTONIC) > deadline
          results = ["GitHub checks still failing after #{required_checks_timeout} secs."]
          return results + errors
        end
        @utils.log("Sleeping for #{interval} secs ...")
        sleep(interval)
        interval += 10 unless interval >= 60
      end
    end
  
    def github_check_errors(ref)
      result = @utils.exec(["gh", "api", "repos/#{settings.repo_path}/commits/#{ref}/check-runs",
                            "-H", "Accept: application/vnd.github.antiope-preview+json"],
                           out: :capture, e: false)
      return ["Failed to obtain GitHub check results for #{ref}"] unless result.success?
      checks = ::JSON.parse(result.captured_out)["check_runs"]
      results = []
      results << "No GitHub checks found for #{ref}" if checks.empty?
      checks.each do |check|
        name = check["name"]
        next if @settings.release_jobs_regexp.match(name)
        next unless @settings.required_checks_regexp.match(name)
        if check["status"] != "completed"
          results << "GitHub check #{name.inspect} is not complete"
        elsif check["conclusion"] != "success"
          results << "GitHub check #{name.inspect} was not successful"
        end
      end
      results
    end

    ##
    # Attempt to get the unit and version from the pull request branch name
    #
    def single_released_unit_and_version(pr_info)
      unit_name =
        if @settings.all_unit_names.size == 1
          @settings.default_unit_name
        else
          unit_name_from_release_branch(pr_info["head"]["ref"])
        end
      return nil unless unit_name
      unit = releasable_unit(unit_name)
      unless unit
        @utils.warning("Release branch references nonexistent unit #{unit_name.inspect}")
        return nil
      end
      merge_sha = pr_info["merge_commit_sha"]
      version = unit.current_version(at: merge_sha)
      @utils.log("Found single unit to release: #{unit_name} #{version}.")
      { unit_name => version }
    end

    ##
    # Get units and versions from the pull request content
    #
    def multiple_released_gems_and_versions(pr_info)
      merge_sha = pr_info["merge_commit_sha"]
      output = @utils.capture(["git", "diff", "--name-only", "#{merge_sha}^..#{merge_sha}"])
      files = output.split("\n")
      units = all_releasable_units.find_all do |unit|
        dir = unit.directory
        files.any? { |file| file.start_with?(dir) }
      end
      units.each_with_object({}) do |unit, result|
        result[unit.name] = version = unit.current_version(at: merge_sha)
        @utils.log("Releasing gem due to file changes: #{unit.name} #{version}.")
      end
    end
  end
end
