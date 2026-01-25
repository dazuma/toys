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
  if @repository.release_related_branch?(@push_branch)
    logger.info("Ignoring push to release branch.")
    exit
  end
  @push_sha = @repository.current_sha
  if @settings.update_existing_requests
    @repository.git_set_user_info
    @repository.git_prepare_branch("origin", branch: @push_branch)
  end
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

def maybe_update_release_pr(pull)
  errors = []
  @utils.capture_errors(errors) do
    request_spec = recreate_request_spec(pull)
    if request_spec.significant_sha?(request_spec.release_sha)
      update_release_pr(pull, request_spec)
    else
      logger.info("Commit is not significant for PR #{pull.number}.")
      return
    end
  end
  if errors.empty?
    logger.info("Recreated release PR #{pull.number}.")
    pull.add_comment(pr_updated_message)
  else
    logger.info("Encountered errors updating PR #{pull.number}. Adding warning comment instead ...")
    pull.add_comment(pr_error_message(errors))
  end
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
  body = request_logic.build_pr_body
  pull.update(body: body, title: commit_title)
  @utils.exec(["git", "switch", @push_branch])
end

def last_commit_message
  @last_commit_message ||= capture(["git", "log", "-1", "--pretty=%B"], e: true).strip
end

def pr_warning_message
  <<~STR
    WARNING: An additional commit was added while this release PR was open.
    You may need to add to the changelog, or close this PR and prepare a new one.

    Commit link: https://github.com/#{@settings.repo_path}/commit/#{@push_sha}

    Commit message:
    ```
    #{last_commit_message}
    ```
  STR
end

def pr_updated_message
  <<~STR
    NOTE: An additional commit was added while this release PR was open.
    This release PR has been updated to reflect the change.

    Commit link: https://github.com/#{@settings.repo_path}/commit/#{@push_sha}

    Commit message:
    ```
    #{last_commit_message}
    ```
  STR
end

def pr_error_message(errors)
  errors_str = errors.map { |str| "* #{str}" }.join("\n")
  <<~STR
    WARNING: An additional commit was added while this release PR was open.
    Additionally, this release PR could not be updated due to errors.

    Commit link: https://github.com/#{@settings.repo_path}/commit/#{@push_sha}

    Commit message:
    ```
    #{last_commit_message}
    ```

    Errors:
    #{errors_str}
  STR
end
