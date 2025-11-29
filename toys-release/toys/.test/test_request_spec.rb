# frozen_string_literal: true

require_relative "helper"

describe Toys::Release::RequestSpec do
  let(:fake_tool_context) { Toys::Release::Tests::FakeToolContext.new(allow_passthru_exec: true) }
  let(:environment_utils) { Toys::Release::EnvironmentUtils.new(fake_tool_context, on_error_option: :raise) }
  let(:repo_settings) { Toys::Release::RepoSettings.load_from_environment(environment_utils) }
  let(:repository) { Toys::Release::Repository.new(environment_utils, repo_settings) }
  let(:request_spec) { Toys::Release::RequestSpec.new(environment_utils) }

  it "resolves default changes to Toys at HEAD" do
    request_spec.resolve_versions(repository)
    # Can't make any particular assertion here. Just make sure it didn't crash.
    assert(request_spec.resolved_components.size <= 3)
  end

  it "resolves default changes to Toys at v0.15.6 tag" do
    request_spec.resolve_versions(repository, release_ref: "toys/v0.15.6")
    # At this point, toys and toys-core were just released and should show no
    # changes, and common-tools had no updates since 0.15.5.1.
    assert_empty(request_spec.resolved_components)
  end

  it "resolves default changes to Toys just before v0.15.6 tag" do
    request_spec.resolve_versions(repository, release_ref: "a922cf30093c539f3d46733e040567a3d8d9d847")
    # At this point, toys and toys-core should show fixes, but common-tools
    # had no updates.
    resolved_components = request_spec.resolved_components
    assert_equal(2, resolved_components.size)
    assert_equal("toys-core", resolved_components[1].component_name)
    assert_equal(::Gem::Version.new("0.15.6"), resolved_components[1].version)
    core_changeset = resolved_components[1].change_set
    assert_equal(1, core_changeset.change_groups.size)
    refute_nil(core_changeset.change_groups[0].header)
    assert_equal(1, core_changeset.change_groups[0].changes.size)
    assert_equal("toys", resolved_components[0].component_name)
    assert_equal(::Gem::Version.new("0.15.6"), resolved_components[0].version)
    toys_changeset = resolved_components[0].change_set
    assert_equal(1, toys_changeset.change_groups.size)
    assert_equal(1, toys_changeset.change_groups[0].changes.size)
    refute_nil(toys_changeset.change_groups[0].header)
  end

  it "resolves default changes to Toys two commits before v0.15.6 tag" do
    request_spec.resolve_versions(repository, release_ref: "4c620495f915fef39d1583170beb6489d0c7073d")
    # At this point, toys had a fix but the other components had no updates.
    # However, the coordination group should bring toys-core in.
    resolved_components = request_spec.resolved_components
    assert_equal(2, resolved_components.size)
    assert_equal("toys-core", resolved_components[1].component_name)
    assert_equal(::Gem::Version.new("0.15.6"), resolved_components[1].version)
    core_changeset = resolved_components[1].change_set
    assert_equal(1, core_changeset.change_groups.size)
    assert_equal(1, core_changeset.change_groups[0].changes.size)
    assert_nil(core_changeset.change_groups[0].header)
    assert_equal("toys", resolved_components[0].component_name)
    assert_equal(::Gem::Version.new("0.15.6"), resolved_components[0].version)
    toys_changeset = resolved_components[0].change_set
    assert_equal(1, toys_changeset.change_groups.size)
    assert_equal(1, toys_changeset.change_groups[0].changes.size)
    refute_nil(toys_changeset.change_groups[0].header)
  end

  it "resolves requested versioned changes to Toys common-tools two commits before v0.15.6 tag" do
    request_spec.add("common-tools", version: "0.15.5.2")
    request_spec.resolve_versions(repository, release_ref: "4c620495f915fef39d1583170beb6489d0c7073d")
    # We should force a release to common-tools but ignore the nonrequested components
    resolved_components = request_spec.resolved_components
    assert_equal(1, resolved_components.size)
    assert_equal("common-tools", resolved_components[0].component_name)
    assert_equal(::Gem::Version.new("0.15.5.2"), resolved_components[0].version)
    changeset = resolved_components[0].change_set
    assert_equal(1, changeset.change_groups.size)
    assert_equal(1, changeset.change_groups[0].changes.size)
    assert_nil(changeset.change_groups[0].header)
  end

  it "resolves requested semver changes to Toys common-tools two commits before v0.15.6 tag" do
    request_spec.add("common-tools", version: "minor")
    request_spec.resolve_versions(repository, release_ref: "4c620495f915fef39d1583170beb6489d0c7073d")
    # We should force a release to common-tools but ignore the nonrequested components
    resolved_components = request_spec.resolved_components
    assert_equal(1, resolved_components.size)
    assert_equal("common-tools", resolved_components[0].component_name)
    assert_equal(::Gem::Version.new("0.16.0"), resolved_components[0].version)
    changeset = resolved_components[0].change_set
    assert_equal(1, changeset.change_groups.size)
    assert_equal(1, changeset.change_groups[0].changes.size)
    assert_nil(changeset.change_groups[0].header)
  end

  it "resolves requested changes to Toys toys-core two commits before v0.15.6 tag" do
    request_spec.add("toys-core")
    request_spec.resolve_versions(repository, release_ref: "4c620495f915fef39d1583170beb6489d0c7073d")
    # A toys-core request implies a toys request, and toys has a fix, so this
    # should bring in both.
    resolved_components = request_spec.resolved_components
    assert_equal(2, resolved_components.size)
    assert_equal("toys-core", resolved_components[1].component_name)
    assert_equal(::Gem::Version.new("0.15.6"), resolved_components[1].version)
    core_changeset = resolved_components[1].change_set
    assert_equal(1, core_changeset.change_groups.size)
    assert_equal(1, core_changeset.change_groups[0].changes.size)
    assert_nil(core_changeset.change_groups[0].header)
    assert_equal("toys", resolved_components[0].component_name)
    assert_equal(::Gem::Version.new("0.15.6"), resolved_components[0].version)
    toys_changeset = resolved_components[0].change_set
    assert_equal(1, toys_changeset.change_groups.size)
    assert_equal(1, toys_changeset.change_groups[0].changes.size)
    refute_nil(toys_changeset.change_groups[0].header)
  end

  it "resolves requested versioned changes to Toys toys-core two commits before v0.15.6 tag" do
    request_spec.add("toys-core", version: "0.16.0")
    request_spec.resolve_versions(repository, release_ref: "4c620495f915fef39d1583170beb6489d0c7073d")
    # A toys-core request implies a toys request, and toys has a fix, so this
    # should bring in both.
    resolved_components = request_spec.resolved_components
    assert_equal(2, resolved_components.size)
    assert_equal("toys-core", resolved_components[1].component_name)
    assert_equal(::Gem::Version.new("0.16.0"), resolved_components[1].version)
    core_changeset = resolved_components[1].change_set
    assert_equal(1, core_changeset.change_groups.size)
    assert_equal(1, core_changeset.change_groups[0].changes.size)
    assert_nil(core_changeset.change_groups[0].header)
    assert_equal("toys", resolved_components[0].component_name)
    assert_equal(::Gem::Version.new("0.16.0"), resolved_components[0].version)
    toys_changeset = resolved_components[0].change_set
    assert_equal(1, toys_changeset.change_groups.size)
    assert_equal(1, toys_changeset.change_groups[0].changes.size)
    refute_nil(toys_changeset.change_groups[0].header)
  end

  it "resolves requested semver changes to Toys toys-core two commits before v0.15.6 tag" do
    request_spec.add("toys-core", version: "minor")
    request_spec.resolve_versions(repository, release_ref: "4c620495f915fef39d1583170beb6489d0c7073d")
    # A toys-core request implies a toys request, and toys has a fix, so this
    # should bring in both.
    resolved_components = request_spec.resolved_components
    assert_equal(2, resolved_components.size)
    assert_equal("toys-core", resolved_components[1].component_name)
    assert_equal(::Gem::Version.new("0.16.0"), resolved_components[1].version)
    core_changeset = resolved_components[1].change_set
    assert_equal(1, core_changeset.change_groups.size)
    assert_equal(1, core_changeset.change_groups[0].changes.size)
    assert_nil(core_changeset.change_groups[0].header)
    assert_equal("toys", resolved_components[0].component_name)
    assert_equal(::Gem::Version.new("0.16.0"), resolved_components[0].version)
    toys_changeset = resolved_components[0].change_set
    assert_equal(1, toys_changeset.change_groups.size)
    assert_equal(1, toys_changeset.change_groups[0].changes.size)
    refute_nil(toys_changeset.change_groups[0].header)
  end

  # TODO: test error cases
end
