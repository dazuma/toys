require_relative "helper"
require_relative "../.lib/environment_utils"
require_relative "../.lib/repo_settings"
require_relative "../.lib/releasable_unit"

describe ToysReleaser::ReleasableUnit do
  let(:fake_tool_context) { ToysReleaser::Tests::FakeToolContext.new(allow_passthru_exec: true) }
  let(:environment_utils) { ToysReleaser::EnvironmentUtils.new(fake_tool_context, on_error_option: :raise) }
  let(:repo_settings) { ToysReleaser::RepoSettings.load_from_environment(environment_utils) }

  expected_units = [
    ["toys", "gem", "version.rb"],
    ["toys-core", "gem", "core.rb"],
    ["common-tools", "unit", "version.rb"],
  ]

  expected_units.each do |(unit_name, unit_type, version_file_name)|
    describe "#{unit_name} unit" do
      let(:releasable_unit) {
        ToysReleaser::ReleasableUnit.build(repo_settings, unit_name, environment_utils)
      }
      let(:changelog_file) { releasable_unit.changelog_file }
      let(:version_rb_file) { releasable_unit.version_rb_file }

      it "has the correct type and name" do
        assert_equal(unit_type, releasable_unit.type)
        assert_equal(unit_name, releasable_unit.name)
      end

      it "knows the directory" do
        assert_equal(unit_name, releasable_unit.directory)
        assert_equal(::File.join(environment_utils.context_directory, unit_name),
          releasable_unit.directory(from: :absolute))
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
        releasable_unit.validate
      end

      it "gets the latest tag version for the main branch" do
        assert_match(/^\d+\.\d+\.\d+(?:\.\w+)*$/, releasable_unit.latest_tag_version.to_s)
      end

      it "gets the latest tag for the main branch" do
        assert_match(%r{^#{unit_name}/v\d+\.\d+\.\d+(?:\.\w+)*$}, releasable_unit.latest_tag)
      end

      it "gets the changelog version for HEAD" do
        assert_match(/^\d+\.\d+\.\d+(?:\.\w+)*$/, releasable_unit.current_changelog_version.to_s)
      end

      it "gets the version.rb version for HEAD" do
        assert_match(/^\d+\.\d+\.\d+(?:\.\w+)*$/, releasable_unit.current_constant_version.to_s)
      end

      it "verifies the latest tag version" do
        tag_version = releasable_unit.latest_tag_version
        releasable_unit.verify_version(tag_version)
      end

      it "errors on verifying the wrong version" do
        assert_raises(ToysReleaser::ReleaseError) do
          releasable_unit.verify_version(::Gem::Version.new("0.0.1"))
        end
      end

      it "makes a changeset" do
        changeset = releasable_unit.make_change_set
        assert(changeset.finished?)
      end
    end
  end
end
