# frozen_string_literal: true

require_relative "helper"

describe Toys::Release::CommitInfo do
  let(:fake_tool_context) { Toys::Release::Tests::FakeToolContext.new(allow_passthru_exec: true) }
  let(:environment_utils) { Toys::Release::EnvironmentUtils.new(fake_tool_context) }
  let(:repo_settings) { Toys::Release::RepoSettings.load_from_environment(environment_utils) }
  let(:repository) { Toys::Release::Repository.new(environment_utils, repo_settings) }

  it "handles a bad commit" do
    commit = Toys::Release::CommitInfo.new(environment_utils, "0b893edb11d8e50a978ca7f80f2b496f0e0ceb5e")
    refute(commit.exist?)
    assert_empty(commit.message)
    assert_empty(commit.modified_paths)
    assert_empty(commit.parent_sha)
  end

  it "handles a good commit" do
    commit = Toys::Release::CommitInfo.new(environment_utils, "47cfeffc9ba275dab7604e30038fed107636304f")
    assert(commit.exist?)
    assert_equal("docs: Some formatting fixes in the user guide (#376)", commit.message)
    expected_paths = [
      "toys-core/docs/guide.md",
      "toys-release/README.md",
      "toys-release/docs/guide.md",
    ]
    assert_equal(expected_paths, commit.modified_paths)
    assert_equal("3beffe9a276e61e2acd6f2c008de4894ec0349aa", commit.parent_sha)
  end

  it "handles an initial commit" do
    commit = Toys::Release::CommitInfo.new(environment_utils, "21dcf727b0f5b2f235a05a9d144a8b6a378a1aeb")
    assert(commit.exist?)
    assert_equal("Initial commit", commit.message)
    assert_includes(commit.modified_paths, ".gitignore")
    assert_equal("4b825dc642cb6eb9a060e54bf8d69288fbee4904", commit.parent_sha)
  end
end
