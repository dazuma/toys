require_relative "helper"
require_relative "../.lib/repo_settings"

describe ToysReleaser::CommitTagSettings do
  it "reads a simple tag setting" do
    setting = ToysReleaser::CommitTagSettings.new("docs")
    assert_equal("docs", setting.tag)
    assert_equal("DOCS", setting.header)
    assert_equal(ToysReleaser::Semver::PATCH, setting.semver)
  end

  it "reads a hash tag setting" do
    input = {
      "tag" => "feat",
      "label" => "ADDED",
      "semver" => "minor",
    }
    setting = ToysReleaser::CommitTagSettings.new(input)
    assert_equal("feat", setting.tag)
    assert_equal("ADDED", setting.header)
    assert_equal(ToysReleaser::Semver::MINOR, setting.semver)
  end
end

describe ToysReleaser::RepoSettings do
  let(:fake_tool_context) { ToysReleaser::Tests::FakeToolContext.new }
  let(:environment_utils) { ToysReleaser::EnvironmentUtils.new(fake_tool_context) }

  it "loads the toys repo settings" do
    settings = ToysReleaser::RepoSettings.load_from_environment(environment_utils)
    assert_equal("dazuma/toys", settings.repo_path)
    assert_equal("main", settings.main_branch)
    assert_equal("Daniel Azuma", settings.git_user_name)
    assert_equal("dazuma@gmail.com", settings.git_user_email)
    assert_equal("toys", settings.default_component_name)
    assert_equal(//, settings.required_checks_regexp)
    assert_equal(1800, settings.required_checks_timeout)
    assert_equal(["squash"], settings.commit_lint_merge)
    assert_nil(settings.commit_lint_allowed_types)
    assert_equal("dazuma", settings.repo_owner)
    assert_equal(false, settings.signoff_commits?)
    assert_equal(true, settings.enable_release_automation?)
    assert_equal(true, settings.commit_lint_fail_checks?)
    assert_equal(true, settings.commit_lint_active?)
    assert_equal(["toys", "toys-core", "common-tools"], settings.all_component_names)
    assert_equal(["toys", "toys-core", "common-tools"], settings.all_component_settings.map(&:name))
    assert_equal([["toys", "toys-core"]], settings.coordination_groups)

    toys_core_settings = settings.component_settings("toys-core")
    assert_equal("toys-core", toys_core_settings.name)
    assert_equal("gem", toys_core_settings.type)
    assert_equal("toys-core", toys_core_settings.directory)
    assert_equal("CHANGELOG.md", toys_core_settings.changelog_path)
    assert_equal(["Toys", "Core", "VERSION"], toys_core_settings.version_constant)
    assert_equal("gems/toys-core", toys_core_settings.gh_pages_directory)
    assert_equal("version", toys_core_settings.gh_pages_version_var)
    assert_equal("lib/toys/core.rb", toys_core_settings.version_rb_path)
    assert_nil(toys_core_settings.task_named("build_yard").options["pre_tool"])

    toys_settings = settings.component_settings("toys")
    assert_equal("toys", toys_settings.name)
    assert_equal("gem", toys_settings.type)
    assert_equal("toys", toys_settings.directory)
    assert_equal("CHANGELOG.md", toys_settings.changelog_path)
    assert_equal(["Toys", "VERSION"], toys_settings.version_constant)
    assert_equal("gems/toys", toys_settings.gh_pages_directory)
    assert_equal("version", toys_settings.gh_pages_version_var)
    assert_equal("lib/toys/version.rb", toys_settings.version_rb_path)
    assert_equal(["copy-core-docs"], toys_settings.task_named("build_yard").options["pre_tool"])

    common_settings = settings.component_settings("common-tools")
    assert_equal("common-tools", common_settings.name)
    assert_equal("component", common_settings.type)
    assert_equal("common-tools", common_settings.directory)
    assert_equal("CHANGELOG.md", common_settings.changelog_path)
    assert_equal(["Toys", "CommonTools", "VERSION"], common_settings.version_constant)
    assert_equal(".lib/version.rb", common_settings.version_rb_path)
    assert_nil(common_settings.task_named("build_yard"))

    commit_tag_settings = settings.release_commit_tags
    feat_tag_settings = commit_tag_settings["feat"]
    assert_equal("feat", feat_tag_settings.tag)
    assert_equal("ADDED", feat_tag_settings.header)
    assert_equal(ToysReleaser::Semver::MINOR, feat_tag_settings.semver)
    fix_tag_settings = commit_tag_settings["fix"]
    assert_equal("fix", fix_tag_settings.tag)
    assert_equal("FIXED", fix_tag_settings.header)
    assert_equal(ToysReleaser::Semver::PATCH, fix_tag_settings.semver)
    docs_tag_settings = commit_tag_settings["docs"]
    assert_equal("docs", docs_tag_settings.tag)
    assert_equal("DOCS", docs_tag_settings.header)
    assert_equal(ToysReleaser::Semver::PATCH, docs_tag_settings.semver)
  end
end
