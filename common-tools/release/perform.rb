# frozen_string_literal: true

desc "Perform a release"

long_desc \
  "This tool performs an official release. It is normally called from a" \
    " GitHub Actions workflow, but can also be executed locally if the" \
    " proper credentials are present.",
  "",
  "Normally, releases should be initiated using the 'request' tool, invoked" \
    " either locally or from GitHub Actions. That tool will automatically" \
    " update the library version and changelog based on the commits since" \
    " the last release, and will open a pull request that you can merge to" \
    " actually perform the release. The 'perform' tool should be used only" \
    " if the version and changelog commits are already committed.",
  "",
  "When invoked, this tool first performs pre-checks including:",
  "* The git workspace must be clean (no new, modified, or deleted files)",
  "* The remote repo must be the correct repo configured in releases.yml",
  "* All GitHub checks for the release to commit must have succeeded",
  "",
  "The tool then performs the necessary release tasks for each component." \
    " It also ensures each version file and changelog are properly formatted" \
    " and match the release version if given."

remaining_args :components do
  accept(/^[\w-]+(?:[=:][\w.-]+)?$/)
  desc "Components to release"
  long_desc \
    "Each remaining argument should consist of a component name, and optional" \
      " version number separated by a equal sign, i.e.",
    ["    <name>[=<version>]"],
    "",
    "The version to release is determined by the version file and changelog." \
      " The version given on the command line, if provided, is used only for" \
      " verification."
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
  flag :git_remote, "--git-remote=VAL" do
    default "origin"
    desc "The name of the git remote"
    long_desc \
      "The name of the git remote pointing at the canonical repository." \
      " Defaults to 'origin'."
  end
  flag :release_ref, "--release-ref=VAL", "--release-sha=VAL" do
    desc "The commit to use for the release"
    long_desc \
      "Specifies a ref (branch or SHA) for the release. Optional. Defaults" \
      " to the current HEAD."
  end
  flag :enable_prechecks, "--[no-]enable-prechecks" do
    default true
    desc "Enables pre-release checks. Enabled by default."
  end
  flag :release_pr, "--release-pr=VAL" do
    accept ::Integer
    desc "Release pull request number"
    long_desc \
      "Update the given release pull request number. Optional."
  end
  flag :work_dir, "--work-dir=PATH" do
    desc "Set the directory for artifacts and temporary files"
    long_desc \
      "If provided, the given directory path is used for artifacts and" \
        " temporary files, and is left intact after the release so the" \
        " artifacts can be inspected. If omitted, a new temporary directory" \
        " is created, and is automatically deleted after the release."
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
  flag :gh_token, "--gh-token=VAL" do
    desc "Set the GitHub token"
    long_desc \
      "Use the given GitHub token when pushing to GitHub. Deprecated; prefer" \
      " just setting the `GITHUB_TOKEN` environment variable."
  end
end

include :exec
include :terminal, styled: true

def run
  ::Dir.chdir(context_directory)
  require "environment_utils"
  require "repository"
  require "repo_settings"
  require "performer"

  setup_arguments
  setup_performer
  components.each do |component_spec|
    name, version = component_spec.split(/[:=]/, 2)
    confirmation_ui(name, version)
    gem_version = version ? ::Gem::Version.new(version) : nil
    @performer.perform_adhoc_release(name, assert_version: gem_version)
  end
  puts @performer.build_report_text
end

def setup_arguments
  require "environment_utils"
  require "repository"
  require "repo_settings"
  require "performer"
  [
    :git_remote,
    :release_ref,
    :release_pr,
    :rubygems_api_key,
    :gh_token,
    :work_dir,
  ].each do |key|
    set(key, nil) if get(key).to_s.empty?
  end
  set(:dry_run, true) if dry_run.nil? && enable_releases != "true"
  ::ENV["GEM_HOST_API_KEY"] = rubygems_api_key if rubygems_api_key
  ::ENV["GITHUB_TOKEN"] = gh_token if gh_token
end

def setup_performer
  @utils = ToysReleaser::EnvironmentUtils.new(self)
  @repo_settings = ToysReleaser::RepoSettings.load_from_environment(@utils)
  @repository = ToysReleaser::Repository.new(@utils, @repo_settings)
  @repository.git_set_user_info
  @performer = ToysReleaser::Performer.new(@repository,
                                           release_ref: release_ref,
                                           release_pr: release_pr,
                                           enable_prechecks: enable_prechecks,
                                           git_remote: git_remote,
                                           work_dir: work_dir,
                                           dry_run: dry_run)
end

def confirmation_ui(name, version)
  return if yes
  return if confirm("Release #{name} #{version}? ", :bold, default: false)
  @utils.error("Release aborted")
end
