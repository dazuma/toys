# frozen_string_literal: true

desc "Open a release request"

long_desc \
  "This tool opens release pull requests for the specified releasable" \
  " components. It analyzes the commits since the last release, and updates" \
    " each component's version and changelog accordingly. This tool is" \
    " normally called from a GitHub Actions workflow, but can also be" \
    " executed locally.",
  "",
  "When invoked, this tool first performs checks including:",
  "* The git workspace must be clean (no new, modified, or deleted files)",
  "* The remote repo must be the correct repo configured in releases.yml",
  "* All GitHub checks for the release commit must have succeeded",
  "",
  "The tool then creates release pull requests for each component:",
  "* It collects all commit messages since the previous release.",
  "* It builds a changelog using properly formatted conventional commit" \
    " messages of type 'fix', 'feat', and 'docs', and any that indicate a" \
    " breaking change.",
  "* Unless a specific version is provided via flags, it infers a new version" \
    " number using the implied semver significance of the commit messages.",
  "* It edits the changelog and version Ruby files and pushes a commit to a" \
    " release branch.",
  "* It opens a release pull request.",
  "",
  "Release pull requests may be edited to modify the version and/or changelog" \
    " before merging. In repositories that have release automation enabled," \
    " the release script will run automatically when a release pull request" \
    " is merged."

remaining_args :components do
  accept(/^[\w-]+(?:[=:][\w.-]+)?$/)
  desc "Components to release"
  long_desc \
    "Each remaining argument should consist of a component name, and optional" \
      " version spec separated by a equal sign, i.e.",
    ["    <name>[=<version>]"],
    "",
    "The version can be a literal version number, or one of the semver" \
      " change types 'major', 'minor', or 'patch'. It can also be omitted." \
      " If the version is omitted, a semver change type will be inferred" \
      " from the conventional commit message history, and the component will" \
      " be released only if at least one significant releasable commit tag" \
      " (such as 'feat:' or 'fix:') is found.",
    "",
    "Note that any coordination groups are honored. If you release at least" \
      " one component within a group, all components in the group will be" \
      " forced to release with the same version.",
    "",
    "The special name 'all' can be used to specify all components. You can" \
      " also provide a version to force all components to be released with" \
      " that version, e.g. 'all=1.2.3'.",
    "",
    "If no components are provided, all components with releasable changes" \
      " are released. That is, not providing any components is equivalent to" \
      " specifying 'all' without a version."
end

flag :git_remote, "--git-remote=VAL" do
  default "origin"
  desc "The name of the git remote"
  long_desc \
    "The name of the git remote pointing at the canonical repository." \
    " Defaults to 'origin'."
end
flag :target_branch, "--release-ref=VAL", "--target-branch=VAL" do
  desc "Target branch for the release"
  long_desc "The target branch for the release request. Defaults to HEAD."
end
flag :yes, "--yes", "-y" do
  desc "Automatically answer yes to all confirmations"
end

include :exec
include :terminal, styled: true

def run
  setup
  @utils = Toys::Release::EnvironmentUtils.new(self)
  @repo_settings = Toys::Release::RepoSettings.load_from_environment(@utils)
  @repository = prepare_repository
  @request_spec = build_request_spec
  @request_logic = Toys::Release::RequestLogic.new(@repository, @request_spec)
  @request_logic.verify_component_status
  @request_logic.verify_pull_request_status
  confirmation_ui
  @pull_request = create_pull_request
  result_ui(@pull_request.number)
end

def setup
  ::Dir.chdir(context_directory)
  require "toys/release/environment_utils"
  require "toys/release/repository"
  require "toys/release/repo_settings"
  require "toys/release/request_logic"
  require "toys/release/request_spec"
end

def prepare_repository
  repository = Toys::Release::Repository.new(@utils, @repo_settings)
  repository.git_set_user_info
  repository.verify_git_clean
  repository.verify_repo_identity(remote: git_remote)
  set(:target_branch, nil) if get(:target_branch).to_s.empty?
  set(:target_branch, repository.git_prepare_branch(git_remote, branch: target_branch))
  repository.verify_github_checks(ref: target_branch)
  repository
end

def build_request_spec
  request_spec = Toys::Release::RequestSpec.new(@utils)
  set(:components, ["all"]) if components.empty?
  request_spec.add_from_input_string(components.join(" "), @repository)
  request_spec.resolve_versions(@repository, release_ref: target_branch)
  request_spec
end

def confirmation_ui
  puts("Opening a request to release the following:", :bold)
  @request_spec.resolved_components.each do |component|
    puts("* #{component.component_name} version #{component.last_version} -> #{component.version}")
  end
  unless yes || confirm("Create release PR? ", :bold, default: true)
    @utils.error("Release aborted")
  end
end

def create_pull_request
  release_branch = @request_logic.determine_release_branch
  commit_title = @request_logic.build_commit_title
  commit_details = @request_logic.build_commit_details
  signoff = @repository.settings.signoff_commits?
  @repository.create_branch(release_branch)
  @request_logic.change_files
  @repository.git_commit(commit_title, commit_details: commit_details, signoff: signoff)
  body = @request_logic.build_pr_body
  labels = @request_logic.determine_pr_labels
  @repository.create_pull_request(base_branch: target_branch,
                                  remote: git_remote,
                                  title: commit_title,
                                  body: body,
                                  labels: labels)
end

def result_ui(pr_number)
  repo = @repository.settings.repo_path
  puts("Created pull request: https://github.com/#{repo}/pull/#{pr_number}", :bold)
end
