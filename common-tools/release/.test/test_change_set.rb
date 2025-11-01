require_relative "../.lib/change_set"
require_relative "../.lib/repo_settings"

describe ToysReleaser::ChangeSet do
  let(:default_settings) { ToysReleaser::RepoSettings.new({}) }
  let(:change_set) { ToysReleaser::ChangeSet.new(default_settings) }

  describe "#suggested_version" do
    it "suggests a patch bump from an existing version" do
      change_set.add_message("12345", "fix: change").finish
      version = change_set.suggested_version(::Gem::Version.new("1.2.3"))
      assert_equal(::Gem::Version.new("1.2.4"), version)
    end

    it "suggests a minor bump from an existing version" do
      change_set.add_message("12345", "feat: change").finish
      version = change_set.suggested_version(::Gem::Version.new("1.2.3"))
      assert_equal(::Gem::Version.new("1.3.0"), version)
    end

    it "suggests a major bump from an existing version" do
      change_set.add_message("12345", "feat!: change").finish
      version = change_set.suggested_version(::Gem::Version.new("1.2.3"))
      assert_equal(::Gem::Version.new("2.0.0"), version)
    end

    it "suggests a major bump from an existing prerelease version" do
      change_set.add_message("12345", "feat!: change").finish
      version = change_set.suggested_version(::Gem::Version.new("0.2.3"))
      assert_equal(::Gem::Version.new("0.3.0"), version)
    end

    it "suggests no change from an existing version" do
      change_set.add_message("12345", "chore: change").finish
      version = change_set.suggested_version(::Gem::Version.new("1.2.3"))
      assert_nil(version)
    end

    it "suggests a patch bump from zero" do
      change_set.add_message("12345", "fix: change").finish
      version = change_set.suggested_version(nil)
      assert_equal(::Gem::Version.new("0.0.1"), version)
    end

    it "suggests a minor bump from zero" do
      change_set.add_message("12345", "feat: change").finish
      version = change_set.suggested_version(nil)
      assert_equal(::Gem::Version.new("0.1.0"), version)
    end

    it "suggests a major bump from zero" do
      change_set.add_message("12345", "feat!: change").finish
      version = change_set.suggested_version(nil)
      assert_equal(::Gem::Version.new("0.1.0"), version)
    end
  end

  it "reflects no significant changes" do
    change_set.add_message("12345", "chore: Nothing much")
    change_set.finish
    assert_equal(ToysReleaser::Semver::NONE, change_set.semver)
    groups = change_set.change_groups
    assert_equal(0, groups.size)
  end

  it "reflects a simple feat message" do
    change_set.add_message("12345", "feat: Feature 1")
    change_set.finish
    assert_equal(ToysReleaser::Semver::MINOR, change_set.semver)
    groups = change_set.change_groups
    assert_equal(1, groups.size)
    assert_equal(["ADDED: Feature 1"], groups[0].prefixed_changes)
  end

  it "reflects a simple patch message" do
    change_set.add_message("12345", "fix: Fix 1")
    change_set.finish
    assert_equal(ToysReleaser::Semver::PATCH, change_set.semver)
    groups = change_set.change_groups
    assert_equal(1, groups.size)
    assert_equal(["FIXED: Fix 1"], groups[0].prefixed_changes)
  end

  it "reflects a patch message with breaking change" do
    change_set.add_message("12345", "fix!: Fix 1")
    change_set.finish
    assert_equal(ToysReleaser::Semver::MAJOR, change_set.semver)
    groups = change_set.change_groups
    assert_equal(2, groups.size)
    assert_equal(["BREAKING CHANGE: Fix 1"], groups[0].prefixed_changes)
    assert_equal(["FIXED: Fix 1"], groups[1].prefixed_changes)
  end

  it "reflects a simple docs message" do
    change_set.add_message("12345", "docs: clarified")
    change_set.finish
    assert_equal(ToysReleaser::Semver::PATCH, change_set.semver)
    groups = change_set.change_groups
    assert_equal(1, groups.size)
    assert_equal(["DOCS: Clarified"], groups[0].prefixed_changes)
  end

  it "reflects a compound message with fix and feat" do
    change_set.add_message("12345", "feat: Feature 1\nfix: Fix 2")
    change_set.finish
    assert_equal(ToysReleaser::Semver::MINOR, change_set.semver)
    groups = change_set.change_groups
    assert_equal(2, groups.size)
    assert_equal(["ADDED: Feature 1"], groups[0].prefixed_changes)
    assert_equal(["FIXED: Fix 2"], groups[1].prefixed_changes)
  end

  it "reflects two messages, each with fix and feat" do
    change_set.add_message("12345", "feat: Feature 1\nfix: Fix 2")
    change_set.add_message("abcde", "feat: Feature 3\nfix: Fix 4")
    change_set.finish
    assert_equal(ToysReleaser::Semver::MINOR, change_set.semver)
    groups = change_set.change_groups
    assert_equal(2, groups.size)
    assert_equal(["ADDED: Feature 1", "ADDED: Feature 3"], groups[0].prefixed_changes)
    assert_equal(["FIXED: Fix 2", "FIXED: Fix 4"], groups[1].prefixed_changes)
  end

  it "reflects messages including a breaking change message" do
    change_set.add_message("12345", "feat: Feature 1\nfix: Fix 2")
    change_set.add_message("67890", "fix!: Breaking fix")
    change_set.add_message("abcde", "feat: Feature 3\nfix: Fix 4")
    change_set.finish
    assert_equal(ToysReleaser::Semver::MAJOR, change_set.semver)
    groups = change_set.change_groups
    assert_equal(3, groups.size)
    assert_equal(["BREAKING CHANGE: Breaking fix"], groups[0].prefixed_changes)
    assert_equal(["ADDED: Feature 1", "ADDED: Feature 3"], groups[1].prefixed_changes)
    assert_equal(["FIXED: Fix 2", "FIXED: Breaking fix", "FIXED: Fix 4"], groups[2].prefixed_changes)
  end

  it "reflects a semver-change" do
    change_set.add_message("12345", "feat!: Breaking feature\nsemver-change: minor (#123)\nfeat!: Another break\n")
    change_set.finish
    assert_equal(ToysReleaser::Semver::MINOR, change_set.semver)
    groups = change_set.change_groups
    assert_equal(2, groups.size)
    assert_equal(["BREAKING CHANGE: Breaking feature", "BREAKING CHANGE: Another break"], groups[0].prefixed_changes)
    assert_equal(["ADDED: Breaking feature", "ADDED: Another break"], groups[1].prefixed_changes)
  end

  it "reflects a revert message reverting a feature but leaving a fix" do
    change_set.add_message("12345", "feat: Feat 1")
    change_set.add_message("23456", "fix: Fix 2")
    change_set.add_message("67890", "chore: Revert feat 1\nrevert-commit: 12345 (#123)")
    change_set.finish
    assert_equal(ToysReleaser::Semver::PATCH, change_set.semver)
    groups = change_set.change_groups
    assert_equal(1, groups.size)
    assert_equal(["FIXED: Fix 2"], groups[0].prefixed_changes)
  end

  it "reflects a revert message reverting the last effective change" do
    change_set.add_message("12345", "feat: Feat 1")
    change_set.add_message("67890", "chore: Revert feat 1\nrevert-commit: 12345")
    change_set.finish
    assert_equal(ToysReleaser::Semver::NONE, change_set.semver)
    assert_empty(change_set.change_groups)
  end
end
