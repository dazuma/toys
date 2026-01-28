# frozen_string_literal: true

require_relative "helper"

describe Toys::Release::Component do
  let(:fake_tool_context) { Toys::Release::Tests::FakeToolContext.new(allow_passthru_exec: true) }
  let(:environment_utils) { Toys::Release::EnvironmentUtils.new(fake_tool_context, on_error_option: :raise) }
  let(:repo_settings) { Toys::Release::RepoSettings.load_from_environment(environment_utils) }
  let(:repository) { Toys::Release::Repository.new(environment_utils, repo_settings) }

  expected_components = [
    ["toys", "version.rb"],
    ["toys-core", "core.rb"],
    ["toys-release", "version.rb"],
    ["common-tools", "version.rb"],
  ]

  expected_components.each do |(component_name, version_file_name)|
    describe "#{component_name} component" do
      let(:component) { Toys::Release::Component.new(repository, component_name, environment_utils) }
      let(:changelog_file) { component.changelog_file }
      let(:version_rb_file) { component.version_rb_file }

      it "has the correct name" do
        assert_equal(component_name, component.name)
      end

      it "knows the directory" do
        assert_equal(component_name, component.directory)
        assert_equal(::File.join(environment_utils.repo_root_directory, component_name),
                     component.directory(from: :absolute))
      end

      it "accesses the changelog file" do
        assert(changelog_file.exists?)
        assert_equal("CHANGELOG.md", ::File.basename(changelog_file.path))
      end

      it "accesses the version file file" do
        assert(version_rb_file.exists?)
        assert_equal(version_file_name, ::File.basename(version_rb_file.path))
      end

      it "has no errors" do
        component.validate
      end

      it "gets the latest tag version for the main branch" do
        assert_match(/^\d+\.\d+\.\d+(?:\.\w+)*$/, component.latest_tag_version.to_s)
      end

      it "gets the latest tag for the main branch" do
        assert_match(%r{^#{component_name}/v\d+\.\d+\.\d+(?:\.\w+)*$}, component.latest_tag)
      end

      it "gets the changelog version for HEAD" do
        assert_match(/^\d+\.\d+\.\d+(?:\.\w+)*$/, component.current_changelog_version.to_s)
      end

      it "gets the version.rb version for HEAD" do
        assert_match(/^\d+\.\d+\.\d+(?:\.\w+)*$/, component.current_constant_version.to_s)
      end

      it "verifies the current changelog version" do
        component.verify_version(component.current_changelog_version)
      end

      it "errors on verifying the wrong version" do
        assert_raises(Toys::Release::ReleaseError) do
          component.verify_version(::Gem::Version.new("0.0.1"))
        end
      end

      it "makes a changeset" do
        changeset = component.make_change_set
        assert(changeset.finished?)
      end
    end
  end

  describe "#make_change_set" do
    let(:component) { Toys::Release::Component.new(repository, "toys-release", environment_utils) }

    it "creates a changeset from commits" do
      # These two commits are from 2026-Jan
      commits = repository.commit_info_sequence(from: "21fe91b8be71f1fc6def04f6fa62362cbb775b34",
                                                to: "d69c9d900287c5e8fca92303e566e220429296ed")
      change_set = component.make_change_set(commits: commits)
      assert_equal(["d69c9d900287c5e8fca92303e566e220429296ed"], change_set.significant_shas)
      assert_equal(1, change_set.change_groups.size)
      assert_equal(1, change_set.change_groups.first.changes.size)
    end

    it "creates a changeset from default tag" do
      # The "to" commit is two commits past toys-release/v0.3.2.
      change_set = component.make_change_set(to: "8c20e807a5782348b271331c6404ce5b17ed6137")
      expected_significant_shas = [
        "8d0e9a232cd6a71060a9c3c8859e7994383e6f3c",
        "8c20e807a5782348b271331c6404ce5b17ed6137",
      ]
      assert_equal(expected_significant_shas, change_set.significant_shas)
      assert_equal(2, change_set.change_groups.size)
    end
  end

  describe "#touched?" do
    # The SHA is from 2025-10-30, one commit past common-tools/v0.16.0.
    let(:sha) { "e774119e798f7efc30d9d0e469b7a88e7f54251c" }
    let(:the_commit) { repository.commit_info(sha) }
    let(:initial_sha) { "21dcf727b0f5b2f235a05a9d144a8b6a378a1aeb" }
    let(:initial_commit) { repository.commit_info(initial_sha) }
    let(:toys_component) { Toys::Release::Component.new(repository, "toys", environment_utils) }
    let(:core_component) { Toys::Release::Component.new(repository, "toys-core", environment_utils) }
    let(:tools_component) { Toys::Release::Component.new(repository, "common-tools", environment_utils) }
    let(:release_component) { Toys::Release::Component.new(repository, "toys-release", environment_utils) }

    def append_commit_message(message_addition)
      modified_message = "#{the_commit.message}\n#{message_addition}"
      the_commit.populate_for_testing(message: modified_message,
                                      parent_sha: the_commit.parent_sha,
                                      modified_paths: the_commit.modified_paths)
    end

    it "finds a change to common-tools with the actual settings" do
      assert(tools_component.touched?(the_commit))
      refute(core_component.touched?(the_commit))
      refute(toys_component.touched?(the_commit))
      refute(release_component.touched?(the_commit))
    end

    it "supports include_globs" do
      repo_settings.component_settings("toys-core").include_globs << "common-tools/release/*.rb"
      assert(tools_component.touched?(the_commit))
      assert(core_component.touched?(the_commit))
      refute(toys_component.touched?(the_commit))
      refute(release_component.touched?(the_commit))
    end

    it "supports exclude_globs" do
      repo_settings.component_settings("toys-core").include_globs << "common-tools/release/*.rb"
      repo_settings.component_settings("toys-core").exclude_globs << "common-tools/release/_*.rb"
      repo_settings.component_settings("common-tools").exclude_globs << "common-tools/release/_*.rb"
      refute(tools_component.touched?(the_commit))
      refute(core_component.touched?(the_commit))
      refute(toys_component.touched?(the_commit))
      refute(release_component.touched?(the_commit))
    end

    it "supports the initial commit" do
      refute(release_component.touched?(initial_commit))
    end

    it "recognizes touch-component and no-touch-component" do
      append_commit_message("touch-component: toys-core")
      append_commit_message("touch-component: toys-release")
      append_commit_message("no-touch-component: common-tools")
      refute(tools_component.touched?(the_commit))
      assert(core_component.touched?(the_commit))
      refute(toys_component.touched?(the_commit))
      assert(release_component.touched?(the_commit))
    end
  end
end
