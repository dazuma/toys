# frozen_string_literal: true

desc "Process a release pull request"

long_desc \
  "This tool is called by a GitHub Actions workflow after a release pull" \
    " request is closed. If the pull request was merged, the requested" \
    " release is performed and the pull request is updated with the results." \
    " If the pull request was closed without being merged, the pull request" \
    " is marked as aborted. This tool also ensures that release branches are" \
    " deleted once their PRs are closed."

flag :enable_releases, "--enable-releases=VAL" do
  default "true"
  desc "Control whether to enable releases."
  long_desc \
    "If set to 'true', releases will be enabled. Any other value will" \
    " result in dry-run mode, meaning it will go through the motions," \
    " create a GitHub release, and update the release pull request if" \
    " applicable, but will not actually push the gem to Rubygems or push" \
    " the docs to gh-pages."
end
flag :event_path, "--event-path=VAL" do
  default ::ENV["GITHUB_EVENT_PATH"]
  desc "Path to the pull request closed event JSON file"
end
flag :rubygems_api_key, "--rubygems-api-key=VAL" do
  desc "Set the Rubygems API key"
  long_desc \
    "Use the given Rubygems API key when pushing to Rubygems. Deprecated;" \
    " prefer just setting the `GEM_HOST_API_KEY` environment variable."
end

include :exec
include :terminal, styled: true

def run
  setup

  ::ENV["GEM_HOST_API_KEY"] = rubygems_api_key unless rubygems_api_key.to_s.empty?
  @utils.error("GitHub event path missing") unless event_path
  @pr_info = ::JSON.parse(::File.read(event_path))["pull_request"]

  delete_release_branch
  check_for_release_pr
  if @pr_info["merged_at"]
    handle_release_merged
  else
    handle_release_aborted
  end
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

def delete_release_branch
  source_ref = @pr_info["head"]["ref"]
  if @repository.release_related_branch?(source_ref)
    logger.info("Deleting release branch #{source_ref} ...")
    exec(["git", "push", "--delete", "origin", source_ref])
    logger.info("Deleted.")
  end
end

def check_for_release_pr
  pr_number = @pr_info["number"]
  if @pr_info["labels"].all? { |label_info| label_info["name"] != @utils.release_pending_label }
    logger.info("PR #{pr_number} does not have the release pending label. Ignoring.")
    exit
  end
end

def handle_release_aborted
  pr_number = @pr_info["number"]
  logger.info("Updating release PR #{pr_number} to mark it as aborted.")
  @utils.update_release_pr(pr_number,
                           label: @utils.release_aborted_label,
                           message: "Release PR closed without merging.",
                           state: "closed",
                           cur_pr: @pr_info)
  logger.info "Done."
end

def handle_release_merged
  setup_git
  performer = create_performer
  github_check_errors = @repository.wait_github_checks
  unless github_check_errors.empty?
    @utils.error("GitHub checks failed", *github_check_errors)
  end
  performer.perform_pr_releases
  performer.report_results
  if performer.error?
    @utils.error("Releases reported failure")
  else
    puts("All releases completed successfully", :bold, :green)
  end
end

def setup_git
  merge_sha = @pr_info["merge_commit_sha"]
  exec(["git", "fetch", "--depth=2", "origin", "+#{merge_sha}:refs/heads/release/current"], e: true)
  exec(["git", "switch", "release/current"], e: true)
end

def create_performer
  require "performer"
  dry_run = /^t/i =~ enable_releases.to_s ? false : true
  ToysReleaser::Performer.new(@repository,
                              release_pr: @pr_info,
                              git_remote: "origin",
                              capture_errors: true,
                              dry_run: dry_run)
end
