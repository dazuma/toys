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
  @utils.error("Cannot run the _onpush tool from detached HEAD") if @push_branch.nil?
  if @repository.release_related_branch?(@push_branch)
    logger.info("Ignoring push to release branch.")
    exit
  end
  @repository.git_set_user_info
  @repository.git_prepare_branch("origin", branch: @push_branch)
end

def update_open_release_prs
  logger.info("Searching for open release PRs targeting branch #{@push_branch} ...")
  release_prs = @repository.find_release_prs(branch: @push_branch)
  count = 0
  release_prs.each do |pull|
    relevant_commits = determine_relevant_commits(pull)
    if relevant_commits.nil?
      logger.info("No relevant commits for PR #{pull.number}")
    else
      if @settings.update_existing_requests
        errors = update_release_pr(pull)
        if errors.empty?
          add_updated_comment(pull, relevant_commits)
        else
          add_error_comment(pull, relevant_commits, errors)
        end
      else
        add_warning_comment(pull, relevant_commits)
      end
      count += 1
    end
  end
  logger.info("Updated #{count} release pull requests for target branch #{@push_branch}")
end

def determine_relevant_commits(pull)
  original_sha = pull.release_request_sha
  return true if original_sha.nil?
  requested_components = pull.requested_components
  return true if requested_components.nil?
  new_commits = @repository.commit_info_sequence(from: original_sha)
  relevant_shas = {}
  result = false
  requested_components.each_key do |comp_name|
    component = @repository.component_named(comp_name)
    if component.nil?
      @utils.warning("Unknown component #{comp_name.inspect} found in metadata for PR #{pull.number}")
      next
    end
    new_changes = component.make_change_set(commits: new_commits)
    new_changes.significant_shas.each { |sha| relevant_shas[sha] = true }
    result ||= !new_changes.empty?
  end
  return nil unless result
  new_commits.find_all { |commit| relevant_shas[commit.sha] }
end

def update_release_pr(pull)
  logger.info("Regenerating PR #{pull.number} ...")
  errors = []
  @utils.capture_errors(errors) do
    request_spec = recreate_request_spec(pull)
    request_logic = Toys::Release::RequestLogic.new(@repository, request_spec)
    request_logic.update_existing_pr(pull)
    @utils.exec(["git", "switch", @push_branch])
  end
  errors
end

def recreate_request_spec(pull)
  requested_components = pull.requested_components
  @utils.error("Could not find metadata in PR #{pull.number}") unless requested_components
  request_spec = Toys::Release::RequestSpec.new(@utils)
  requested_components.each do |component_name, version|
    component = @repository.component_named(component_name)
    if component.nil?
      @utils.error("Unknown component name #{component_name.inspect} in PR #{pull.number}")
    else
      request_spec.add(component, version: version)
    end
  end
  request_spec.resolve_versions(@repository.current_sha(@push_branch))
  request_spec
end

def add_warning_comment(pull, commits)
  logger.info("Commented on release PR #{pull.number} to warn about new commits.")
  comment = <<~STR
    WARNING: Additional commits were added while this release PR was open.
    You may need to add to the changelog, or close this PR and prepare a new one.

    #{commit_descriptions(commits)}
  STR
  pull.add_comment(comment)
end

def add_updated_comment(pull, commits)
  logger.info("Updated release PR #{pull.number} to reflect new commits.")
  comment = <<~STR
    NOTE: Additional commits were added while this release PR was open.
    This release PR has been updated to reflect the change.

    #{commit_descriptions(commits)}
  STR
  pull.add_comment(comment)
end

def add_error_comment(pull, commits, errors)
  logger.info("Commented on release PR #{pull.number} to note errors when attempting to reflect new commits.")
  errors_str = errors.map { |str| "* #{str}" }.join("\n")
  comment = <<~STR
    WARNING: Additional commits were added while this release PR was open.
    However, this release PR could not be updated due to errors:

    #{errors_str}

    #{commit_descriptions(commits)}
  STR
  pull.add_comment(comment)
end

def commit_descriptions(commits)
  commits.map do |commit|
    <<~STR
      ----

      Commit: https://github.com/#{@settings.repo_path}/commit/#{commit.sha}
      ```
      #{commit.message.strip}
      ```
    STR
  end.join("\n").strip
end
