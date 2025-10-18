require_relative "helper"
require_relative "../.lib/environment_utils"
require_relative "../.lib/repository"
require_relative "../.lib/repo_settings"
require_relative "../.lib/request_logic"
require_relative "../.lib/request_spec"

describe ToysReleaser::RequestLogic do
  let(:fake_tool_context) { ToysReleaser::Tests::FakeToolContext.new(allow_passthru_exec: true) }
  let(:environment_utils) { ToysReleaser::EnvironmentUtils.new(fake_tool_context) }
  let(:repo_settings) { ToysReleaser::RepoSettings.load_from_environment(environment_utils) }
  let(:repository) { ToysReleaser::Repository.new(environment_utils, repo_settings) }
  let(:request_spec) { ToysReleaser::RequestSpec.new(environment_utils) }

  it "handles Toys two commits before v0.15.6 tag" do
    request_spec.resolve_versions(repository, release_ref: "4c620495f915fef39d1583170beb6489d0c7073d")
    request_logic = ToysReleaser::RequestLogic.new(repository, request_spec)
    assert_match(%r|^release/multi/\d{14}$|, request_logic.determine_release_branch)
    assert_equal("release: Release 2 items", request_logic.build_commit_title)
    expected_details = <<~STRING.strip
      * toys 0.15.6 (was 0.15.5)
      * toys-core 0.15.6 (was 0.15.5)
    STRING
    assert_equal(expected_details, request_logic.build_commit_details)
    expected_body = <<~STRING
      This pull request prepares new releases for the following components:

       *  **toys 0.15.6** (was 0.15.5)
       *  **toys-core 0.15.6** (was 0.15.5)

      For each releasable component, this pull request modifies the version \
      and provides an initial changelog entry based on \
      [conventional commit](https://conventionalcommits.org) messages. You can \
      edit these changes before merging, to release a different version or to \
      alter the changelog text.

       *  To confirm this release, merge this pull request, ensuring the \
      "release: pending" label is set. The release script will trigger \
      automatically on merge.
       *  To abort this release, close this pull request without merging.

      The generated changelog entries have been copied below:

      ----

      ## toys

       *  FIXED: Fixed minitest version failures in the system test builtin tool

      ----

      ## toys-core

       *  No significant updates.
      STRING
    assert_equal(expected_body, request_logic.build_pr_body)
    assert_equal(["release: pending"], request_logic.determine_pr_labels)
  end
end
