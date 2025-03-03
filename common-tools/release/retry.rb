# frozen_string_literal: true

desc "Releases pending gems for a pull request"

long_desc \
  "This tool continues the releases associated with a release pull request." \
    " It is normally used to retry or continue releases that aborted due to" \
    " an error. This tool is normally called from a GitHub Actions workflow," \
    " but can also be executed locally if the proper credentials are present."

required_arg :release_pr, accept: Integer do
  desc "Release pull request number. Required."
end
flag_group desc: "Flags" do
  flag :enable_releases, "--enable-releases=VAL" do
    default "true"
    desc "Control dry run mode."
    long_desc \
      "If set to any value other than `true` (the default), run in dry-run" \
      " mode as if `--dry-run` were passed. This is used to control dry-run" \
      " mode from a github action where we need to control a value."
  end
  flag :dry_run, "--[no-]dry-run" do
    desc "Run in dry-run mode."
    long_desc \
      "Run in dry-run mode, where checks are made and releases are built" \
      " but are not pushed."
  end
  flag :gh_pages_dir, "--gh-pages-dir=VAL" do
    desc "The directory to use for the gh-pages branch"
    long_desc \
      "Set to the path of a directory to use as the gh-pages workspace when" \
      " building and pushing gem documentation. If left unset, a temporary" \
      " directory will be created (and removed when finished)."
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
  flag :rubygems_api_key, "--rubygems-api-key=VAL" do
    desc "Set the Rubygems API key"
    long_desc \
      "Use the given Rubygems API key when pushing to Rubygems. Deprecated;" \
      " prefer just setting the `GEM_HOST_API_KEY` environment variable."
  end
  flag :enable_prechecks, "--[no-]enable-prechecks" do
    default true
    desc "Enables pre-release checks. Enabled by default."
    long_desc \
      "Enables pre-release checks. Enabled by default. It may occasionally" \
      " be useful to disable this to repair a broken release, but it is" \
      " generally not recommended."
  end
  flag :enable_tags, "--[no-]enable-tags" do
    default true
    desc "Enables github release tags. Enabled by default."
  end
  flag :enable_gems, "--[no-]enable-gems" do
    default true
    desc "Enables Rubygems pushes. Enabled by default."
  end
  flag :enable_docs, "--[no-]enable-docs" do
    default true
    desc "Enables gh-pages documentation pushes. Enabled by default."
  end
  flag :yes, "--yes", "-y" do
    desc "Automatically answer yes to all confirmations"
  end
end

include :exec
include :terminal, styled: true

def run
  ::Dir.chdir(context_directory)
  setup_objects
  verify_release_pr
  setup_params
  @repository.at_sha(release_ref) do
    perform_pending_releases
  end
end

def setup_objects
  require "environment_utils"
  require "repository"
  require "repo_settings"
  require "performer"

  @utils = ToysReleaser::EnvironmentUtils.new(self)
  @repo_settings = ToysReleaser::RepoSettings.load_from_environment(@utils)
  @repository = ToysReleaser::Repository.new(@utils, @repo_settings)
  @repository.git_set_user_info
end

def verify_release_pr
  @pr_info = @repository.load_pr(release_pr)
  @utils.error("Could not load pull request ##{release_pr}") unless @pr_info
  expected_labels = [@repo_settings.release_pending_label, @repo_settings.release_error_label]
  return if @pr_info["labels"].any? { |label| expected_labels.include?(label["name"]) }
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
  [:gh_pages_dir, :rubygems_api_key].each do |key|
    set(key, nil) if get(key).to_s.empty?
  end
  ::ENV["GEM_HOST_API_KEY"] = rubygems_api_key if rubygems_api_key
  set(:dry_run, /^t/i =~ enable_releases.to_s ? false : true) if dry_run.nil?
  set :release_ref, @repository.current_sha(release_ref || @pr_info["merge_commit_sha"])
end

def create_performer
  ToysReleaser::Performer.new(@repository,
                              release_ref: release_ref,
                              release_pr: release_pr,
                              enable_prechecks: enable_prechecks,
                              enable_tags: enable_tags,
                              enable_gems: enable_gems,
                              enable_docs: enable_docs,
                              git_remote: git_remote,
                              gh_pages_dir: gh_pages_dir,
                              capture_errors: true,
                              dry_run: dry_run)
end

def perform_pending_releases
  @repository.wait_github_checks(release_ref) if enable_prechecks
  performer = create_performer
  performer.perform_pr_releases
  performer.report_results
  if performer.error?
    @utils.error("Releases reported failure")
  else
    puts("All releases completed successfully", :bold, :green)
  end
end
