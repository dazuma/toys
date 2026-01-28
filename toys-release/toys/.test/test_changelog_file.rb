# frozen_string_literal: true

require "fileutils"
require "tmpdir"

require_relative "helper"

describe Toys::Release::ChangelogFile do
  let(:fake_tool_context) { Toys::Release::Tests::FakeToolContext.new }
  let(:environment_utils) { Toys::Release::EnvironmentUtils.new(fake_tool_context) }
  let(:changelog1_path) { File.join(__dir__, ".data", "changelog1.md") }
  let(:changelog2_path) { File.join(__dir__, ".data", "changelog2.md") }
  let(:changelog3_path) { File.join(__dir__, ".data", "changelog3.md") }
  let(:nonexistent_path) { File.join(__dir__, ".data", "nonexistent.md") }
  let(:component_name) { "my_component" }
  let(:repo_path) { "example/repo" }
  let(:settings_customization) { {"repo" => repo_path, "components" => [{"name" => component_name}]} }
  let(:repo_settings) { Toys::Release::RepoSettings.new(settings_customization) }
  let(:component_settings) { repo_settings.component_settings(component_name) }
  let(:change_set) { Toys::Release::ChangeSet.new(repo_settings, component_settings) }

  def commit_with(sha, message)
    Toys::Release::CommitInfo.new(nil, sha).populate_for_testing(message: message)
  end

  it "checks existence" do
    file = Toys::Release::ChangelogFile.new(changelog1_path, environment_utils)
    assert(file.exists?)
  end

  it "checks non-existence" do
    file = Toys::Release::ChangelogFile.new(nonexistent_path, environment_utils)
    refute(file.exists?)
  end

  it "determines current version from content" do
    file = Toys::Release::ChangelogFile.new(changelog1_path, environment_utils)
    assert_equal("0.15.6", file.current_version.to_s)
  end

  it "reads latest entry" do
    file = Toys::Release::ChangelogFile.new(changelog1_path, environment_utils)
    content = file.read_and_verify_latest_entry("0.15.6")
    assert_empty(fake_tool_context.console_output)
    lines = content.lines
    assert_match(%r{^### v0\.15\.6 /}, lines[0])
    assert_match(/\* FIXED: /, lines[2])
    assert_match(/\* FIXED: /, lines[3])
    assert_match(/\* FIXED: /, lines[4])
  end

  it "fails latest entry verification on incorrect version" do
    file = Toys::Release::ChangelogFile.new(changelog1_path, environment_utils)
    assert_raises(Toys::Release::Tests::FakeToolContext::FakeExit) do
      file.read_and_verify_latest_entry("0.15.61")
    end
  end

  it "appends to a file" do
    Dir.mktmpdir do |dir|
      changelog_path = File.join(dir, "changelog.md")
      FileUtils.cp(changelog2_path, changelog_path)
      file = Toys::Release::ChangelogFile.new(changelog_path, environment_utils)
      change_set.add_commit(
        commit_with(
          "abcde1",
          "fix: fixed argument parsing to allow a flag values delimited by \"=\" to contain newlines"
        )
      )
      change_set.add_commit(
        commit_with(
          "abcde2",
          "fix: fixed minitest version failures in the system test builtin tool"
        )
      )
      change_set.add_commit(
        commit_with(
          "abcde3",
          "fix: fixed crash in the system test builtin tool's minitest-rg integration with minitest-rg 5.3"
        )
      )
      change_set.finish
      file.append(change_set, "0.15.6", date: "2024-05-15")
      file1 = Toys::Release::ChangelogFile.new(changelog1_path, environment_utils)
      assert_equal(file1.content, file.content)
    end
  end

  it "appends to an empty file" do
    Dir.mktmpdir do |dir|
      changelog_path = File.join(dir, "changelog.md")
      FileUtils.cp(changelog3_path, changelog_path)
      file = Toys::Release::ChangelogFile.new(changelog_path, environment_utils)
      change_set.add_commit(
        commit_with(
          "abcde1",
          "fix: fix for uri version mismatch error in certain bundler integration cases"
        )
      )
      change_set.finish
      file.append(change_set, "0.15.5", date: "2024-01-31")
      file2 = Toys::Release::ChangelogFile.new(changelog2_path, environment_utils)
      assert_equal(file2.content, file.content)
    end
  end
end
