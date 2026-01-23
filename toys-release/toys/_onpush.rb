# frozen_string_literal: true

desc "Update open releases after a push"

long_desc \
  "This tool is called by a GitHub Actions workflow after a commit is pushed" \
    " to a releasable branch. It adds a warning note to any relevant open" \
    " releases that additional commits have been added."

include :exec
include :terminal, styled: true

def run
  setup
  update_open_release_prs
end

def setup
  ::Dir.chdir(context_directory)

  require "toys/release/environment_utils"
  require "toys/release/repo_settings"
  require "toys/release/repository"
  require "toys/release/request_logic"
  require "toys/release/request_spec"

  @utils = Toys::Release::EnvironmentUtils.new(self)
  @settings = Toys::Release::RepoSettings.load_from_environment(@utils)
  @repository = Toys::Release::Repository.new(@utils, @settings)
  @push_branch = @repository.current_branch
  @push_sha = @repository.current_sha
end

def update_open_release_prs
  logger.info("Searching for open release PRs targeting branch #{@push_branch} ...")
  release_prs = @repository.find_release_prs(branch: @push_branch)
  release_prs.each do |pull|
    if @settings.update_existing_requests
      maybe_update_release_pr(pull)
    else
      logger.info("Adding warning comment to PR #{pull.number} ...")
      pull.add_comment(pr_warning_message)
    end
  end
  if release_prs.empty?
    logger.info("No existing release PRs target branch #{@push_branch}.")
  else
    logger.info("Finished updating existing release PRs.")
  end
end

def pr_warning_message
  @pr_warning_message ||= begin
    commit_message = capture(["git", "log", "-1", "--pretty=%B"], e: true)
    <<~STR
      WARNING: An additional commit was added while this release PR was open.
      You may need to add to the changelog, or close this PR and prepare a new one.

      Commit link: https://github.com/#{@settings.repo_path}/commit/#{@push_sha}

      Message:
      #{commit_message}
    STR
  end
end

def maybe_update_release_pr(pull)
  errors = []
  @utils.capture_errors(errors) do
    request_spec = recreate_request_spec(pull)
    if request_spec.significant_sha?(request_spec.release_sha)
      update_release_pr(pull, request_spec)
    else
      logger.info("Commit is not significant for PR #{pull.number}.")
    end
  end
  unless errors.empty?
    logger.info("Encountered errors updating PR #{pull.number}. Adding warning comment instead ...")
    pull.add_comment(pr_error_message(errors))
  end
end

def recreate_request_spec(pull)
  input_string = pull.request_input_string
  @utils.error("Could not find metadata in PR #{pull.number}") unless input_string
  request_spec = Toys::Release::RequestSpec.new(@utils)
  request_spec.add_from_input_string(input_string, @repository)
  request_spec.resolve_versions(@repository, release_ref: @push_branch)
  request_spec
end

def update_release_pr(pull, request_spec)
  request_logic = Toys::Release::RequestLogic.new(@repository, request_spec)
  release_branch = pull.head_ref
  @repository.create_branch(release_branch)
  commit_title = request_logic.build_commit_title
  commit_details = request_logic.build_commit_details
  signoff = @repository.settings.signoff_commits?
  request_logic.change_files
  @repository.git_commit(commit_title, commit_details: commit_details, signoff: signoff)
  @utils.exec(["git", "push", "-f", "origin", release_branch])
  @utils.exec(["git", "switch", @push_branch])
  pull.add_comment(pr_updated_message)
end

def pr_updated_message
  @pr_updated_message ||= begin
    commit_message = capture(["git", "log", "-1", "--pretty=%B"], e: true)
    <<~STR
      NOTE: An additional commit was added while this release PR was open.
      This release PR has been updated to reflect the change.

      Commit link: https://github.com/#{@settings.repo_path}/commit/#{@push_sha}

      Message:
      #{commit_message}
    STR
  end
end
