# frozen_string_literal: true

require_relative "helper"

describe Toys::Release::CommitTagSettings do
  it "reads a simple tag setting" do
    setting = Toys::Release::CommitTagSettings.new("docs")
    assert_equal("docs", setting.tag)
    assert_equal("DOCS", setting.header)
    assert_equal(Toys::Release::Semver::PATCH, setting.semver)
  end

  it "reads a hash tag setting" do
    input = {
      "tag" => "feat",
      "label" => "ADDED",
      "semver" => "minor",
    }
    setting = Toys::Release::CommitTagSettings.new(input)
    assert_equal("feat", setting.tag)
    assert_equal("ADDED", setting.header)
    assert_equal(Toys::Release::Semver::MINOR, setting.semver)
  end
end

describe Toys::Release::RepoSettings do
  let(:fake_tool_context) { Toys::Release::Tests::FakeToolContext.new }
  let(:environment_utils) { Toys::Release::EnvironmentUtils.new(fake_tool_context) }

  it "loads the toys repo settings" do
    settings = Toys::Release::RepoSettings.load_from_environment(environment_utils)
    assert_equal("dazuma/toys", settings.repo_path)
    assert_equal("main", settings.main_branch)
    assert_equal("Daniel Azuma", settings.git_user_name)
    assert_equal("dazuma@gmail.com", settings.git_user_email)
    assert_equal("toys", settings.default_component_name)
    assert_equal(//, settings.required_checks_regexp)
    assert_equal(1800, settings.required_checks_timeout)
    assert_equal("dazuma", settings.repo_owner)
    assert_equal(false, settings.signoff_commits?)
    assert_equal(true, settings.enable_release_automation?)
    assert_equal(["toys", "toys-core", "toys-release", "common-tools"], settings.all_component_names)
    assert_equal(["toys", "toys-core", "toys-release", "common-tools"], settings.all_component_settings.map(&:name))
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
    assert_nil(toys_core_settings.step_named("copy_core_docs"))
    assert_empty(toys_core_settings.step_named("build_yard").inputs)

    toys_settings = settings.component_settings("toys")
    assert_equal("toys", toys_settings.name)
    assert_equal("gem", toys_settings.type)
    assert_equal("toys", toys_settings.directory)
    assert_equal("CHANGELOG.md", toys_settings.changelog_path)
    assert_equal(["Toys", "VERSION"], toys_settings.version_constant)
    assert_equal("gems/toys", toys_settings.gh_pages_directory)
    assert_equal("version", toys_settings.gh_pages_version_var)
    assert_equal("lib/toys/version.rb", toys_settings.version_rb_path)
    assert_equal(["copy-core-docs"], toys_settings.step_named("copy_core_docs").options["tool"])
    assert_equal(1, toys_settings.step_named("build_yard").inputs.size)
    assert_equal("copy_core_docs", toys_settings.step_named("build_yard").inputs.first.step_name)
    assert_equal(1, toys_settings.step_named("copy_core_docs").outputs.size)
    assert_equal("core-docs", toys_settings.step_named("copy_core_docs").outputs.first.source_path)

    toys_release_settings = settings.component_settings("toys-release")
    assert_equal("toys-release", toys_release_settings.name)
    assert_equal("gem", toys_release_settings.type)
    assert_equal("toys-release", toys_release_settings.directory)
    assert_equal("CHANGELOG.md", toys_release_settings.changelog_path)
    assert_equal(["Toys", "Release", "VERSION"], toys_release_settings.version_constant)
    assert_equal("gems/toys-release", toys_release_settings.gh_pages_directory)
    assert_equal("version_toys_release", toys_release_settings.gh_pages_version_var)
    assert_equal("lib/toys/release/version.rb", toys_release_settings.version_rb_path)
    assert_nil(toys_release_settings.step_named("copy_core_docs"))
    assert_empty(toys_release_settings.step_named("build_yard").inputs)

    common_tools_settings = settings.component_settings("common-tools")
    assert_equal("common-tools", common_tools_settings.name)
    assert_equal("component", common_tools_settings.type)
    assert_equal("common-tools", common_tools_settings.directory)
    assert_equal("CHANGELOG.md", common_tools_settings.changelog_path)
    assert_equal(["Toys", "CommonTools", "VERSION"], common_tools_settings.version_constant)
    assert_equal(".lib/version.rb", common_tools_settings.version_rb_path)
    assert_nil(common_tools_settings.step_named("build_yard"))

    commit_tag_settings = settings.release_commit_tags
    feat_tag_settings = commit_tag_settings["feat"]
    assert_equal("feat", feat_tag_settings.tag)
    assert_equal("ADDED", feat_tag_settings.header)
    assert_equal(Toys::Release::Semver::MINOR, feat_tag_settings.semver)
    fix_tag_settings = commit_tag_settings["fix"]
    assert_equal("fix", fix_tag_settings.tag)
    assert_equal("FIXED", fix_tag_settings.header)
    assert_equal(Toys::Release::Semver::PATCH, fix_tag_settings.semver)
    docs_tag_settings = commit_tag_settings["docs"]
    assert_equal("docs", docs_tag_settings.tag)
    assert_equal("DOCS", docs_tag_settings.header)
    assert_equal(Toys::Release::Semver::PATCH, docs_tag_settings.semver)
  end

  describe "CommitTagSettings" do
    it "loads a hidden header" do
      input = {
        "release_commit_tags" => [
          {
            "tag" => "internal",
            "header" => nil,
          },
        ],
      }
      settings = Toys::Release::RepoSettings.new(input)
      tag_settings = settings.release_commit_tags["internal"]
      assert_equal("internal", tag_settings.tag)
      assert_equal(:hidden, tag_settings.header)
      assert_equal(Toys::Release::Semver::PATCH, tag_settings.semver)
    end

    it "loads a scope" do
      input = {
        "release_commit_tags" => [
          {
            "tag" => "chore",
            "header" => nil,
            "semver" => nil,
            "scopes" => {
              "deps" => {
                "header" => "DEPENDENCIES",
                "semver" => "patch",
              },
            },
          },
        ],
      }
      settings = Toys::Release::RepoSettings.new(input)
      tag_settings = settings.release_commit_tags["chore"]
      assert_equal("chore", tag_settings.tag)
      assert_equal(:hidden, tag_settings.header)
      assert_equal(Toys::Release::Semver::NONE, tag_settings.semver)
      assert_equal(:hidden, tag_settings.header("foo"))
      assert_equal(Toys::Release::Semver::NONE, tag_settings.semver("foo"))
      assert_equal("DEPENDENCIES", tag_settings.header("deps"))
      assert_equal(Toys::Release::Semver::PATCH, tag_settings.semver("deps"))
    end

    it "modifies header and semver of an existing tag" do
      input = {
        "modify_release_commit_tags" => {
          "feat" => {
            "header" => "FEATURE",
            "semver" => "major",
          },
        },
      }
      settings = Toys::Release::RepoSettings.new(input)
      tag_settings = settings.release_commit_tags["feat"]
      assert_equal("feat", tag_settings.tag)
      assert_equal("FEATURE", tag_settings.header)
      assert_equal(Toys::Release::Semver::MAJOR, tag_settings.semver)
    end

    it "adds a scope to an existing tag" do
      input = {
        "modify_release_commit_tags" => {
          "feat" => {
            "scopes" => {
              "internal" => {
                "header" => nil,
                "semver" => "patch",
              },
            },
          },
        },
      }
      settings = Toys::Release::RepoSettings.new(input)
      tag_settings = settings.release_commit_tags["feat"]
      assert_equal("feat", tag_settings.tag)
      assert_equal("ADDED", tag_settings.header)
      assert_equal(Toys::Release::Semver::MINOR, tag_settings.semver)
      assert_equal(:hidden, tag_settings.header("internal"))
      assert_equal(Toys::Release::Semver::PATCH, tag_settings.semver("internal"))
    end

    it "modifies an existing scope" do
      input = {
        "release_commit_tags" => [
          {
            "tag" => "chore",
            "header" => nil,
            "semver" => nil,
            "scopes" => {
              "deps" => {
                "header" => "DEPENDENCIES",
                "semver" => "patch",
              },
            },
          },
        ],
        "modify_release_commit_tags" => {
          "chore" => {
            "scopes" => {
              "deps" => {
                "header" => "DEPENDS ON",
                "semver" => "patch",
              },
            },
          },
        },
      }
      settings = Toys::Release::RepoSettings.new(input)
      tag_settings = settings.release_commit_tags["chore"]
      assert_equal("chore", tag_settings.tag)
      assert_equal(:hidden, tag_settings.header)
      assert_equal(Toys::Release::Semver::NONE, tag_settings.semver)
      assert_equal(:hidden, tag_settings.header("foo"))
      assert_equal(Toys::Release::Semver::NONE, tag_settings.semver("foo"))
      assert_equal("DEPENDS ON", tag_settings.header("deps"))
      assert_equal(Toys::Release::Semver::PATCH, tag_settings.semver("deps"))
    end

    it "deletes an existing scope" do
      input = {
        "release_commit_tags" => [
          {
            "tag" => "chore",
            "header" => nil,
            "semver" => nil,
            "scopes" => {
              "deps" => {
                "header" => "DEPENDENCIES",
                "semver" => "patch",
              },
            },
          },
        ],
        "modify_release_commit_tags" => {
          "chore" => {
            "scopes" => {
              "deps" => nil,
            },
          },
        },
      }
      settings = Toys::Release::RepoSettings.new(input)
      tag_settings = settings.release_commit_tags["chore"]
      assert_equal("chore", tag_settings.tag)
      assert_equal(:hidden, tag_settings.header)
      assert_equal(Toys::Release::Semver::NONE, tag_settings.semver)
      assert_equal(:hidden, tag_settings.header("deps"))
      assert_equal(Toys::Release::Semver::NONE, tag_settings.semver("deps"))
    end

    it "deletes an existing tag" do
      input = {
        "modify_release_commit_tags" => {
          "feat" => nil,
        },
      }
      settings = Toys::Release::RepoSettings.new(input)
      assert_equal(false, settings.release_commit_tags.key?("feat"))
    end

    it "appends a tag" do
      input = {
        "append_release_commit_tags" => [
          "chore" => {
            "header" => nil,
            "semver" => nil,
            "scopes" => {
              "deps" => {
                "header" => "DEPENDENCIES",
                "semver" => "patch",
              },
            },
          },
        ],
      }
      settings = Toys::Release::RepoSettings.new(input)
      assert_equal("chore", settings.release_commit_tags.keys.last)
      tag_settings = settings.release_commit_tags["chore"]
      assert_equal("chore", tag_settings.tag)
      assert_equal(:hidden, tag_settings.header)
      assert_equal(Toys::Release::Semver::NONE, tag_settings.semver)
      assert_equal(:hidden, tag_settings.header("foo"))
      assert_equal(Toys::Release::Semver::NONE, tag_settings.semver("foo"))
      assert_equal("DEPENDENCIES", tag_settings.header("deps"))
      assert_equal(Toys::Release::Semver::PATCH, tag_settings.semver("deps"))
    end

    it "prepends a tag" do
      input = {
        "prepend_release_commit_tags" => [
          {
            "tag" => "chore",
            "header" => nil,
            "semver" => nil,
            "scopes" => {
              "deps" => {
                "header" => "DEPENDENCIES",
                "semver" => "patch",
              },
            },
          },
        ],
      }
      settings = Toys::Release::RepoSettings.new(input)
      assert_equal("chore", settings.release_commit_tags.keys.first)
      tag_settings = settings.release_commit_tags["chore"]
      assert_equal("chore", tag_settings.tag)
      assert_equal(:hidden, tag_settings.header)
      assert_equal(Toys::Release::Semver::NONE, tag_settings.semver)
      assert_equal(:hidden, tag_settings.header("foo"))
      assert_equal(Toys::Release::Semver::NONE, tag_settings.semver("foo"))
      assert_equal("DEPENDENCIES", tag_settings.header("deps"))
      assert_equal(Toys::Release::Semver::PATCH, tag_settings.semver("deps"))
    end
  end
end
