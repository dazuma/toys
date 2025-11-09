# frozen_string_literal: true

require_relative "helper"

require "toys/release/component"
require "toys/release/environment_utils"
require "toys/release/repo_settings"

describe Toys::Release::Component do
  let(:fake_tool_context) { Toys::Release::Tests::FakeToolContext.new(allow_passthru_exec: true) }
  let(:environment_utils) { Toys::Release::EnvironmentUtils.new(fake_tool_context, on_error_option: :raise) }
  let(:repo_settings) { Toys::Release::RepoSettings.load_from_environment(environment_utils) }

  expected_components = [
    ["toys", "gem", "version.rb"],
    ["toys-core", "gem", "core.rb"],
    ["common-tools", "component", "version.rb"],
  ]

  expected_components.each do |(component_name, component_type, version_file_name)|
    describe "#{component_name} component" do
      let(:component) { Toys::Release::Component.build(repo_settings, component_name, environment_utils) }
      let(:changelog_file) { component.changelog_file }
      let(:version_rb_file) { component.version_rb_file }

      it "has the correct type and name" do
        assert_equal(component_type, component.type)
        assert_equal(component_name, component.name)
      end

      it "knows the directory" do
        assert_equal(component_name, component.directory)
        assert_equal(::File.join(environment_utils.context_directory, component_name),
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

  describe "#touched_message" do
    let(:sha) { "e774119e798f7efc30d9d0e469b7a88e7f54251c" }
    let(:initial_sha) { "21dcf727b0f5b2f235a05a9d144a8b6a378a1aeb" }

    it "finds a change to common-tools with the actual settings" do
      tools_component = Toys::Release::Component.build(repo_settings, "common-tools", environment_utils)
      refute_nil(tools_component.touched_message(sha))
      core_component = Toys::Release::Component.build(repo_settings, "toys-core", environment_utils)
      assert_nil(core_component.touched_message(sha))
      toys_component = Toys::Release::Component.build(repo_settings, "toys", environment_utils)
      assert_nil(toys_component.touched_message(sha))
    end

    it "supports include_globs" do
      repo_settings.component_settings("toys-core").include_globs << "common-tools/release/*.rb"
      tools_component = Toys::Release::Component.build(repo_settings, "common-tools", environment_utils)
      refute_nil(tools_component.touched_message(sha))
      core_component = Toys::Release::Component.build(repo_settings, "toys-core", environment_utils)
      refute_nil(core_component.touched_message(sha))
      toys_component = Toys::Release::Component.build(repo_settings, "toys", environment_utils)
      assert_nil(toys_component.touched_message(sha))
    end

    it "supports exclude_globs" do
      repo_settings.component_settings("toys-core").include_globs << "common-tools/release/*.rb"
      repo_settings.component_settings("toys-core").exclude_globs << "common-tools/release/_*.rb"
      repo_settings.component_settings("common-tools").exclude_globs << "common-tools/release/_*.rb"
      tools_component = Toys::Release::Component.build(repo_settings, "common-tools", environment_utils)
      assert_nil(tools_component.touched_message(sha))
      core_component = Toys::Release::Component.build(repo_settings, "toys-core", environment_utils)
      assert_nil(core_component.touched_message(sha))
      toys_component = Toys::Release::Component.build(repo_settings, "toys", environment_utils)
      assert_nil(toys_component.touched_message(sha))
    end

    it "supports the initial commit" do
      release_component = Toys::Release::Component.build(repo_settings, "toys-release", environment_utils)
      assert_nil(release_component.touched_message(initial_sha))
    end
  end
end
