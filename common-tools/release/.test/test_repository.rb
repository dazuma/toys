require_relative "helper"
require_relative "../.lib/environment_utils"
require_relative "../.lib/repository"

describe ToysReleaser::Repository do
  let(:fake_tool_context) { ToysReleaser::Tests::FakeToolContext.new(allow_passthru_exec: true) }
  let(:environment_utils) { ToysReleaser::EnvironmentUtils.new(fake_tool_context) }
  let(:repo_settings) { ToysReleaser::RepoSettings.load_from_environment(environment_utils) }
  let(:repository) { ToysReleaser::Repository.new(environment_utils, repo_settings) }

  it "defines the Toys components" do
    refute_nil(repository.component_named("toys"))
    refute_nil(repository.component_named("toys-core"))
    refute_nil(repository.component_named("common-tools"))
    assert_nil(repository.component_named("nonexistent"))
  end

  it "defines the Toys coordination groups" do
    assert_equal(2, repository.coordination_groups.size)
    assert_equal(2, repository.coordination_groups[0].size)
    assert_equal("toys", repository.coordination_groups[0][0].name)
    assert_equal("toys-core", repository.coordination_groups[0][1].name)
    assert_equal(1, repository.coordination_groups[1].size)
    assert_equal("common-tools", repository.coordination_groups[1][0].name)
  end

  it "sets the Toys coordination groups on their components" do
    toys_component = repository.component_named("toys")
    core_component = repository.component_named("toys-core")
    tools_component = repository.component_named("common-tools")
    assert_equal(core_component.coordination_group, toys_component.coordination_group)
    assert_equal([toys_component, core_component], core_component.coordination_group)
    assert_equal([tools_component], tools_component.coordination_group)
  end

  it "returns the current SHA" do
    assert_match(/^[0-9a-f]{40}$/, repository.current_sha)
  end

  it "returns the git remote url" do
    assert_match(%r{dazuma/toys}, repository.git_remote_url("origin"))
  end

  it "creates a single-component release branch name" do
    assert_equal("release/component/toys-core/main", repository.release_branch_name("main", "toys-core"))
  end

  it "creates a multi-component release branch name" do
    assert_match(%r|^release/multi/\d{14}-\d{6}/main$|, repository.multi_release_branch_name("main"))
  end

  it "determines if a branch is release-related" do
    assert(repository.release_related_branch?("release/component/toys/main"))
    assert(repository.release_related_branch?("release/multi/20250903162351-123456/main"))
    refute(repository.release_related_branch?("release/hello"))
  end

  it "simplifies a branch name" do
    assert_equal("main", repository.simplify_branch_name("refs/heads/main"))
  end

  it "switches SHA" do
    skip unless ENV["TOYS_TEST_INTEGRATION"]
    skip unless repository.git_clean?
    original_sha = repository.current_sha
    refute_equal("a922cf30093c539f3d46733e040567a3d8d9d847", original_sha)
    repository.git_prepare_branch("origin")
    repository.at_sha("a922cf30093c539f3d46733e040567a3d8d9d847", quiet: true) do
      assert_equal("a922cf30093c539f3d46733e040567a3d8d9d847", repository.current_sha)
    end
    assert_equal(original_sha, repository.current_sha)
  end

  it "finds a commit message for a sha" do
    message = repository.last_commit_message(ref: "a922cf30093c539f3d46733e040567a3d8d9d847")
    assert_equal("fix: Fixed argument parsing to allow a flag value with a newline delimited by = (#258)", message)
  end

  it "creates a branch" do
    begin
      skip unless repository.git_clean?
      cur_branch = repository.current_branch
      cur_sha = repository.current_sha
      new_branch_name = "test/test-branch-12345"
      repository.create_branch(new_branch_name, quiet: true)
      assert_equal(new_branch_name, repository.current_branch)
      repository.create_branch(new_branch_name, quiet: true)
      assert_equal(new_branch_name, repository.current_branch)
    ensure
      if cur_branch
        environment_utils.exec(["git", "switch", cur_branch], err: :null)
      elsif cur_sha
        environment_utils.exec(["git", "switch", "--detach", cur_sha], err: :null)
      end
    end
  end

  it "determines single released component and version from pull request" do
    pull_request = ToysReleaser::Tests::FakePullRequest.new(
      merge_commit_sha: "1a29ad36ff214d314ec3fd2da727fb25cc5f7a66",
      head_ref: "release/component/toys-core/main"
    )
    data = repository.released_components_and_versions(pull_request)
    assert_equal(1, data.size)
    assert_equal(::Gem::Version.new("0.15.5"), data["toys-core"])
  end

  it "determines multiple released component and version from pull request" do
    pull_request = ToysReleaser::Tests::FakePullRequest.new(
      merge_commit_sha: "1a29ad36ff214d314ec3fd2da727fb25cc5f7a66",
      head_ref: "release/multi/20251030192335-123456/main"
    )
    data = repository.released_components_and_versions(pull_request)
    assert_equal(2, data.size)
    assert_equal(::Gem::Version.new("0.15.5"), data["toys-core"])
    assert_equal(::Gem::Version.new("0.15.5"), data["toys"])
  end
end
