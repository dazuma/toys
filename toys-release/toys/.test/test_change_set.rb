# frozen_string_literal: true

require_relative "helper"

describe Toys::Release::ChangeSet do
  let(:component_name) { "my_component" }
  let(:repo_path) { "example/repo" }
  let(:settings_customization) { {"repo" => repo_path, "components" => [{"name" => component_name}]} }
  let(:repo_settings) { Toys::Release::RepoSettings.new(settings_customization) }
  let(:component_settings) { repo_settings.component_settings(component_name) }
  let(:change_set) { Toys::Release::ChangeSet.new(repo_settings, component_settings) }

  def commit_with(sha, message)
    Toys::Release::CommitInfo.new(nil, sha).populate_for_testing(message: message)
  end

  describe "#suggested_version" do
    it "suggests a patch bump from an existing version" do
      change_set.add_commit(commit_with("12345", "fix: change")).finish
      version = change_set.suggested_version(::Gem::Version.new("1.2.3"))
      assert_equal(::Gem::Version.new("1.2.4"), version)
    end

    it "suggests a minor bump from an existing version" do
      change_set.add_commit(commit_with("12345", "feat: change")).finish
      version = change_set.suggested_version(::Gem::Version.new("1.2.3"))
      assert_equal(::Gem::Version.new("1.3.0"), version)
    end

    it "suggests a major bump from an existing version" do
      change_set.add_commit(commit_with("12345", "feat!: change")).finish
      version = change_set.suggested_version(::Gem::Version.new("1.2.3"))
      assert_equal(::Gem::Version.new("2.0.0"), version)
    end

    it "suggests a major bump from an existing prerelease version" do
      change_set.add_commit(commit_with("12345", "feat!: change")).finish
      version = change_set.suggested_version(::Gem::Version.new("0.2.3"))
      assert_equal(::Gem::Version.new("0.3.0"), version)
    end

    it "suggests no change from an existing version" do
      change_set.add_commit(commit_with("12345", "chore: change")).finish
      version = change_set.suggested_version(::Gem::Version.new("1.2.3"))
      assert_nil(version)
    end

    it "suggests a patch bump from zero" do
      change_set.add_commit(commit_with("12345", "fix: change")).finish
      version = change_set.suggested_version(nil)
      assert_equal(::Gem::Version.new("0.0.1"), version)
    end

    it "suggests a minor bump from zero" do
      change_set.add_commit(commit_with("12345", "feat: change")).finish
      version = change_set.suggested_version(nil)
      assert_equal(::Gem::Version.new("0.1.0"), version)
    end

    it "suggests a major bump from zero" do
      change_set.add_commit(commit_with("12345", "feat!: change")).finish
      version = change_set.suggested_version(nil)
      assert_equal(::Gem::Version.new("0.1.0"), version)
    end
  end

  it "reflects no significant changes" do
    change_set.add_commit(commit_with("12345", "chore: Nothing much"))
    change_set.finish
    assert_equal(Toys::Release::Semver::NONE, change_set.semver)
    groups = change_set.change_groups
    assert_equal(0, groups.size)
    assert_empty(change_set)
  end

  it "reflects a simple feat message" do
    change_set.add_commit(commit_with("12345", "feat: Feature 1"))
    change_set.finish
    assert_equal(Toys::Release::Semver::MINOR, change_set.semver)
    groups = change_set.change_groups
    assert_equal(1, groups.size)
    assert_equal(["ADDED: Feature 1"], groups[0].prefixed_changes)
    refute_empty(change_set)
  end

  it "reflects a simple message with issue numbers with plain handling" do
    change_set.add_commit(commit_with("12345", "feat: Feature 1 (#123) (#456) "))
    change_set.finish
    assert_equal(Toys::Release::Semver::MINOR, change_set.semver)
    groups = change_set.change_groups
    assert_equal(1, groups.size)
    assert_equal(["ADDED: Feature 1 (#123) (#456)"], groups[0].prefixed_changes)
    refute_empty(change_set)
  end

  it "reflects a simple message with issue numbers with delete handling" do
    settings_customization["issue_number_suffix_handling"] = "delete"
    change_set.add_commit(commit_with("12345", "feat: Feature 1 (#123) (#456) "))
    change_set.finish
    assert_equal(Toys::Release::Semver::MINOR, change_set.semver)
    groups = change_set.change_groups
    assert_equal(1, groups.size)
    assert_equal(["ADDED: Feature 1"], groups[0].prefixed_changes)
    refute_empty(change_set)
  end

  it "reflects a simple message with issue numbers with link handling" do
    settings_customization["issue_number_suffix_handling"] = "link"
    change_set.add_commit(commit_with("12345", "feat: Feature 1 (#123) (#456) "))
    change_set.finish
    assert_equal(Toys::Release::Semver::MINOR, change_set.semver)
    groups = change_set.change_groups
    assert_equal(1, groups.size)
    expected_entry = "ADDED: Feature 1 ([#123](https://github.com/example/repo/pull/123)) " \
                     "([#456](https://github.com/example/repo/pull/456))"
    assert_equal([expected_entry], groups[0].prefixed_changes)
    refute_empty(change_set)
  end

  it "reflects a simple patch message" do
    change_set.add_commit(commit_with("12345", "fix: Fix 1"))
    change_set.finish
    assert_equal(Toys::Release::Semver::PATCH, change_set.semver)
    groups = change_set.change_groups
    assert_equal(1, groups.size)
    assert_equal(["FIXED: Fix 1"], groups[0].prefixed_changes)
  end

  it "reflects a patch message with breaking change" do
    change_set.add_commit(commit_with("12345", "fix!: Fix 1"))
    change_set.finish
    assert_equal(Toys::Release::Semver::MAJOR, change_set.semver)
    groups = change_set.change_groups
    assert_equal(2, groups.size)
    assert_equal(["BREAKING CHANGE: Fix 1"], groups[0].prefixed_changes)
    assert_equal(["FIXED: Fix 1"], groups[1].prefixed_changes)
  end

  it "reflects a simple docs message" do
    change_set.add_commit(commit_with("12345", "docs: clarified"))
    change_set.finish
    assert_equal(Toys::Release::Semver::PATCH, change_set.semver)
    groups = change_set.change_groups
    assert_equal(1, groups.size)
    assert_equal(["DOCS: Clarified"], groups[0].prefixed_changes)
  end

  it "reflects a compound message with fix and feat" do
    change_set.add_commit(commit_with("12345", "feat: Feature 1\nfix: Fix 2"))
    change_set.finish
    assert_equal(Toys::Release::Semver::MINOR, change_set.semver)
    groups = change_set.change_groups
    assert_equal(2, groups.size)
    assert_equal(["ADDED: Feature 1"], groups[0].prefixed_changes)
    assert_equal(["FIXED: Fix 2"], groups[1].prefixed_changes)
  end

  it "reflects two messages, each with fix and feat" do
    change_set.add_commit(commit_with("12345", "feat: Feature 1\nfix: Fix 2"))
    change_set.add_commit(commit_with("abcde", "feat: Feature 3\nfix: Fix 4"))
    change_set.finish
    assert_equal(Toys::Release::Semver::MINOR, change_set.semver)
    groups = change_set.change_groups
    assert_equal(2, groups.size)
    assert_equal(["ADDED: Feature 1", "ADDED: Feature 3"], groups[0].prefixed_changes)
    assert_equal(["FIXED: Fix 2", "FIXED: Fix 4"], groups[1].prefixed_changes)
  end

  it "reflects messages including a breaking change message" do
    change_set.add_commit(commit_with("12345", "feat: Feature 1\nfix: Fix 2"))
    change_set.add_commit(commit_with("67890", "fix!: Breaking fix"))
    change_set.add_commit(commit_with("abcde", "feat: Feature 3\nfix: Fix 4"))
    change_set.finish
    assert_equal(Toys::Release::Semver::MAJOR, change_set.semver)
    groups = change_set.change_groups
    assert_equal(3, groups.size)
    assert_equal(["BREAKING CHANGE: Breaking fix"], groups[0].prefixed_changes)
    assert_equal(["ADDED: Feature 1", "ADDED: Feature 3"], groups[1].prefixed_changes)
    assert_equal(["FIXED: Fix 2", "FIXED: Breaking fix", "FIXED: Fix 4"], groups[2].prefixed_changes)
  end

  it "reflects a downgrading semver-change" do
    change_set.add_commit(
      commit_with("12345", "feat!: Breaking feature\nsemver-change: minor (#123)\nfeat!: Another break\n")
    )
    change_set.finish
    assert_equal(Toys::Release::Semver::MINOR, change_set.semver)
    groups = change_set.change_groups
    assert_equal(2, groups.size)
    assert_equal(["BREAKING CHANGE: Breaking feature", "BREAKING CHANGE: Another break"], groups[0].prefixed_changes)
    assert_equal(["ADDED: Breaking feature", "ADDED: Another break"], groups[1].prefixed_changes)
  end

  it "reflects a semver-change that turns a non-significant change significant" do
    change_set.add_commit(commit_with("12345", "chore: not much here\nsemver-change: minor (#123)\n"))
    change_set.finish
    assert_equal(Toys::Release::Semver::MINOR, change_set.semver)
    groups = change_set.change_groups
    assert_equal(1, groups.size)
    assert_nil(groups[0].header)
  end

  it "reflects a revert message reverting a feature but leaving a fix" do
    change_set.add_commit(commit_with("12345", "feat: Feat 1"))
    change_set.add_commit(commit_with("23456", "fix: Fix 2"))
    change_set.add_commit(commit_with("67890", "chore: Revert feat 1\nrevert-commit: 12345 (#123)"))
    change_set.finish
    assert_equal(Toys::Release::Semver::PATCH, change_set.semver)
    groups = change_set.change_groups
    assert_equal(1, groups.size)
    assert_equal(["FIXED: Fix 2"], groups[0].prefixed_changes)
  end

  it "reflects a revert message reverting the last effective change" do
    change_set.add_commit(commit_with("12345", "feat: Feat 1"))
    change_set.add_commit(commit_with("67890", "chore: Revert feat 1\nrevert-commit: 12345"))
    change_set.finish
    assert_equal(Toys::Release::Semver::NONE, change_set.semver)
    assert_empty(change_set)
  end

  it "reflects a revert of a revert" do
    change_set.add_commit(commit_with("12345", "feat: Feat 1"))
    change_set.add_commit(commit_with("23456", "chore: Revert feat 1\nrevert-commit: 12345"))
    change_set.add_commit(commit_with("34567", "chore: Revert the revert\nrevert-commit: 23456"))
    change_set.finish
    assert_equal(Toys::Release::Semver::MINOR, change_set.semver)
    groups = change_set.change_groups
    assert_equal(1, groups.size)
    assert_equal(["ADDED: Feat 1"], groups[0].prefixed_changes)
  end

  it "reflects a scope change to the header and semver" do
    settings_customization["commit_tags"] = [
      {
        "tag" => "feat",
        "semver" => "minor",
        "scopes" => [
          {
            "scope" => "internal",
            "header" => "INTERNAL",
            "semver" => "patch",
          },
        ],
      },
    ]
    change_set.add_commit(commit_with("12345", "feat(internal): Feature 1"))
    change_set.finish
    assert_equal(Toys::Release::Semver::PATCH, change_set.semver)
    groups = change_set.change_groups
    assert_equal(1, groups.size)
    assert_equal(["INTERNAL: Feature 1"], groups[0].prefixed_changes)
  end

  it "reflects a scope removal of the change description" do
    settings_customization["commit_tags"] = [
      {
        "tag" => "feat",
        "semver" => "minor",
        "scopes" => [
          {
            "scope" => "internal",
            "header" => nil,
          },
        ],
      },
    ]
    change_set.add_commit(commit_with("12345", "feat(internal): Feature 1"))
    change_set.finish
    assert_equal(Toys::Release::Semver::MINOR, change_set.semver)
    groups = change_set.change_groups
    assert_equal(1, groups.size)
    assert_equal(["No significant updates."], groups[0].prefixed_changes)
  end
end
