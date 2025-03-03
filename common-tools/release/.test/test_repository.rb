require_relative "helper"
require_relative "../.lib/environment_utils"
require_relative "../.lib/repository"

describe ToysReleaser::Repository do
  let(:fake_tool_context) { ToysReleaser::Tests::FakeToolContext.new(allow_passthru_exec: true) }
  let(:environment_utils) { ToysReleaser::EnvironmentUtils.new(fake_tool_context) }
  let(:repo_settings) { ToysReleaser::RepoSettings.load_from_environment(environment_utils) }
  let(:repository) { ToysReleaser::Repository.new(environment_utils, repo_settings) }

  it "defines the Toys releasable units" do
    refute_nil(repository.releasable_unit("toys"))
    refute_nil(repository.releasable_unit("toys-core"))
    refute_nil(repository.releasable_unit("common-tools"))
    assert_nil(repository.releasable_unit("nonexistent"))
  end

  it "defines the Toys coordination groups" do
    assert_equal(2, repository.coordination_groups.size)
    assert_equal(2, repository.coordination_groups[0].size)
    assert_equal("toys-core", repository.coordination_groups[0][0].name)
    assert_equal("toys", repository.coordination_groups[0][1].name)
    assert_equal(1, repository.coordination_groups[1].size)
    assert_equal("common-tools", repository.coordination_groups[1][0].name)
  end

  it "sets the Toys coordination groups on their releasable units" do
    toys_unit = repository.releasable_unit("toys")
    core_unit = repository.releasable_unit("toys-core")
    tools_unit = repository.releasable_unit("common-tools")
    assert_equal(core_unit.coordination_group, toys_unit.coordination_group)
    assert_equal([core_unit, toys_unit], core_unit.coordination_group)
    assert_equal([tools_unit], tools_unit.coordination_group)
  end

  it "returns the current SHA" do
    assert_match(/^[0-9a-f]{40}$/, repository.current_sha)
  end

  it "returns the git remote url" do
    assert_match(%r{dazuma/toys}, repository.git_remote_url("origin"))
  end

  it "creates a single-unit release branch name" do
    assert_equal("release/toys-core", repository.release_branch_name("toys-core"))
  end

  it "creates a multi-unit release branch name" do
    assert_match(%r|^release/multi/\d{14}$|, repository.multi_release_branch_name)
  end

  it "finds a single merged Toys release pull request matching a SHA" do
    pull = repository.find_release_prs(merge_sha: "17ed449da8299f272b834470ff6b279a59e8070b")
    assert_equal(260, pull.number)
  end

  it "switches SHA" do
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
end
