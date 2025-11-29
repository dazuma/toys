# frozen_string_literal: true

require_relative "helper"

describe Toys::Release::RequestLogic do
  let(:fake_tool_context) { Toys::Release::Tests::FakeToolContext.new(allow_passthru_exec: true) }
  let(:environment_utils) { Toys::Release::EnvironmentUtils.new(fake_tool_context) }
  let(:repo_settings) { Toys::Release::RepoSettings.load_from_environment(environment_utils) }
  let(:repository) { Toys::Release::Repository.new(environment_utils, repo_settings) }
  let(:request_spec) { Toys::Release::RequestSpec.new(environment_utils) }
  let(:target_branch) { "main" }

  it "handles Toys two commits before v0.15.6 tag" do
    request_spec.resolve_versions(repository, release_ref: "4c620495f915fef39d1583170beb6489d0c7073d")
    request_logic = Toys::Release::RequestLogic.new(repository, request_spec, target_branch: target_branch)
    assert_match(%r|^release/multi/\d{14}-\d{6}/#{target_branch}$|, request_logic.determine_release_branch)
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
