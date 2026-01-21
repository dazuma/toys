# frozen_string_literal: true

require_relative "helper"

describe Toys::Release::PullRequest do
  let(:fake_tool_context) { Toys::Release::Tests::FakeToolContext.new(allow_passthru_exec: true) }
  let(:environment_utils) { Toys::Release::EnvironmentUtils.new(fake_tool_context) }
  let(:repo_settings) { Toys::Release::RepoSettings.load_from_environment(environment_utils) }
  let(:repository) { Toys::Release::Repository.new(environment_utils, repo_settings) }

  it "parses request input string from metadata" do
    body = <<~BODY
      This is a release.

      ```
      # release_metadata DO NOT MODIFY OR DELETE
      {
        "requested_components": {
          "toys": "1.2.3",
          "toys-release": null
        }
      }
      ```
    BODY
    resource = {
      "body" => body,
    }
    pull_request = Toys::Release::PullRequest.new(repository, resource)
    expected_requested_components = {
      "toys" => "1.2.3",
      "toys-release" => nil,
    }
    assert_equal(expected_requested_components, pull_request.requested_components)
  end
end
