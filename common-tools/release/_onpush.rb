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

  require "environment_utils"
  require "repo_settings"
  require "repository"

  @utils = ToysReleaser::EnvironmentUtils.new(self)
  @settings = ToysReleaser::RepoSettings.load_from_environment(@utils)
  @repository = ToysReleaser::Repository.new(@utils, @settings)
end

def update_open_release_prs
  push_branch = @repository.current_branch
  logger.info("Searching for open release PRs targeting branch #{push_branch} ...")
  pr_message = nil
  @repository.find_release_prs(branch: push_branch).each do |pull|
    pr_message ||= build_pr_message
    logger.info("Updating PR #{pull.number} ...")
    pull.add_comment(pr_message)
  end
  if pr_message
    logger.info("Finished updating existing release PRs.")
  else
    logger.info("No existing release PRs target branch #{push_branch}.")
  end
end

def build_pr_message
  commit_message = capture(["git", "log", "-1", "--pretty=%B"], e: true)
  <<~STR
    WARNING: An additional commit was added while this release PR was open.
    You may need to add to the changelog, or close this PR and prepare a new one.

    Commit link: https://github.com/#{@settings.repo_path}/commit/#{@repository.current_sha}

    Message:
    #{commit_message}
  STR
end
