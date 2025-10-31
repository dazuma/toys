require_relative "helper"
require_relative "../.lib/component"
require_relative "../.lib/environment_utils"
require_relative "../.lib/repo_settings"

describe ToysReleaser::Component do
  let(:fake_tool_context) { ToysReleaser::Tests::FakeToolContext.new(allow_passthru_exec: true) }
  let(:environment_utils) { ToysReleaser::EnvironmentUtils.new(fake_tool_context, on_error_option: :raise) }
  let(:repo_settings) { ToysReleaser::RepoSettings.load_from_environment(environment_utils) }

  expected_components = [
    ["toys", "gem", "version.rb"],
    ["toys-core", "gem", "core.rb"],
    ["common-tools", "component", "version.rb"],
  ]

  expected_components.each do |(component_name, component_type, version_file_name)|
    describe "#{component_name} component" do
      let(:component) {
        ToysReleaser::Component.build(repo_settings, component_name, environment_utils)
      }
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
        assert_raises(ToysReleaser::ReleaseError) do
          component.verify_version(::Gem::Version.new("0.0.1"))
        end
      end

      it "makes a changeset" do
        changeset = component.make_change_set
        assert(changeset.finished?)
      end
    end
  end
end
