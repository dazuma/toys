# frozen_string_literal: true

require_relative "helper"

describe Toys::Release::RequestLogic do
  let(:fake_tool_context) { Toys::Release::Tests::FakeToolContext.new(allow_passthru_exec: true) }
  let(:environment_utils) { Toys::Release::EnvironmentUtils.new(fake_tool_context) }
  let(:repo_settings) { Toys::Release::RepoSettings.load_from_environment(environment_utils) }
  let(:repository) { Toys::Release::Repository.new(environment_utils, repo_settings) }
  let(:request_spec) { Toys::Release::RequestSpec.new(environment_utils) }
  let(:target_branch) { "main" }

  it "handles Toys one commit after v0.19.0 tag" do
    repository.all_components.each { |component| request_spec.add(component) }
    request_spec.resolve_versions("47cfeffc9ba275dab7604e30038fed107636304f")
    request_logic = Toys::Release::RequestLogic.new(repository, request_spec, target_branch: target_branch)
    assert_equal("release: Release 3 items", request_logic.build_commit_title)
    expected_details = <<~STRING.strip
      * toys 0.19.1 (was 0.19.0)
      * toys-core 0.19.1 (was 0.19.0)
      * toys-release 0.3.2 (was 0.3.1)
    STRING
    assert_equal(expected_details, request_logic.build_commit_details)
    expected_body = <<~STRING
      This pull request prepares new releases for the following components:

       *  **toys 0.19.1** (was 0.19.0)
       *  **toys-core 0.19.1** (was 0.19.0)
       *  **toys-release 0.3.2** (was 0.3.1)

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

       *  No significant updates.

      ----

      ## toys-core

       *  DOCS: Some formatting fixes in the user guide

      ----

      ## toys-release

       *  DOCS: Some formatting fixes in the user guide

      ----

      ```
      # release_metadata DO NOT REMOVE OR MODIFY
      {
        "requested_components": {
          "toys": null,
          "toys-core": null,
          "toys-release": null,
          "common-tools": null
        }
      }
      ```
    STRING
    assert_equal(expected_body, request_logic.build_pr_body)
    assert_equal(["release: pending"], request_logic.determine_pr_labels)
  end
end
