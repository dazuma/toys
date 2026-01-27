# frozen_string_literal: true

desc "Releases pending releasable components for a pull request"

long_desc \
  "This tool continues the releases associated with a release pull request." \
    " It is normally used to retry or continue releases that aborted due to" \
    " an error. This tool is normally called from a GitHub Actions workflow," \
    " but can also be executed locally if the proper credentials are present."

required_arg :release_pr, accept: Integer do
  desc "Release pull request number. Required."
end
flag_group desc: "Flags" do
  flag :dry_run, "--[no-]dry-run" do
    desc "Run in dry-run mode."
    long_desc \
      "Run in dry-run mode, where checks are made and releases are built" \
      " but are not pushed."
  end
  flag :work_dir, "--work-dir=VAL" do
    desc "The directory to use for artifacts and temporary files"
    long_desc \
      "If provided, the given directory path is used for artifacts and" \
        " temporary files, and is left intact after the release so the" \
        " artifacts can be inspected. If omitted, a new temporary directory" \
        " is created, and is automatically deleted after the release."
  end
  flag :git_remote, "--git-remote=VAL" do
    default "origin"
    desc "The name of the git remote"
    long_desc \
      "The name of the git remote pointing at the canonical repository." \
      " Defaults to 'origin'."
  end
  flag :release_ref, "--release-ref=VAL", "--release-sha=VAL" do
    desc "Override the commit for the release"
    long_desc \
      "The SHA or ref to release from. This can be used if additional" \
      " changes are needed to fix the release. If not given, the merge SHA" \
      " of the pull request is used."
  end
  flag :enable_prechecks, "--[no-]enable-prechecks" do
    default true
    desc "Enables pre-release checks. Enabled by default."
    long_desc \
      "Enables pre-release checks. Enabled by default. It may occasionally" \
      " be useful to disable this to repair a broken release, but it is" \
      " generally not recommended."
  end
  flag :yes, "--yes", "-y" do
    desc "Automatically answer yes to all confirmations"
  end
  flag :rubygems_api_key, "--rubygems-api-key=VAL" do
    desc "Set the Rubygems API key"
    long_desc \
      "Use the given Rubygems API key when pushing to Rubygems. Deprecated;" \
      " prefer just setting the `GEM_HOST_API_KEY` environment variable."
  end
  flag :enable_releases, "--enable-releases=VAL" do
    desc "Deprecated and unused"
  end
end

include :exec
include :terminal, styled: true

def run
  ::Dir.chdir(context_directory)
  setup_objects
  verify_release_pr
  setup_params
  release_sha = setup_git
  @repository.at_sha(release_sha) do
    perform_pending_releases(release_sha)
  end
end

def setup_objects
  require "toys/release/environment_utils"
  require "toys/release/repository"
  require "toys/release/repo_settings"
  require "toys/release/performer"

  @utils = Toys::Release::EnvironmentUtils.new(self)
  @repo_settings = Toys::Release::RepoSettings.load_from_environment(@utils)
  @repository = Toys::Release::Repository.new(@utils, @repo_settings)
  @repository.git_set_user_info
  @pull_request = @repository.load_pr(release_pr)
end

def verify_release_pr
  @utils.error("Could not load pull request ##{release_pr}") unless @pull_request
  expected_labels = [@repo_settings.release_pending_label, @repo_settings.release_error_label]
  return if @pull_request.labels.any? { |label| expected_labels.include?(label) }
  warning = "PR #{release_pr} doesn't have the release pending or release error label."
  if yes
    logger.warn(warning)
    return
  end
  unless confirm("#{warning} Proceed anyway? ", :bold, default: false)
    @utils.error("Release aborted.")
  end
end

def setup_params
  [
    :git_remote,
    :release_ref,
    :rubygems_api_key,
    :work_dir,
  ].each do |key|
    set(key, nil) if get(key).to_s.empty?
  end
  set(:dry_run, /^t/i.match?(::ENV["TOYS_RELEASE_DRY_RUN"].to_s)) if dry_run.nil?
  ::ENV["GEM_HOST_API_KEY"] = rubygems_api_key if rubygems_api_key
end

def setup_git
  @repository.git_prepare_branch(git_remote, branch: @pull_request.base_ref)
  @repository.current_sha(release_ref || @pull_request.merge_commit_sha)
end

def create_performer(release_sha)
  Toys::Release::Performer.new(@repository,
                               release_ref: release_sha,
                               release_pr: release_pr,
                               enable_prechecks: enable_prechecks,
                               git_remote: git_remote,
                               work_dir: work_dir,
                               dry_run: dry_run)
end

def perform_pending_releases(release_sha)
  if enable_prechecks
    github_check_errors = @repository.wait_github_checks(ref: release_sha)
    unless github_check_errors.empty?
      @utils.error("GitHub checks failed", *github_check_errors)
    end
  end
  performer = create_performer(release_sha)
  performer.perform_pr_releases unless performer.error?
  performer.report_results
  if performer.error?
    @utils.error("Releases reported failure")
  else
    puts("All releases completed successfully", :bold, :green)
  end
end
