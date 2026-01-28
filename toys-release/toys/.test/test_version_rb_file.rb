# frozen_string_literal: true

require "fileutils"
require "tmpdir"

require_relative "helper"

describe Toys::Release::VersionRbFile do
  let(:fake_tool_context) { Toys::Release::Tests::FakeToolContext.new(allow_passthru_exec: true) }
  let(:environment_utils) { Toys::Release::EnvironmentUtils.new(fake_tool_context) }
  let(:version1_path) { File.join(__dir__, ".data", "version1.rb") }
  let(:version2_path) { File.join(__dir__, ".data", "version2.rb") }
  let(:nonexistent_path) { File.join(__dir__, ".data", "nonexistent.rb") }

  it "checks existence" do
    file = Toys::Release::VersionRbFile.new(version1_path, environment_utils)
    assert(file.exists?)
  end

  it "checks non-existence" do
    file = Toys::Release::VersionRbFile.new(nonexistent_path, environment_utils)
    refute(file.exists?)
  end

  it "determines current version from content" do
    file = Toys::Release::VersionRbFile.new(version1_path, environment_utils)
    assert_equal("1.2.3.beta4", file.current_version.to_s)
  end

  it "modifies a file" do
    Dir.mktmpdir do |dir|
      version_path = File.join(dir, "version.md")
      FileUtils.cp(version2_path, version_path)
      file = Toys::Release::VersionRbFile.new(version_path, environment_utils)
      assert_equal("1.2.3", file.current_version.to_s)
      file.update_version("1.2.3.beta4")
      file1 = Toys::Release::VersionRbFile.new(version1_path, environment_utils)
      assert_equal(file1.content, file.content)
    end
  end
end
