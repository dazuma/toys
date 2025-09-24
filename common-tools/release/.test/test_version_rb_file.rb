require "fileutils"
require "tmpdir"
require_relative "helper"
require_relative "../.lib/environment_utils"
require_relative "../.lib/version_rb_file"

describe ToysReleaser::VersionRbFile do
  let(:fake_tool_context) { ToysReleaser::Tests::FakeToolContext.new(allow_passthru_exec: true) }
  let(:environment_utils) { ToysReleaser::EnvironmentUtils.new(fake_tool_context) }
  let(:version1_path) { File.join(__dir__, ".data", "version1.rb") }
  let(:version2_path) { File.join(__dir__, ".data", "version2.rb") }
  let(:nonexistent_path) { File.join(__dir__, ".data", "nonexistent.rb") }
  let(:default_settings) { ToysReleaser::RepoSettings.new({}) }
  let(:change_set) { ToysReleaser::ChangeSet.new(default_settings) }
  let(:constant_name) { ["Toys", "Tests", "VERSION"] }

  it "checks existence" do
    file = ToysReleaser::VersionRbFile.new(version1_path, environment_utils, constant_name)
    assert(file.exists?)
  end

  it "checks non-existence" do
    file = ToysReleaser::VersionRbFile.new(nonexistent_path, environment_utils, constant_name)
    refute(file.exists?)
  end

  it "determines current version from content" do
    file = ToysReleaser::VersionRbFile.new(version1_path, environment_utils, constant_name)
    assert_equal("1.2.3.beta4", file.current_version.to_s)
  end

  it "determines current version from eval" do
    file = ToysReleaser::VersionRbFile.new(version1_path, environment_utils, constant_name)
    assert_equal("1.2.3.beta4", file.eval_version.to_s)
  end

  it "fails to eval when given the wrong constant" do
    file = ToysReleaser::VersionRbFile.new(version1_path, environment_utils, ["Bad"])
    assert_nil(file.eval_version)
  end

  it "modifies a file" do
    Dir.mktmpdir do |dir|
      version_path = File.join(dir, "version.md")
      FileUtils.cp(version2_path, version_path)
      file = ToysReleaser::VersionRbFile.new(version_path, environment_utils, constant_name)
      assert_equal("1.2.3", file.current_version.to_s)
      file.update_version("1.2.3.beta4")
      file1 = ToysReleaser::VersionRbFile.new(version1_path, environment_utils, constant_name)
      assert_equal(file1.content, file.content)
    end
  end
end
