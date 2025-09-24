require "fileutils"
require "tmpdir"
require_relative "helper"
require_relative "../.lib/changelog_file"
require_relative "../.lib/change_set"
require_relative "../.lib/environment_utils"

describe ToysReleaser::ChangelogFile do
  let(:fake_tool_context) { ToysReleaser::Tests::FakeToolContext.new }
  let(:environment_utils) { ToysReleaser::EnvironmentUtils.new(fake_tool_context) }
  let(:changelog1_path) { File.join(__dir__, ".data", "changelog1.md") }
  let(:changelog2_path) { File.join(__dir__, ".data", "changelog2.md") }
  let(:nonexistent_path) { File.join(__dir__, ".data", "nonexistent.md") }
  let(:default_settings) { ToysReleaser::RepoSettings.new({}) }
  let(:change_set) { ToysReleaser::ChangeSet.new(default_settings) }

  it "checks existence" do
    file = ToysReleaser::ChangelogFile.new(changelog1_path, environment_utils)
    assert(file.exists?)
  end

  it "checks non-existence" do
    file = ToysReleaser::ChangelogFile.new(nonexistent_path, environment_utils)
    refute(file.exists?)
  end

  it "determines current version from content" do
    file = ToysReleaser::ChangelogFile.new(changelog1_path, environment_utils)
    assert_equal("0.15.6", file.current_version.to_s)
  end

  it "reads latest entry" do
    file = ToysReleaser::ChangelogFile.new(changelog1_path, environment_utils)
    content = file.read_and_verify_latest_entry("0.15.6")
    assert_empty(fake_tool_context.console_output)
    lines = content.lines
    assert_match(%r{^### v0\.15\.6 /}, lines[0])
    assert_match(%r{\* FIXED: }, lines[2])
    assert_match(%r{\* FIXED: }, lines[3])
    assert_match(%r{\* FIXED: }, lines[4])
  end

  it "fails latest entry verification on incorrect version" do
    file = ToysReleaser::ChangelogFile.new(changelog1_path, environment_utils)
    assert_raises(ToysReleaser::Tests::FakeToolContext::FakeExit) do
      file.read_and_verify_latest_entry("0.15.61")
    end
  end

  it "appends to a file" do
    Dir.mktmpdir do |dir|
      changelog_path = File.join(dir, "changelog.md")
      FileUtils.cp(changelog2_path, changelog_path)
      file = ToysReleaser::ChangelogFile.new(changelog_path, environment_utils)
      change_set.add_message("abcde1", "fix: fixed argument parsing to allow a flag values delimited by \"=\" to contain newlines")
      change_set.add_message("abcde2", "fix: fixed minitest version failures in the system test builtin tool")
      change_set.add_message("abcde3", "fix: fixed crash in the system test builtin tool's minitest-rg integration with minitest-rg 5.3")
      change_set.finish
      file.append(change_set, "0.15.6", date: "2024-05-15")
      file1 = ToysReleaser::ChangelogFile.new(changelog1_path, environment_utils)
      assert_equal(file1.content, file.content)
    end
  end
end
