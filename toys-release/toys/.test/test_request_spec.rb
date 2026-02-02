# frozen_string_literal: true

require_relative "helper"

describe Toys::Release::RequestSpec do
  let(:repo_settings_input) { {} }
  let(:fake_tool_context) { Toys::Release::Tests::FakeToolContext.new(allow_passthru_exec: true) }
  let(:environment_utils) { Toys::Release::EnvironmentUtils.new(fake_tool_context, on_error_option: :raise) }
  let(:repo_settings) do
    if repo_settings_input.empty?
      Toys::Release::RepoSettings.load_from_environment(environment_utils)
    else
      Toys::Release::RepoSettings.new(repo_settings_input)
    end
  end
  let(:repository) { Toys::Release::Repository.new(environment_utils, repo_settings) }
  let(:request_spec) { Toys::Release::RequestSpec.new(environment_utils) }
  let(:common_tools_component) { repository.component_named("common-tools") }
  let(:toys_component) { repository.component_named("toys") }
  let(:core_component) { repository.component_named("toys-core") }
  let(:release_component) { repository.component_named("toys-release") }

  it "resolves default changes to Toys at HEAD" do
    request_spec.resolve_versions(repository.current_sha, repository)
    # Can't make any particular assertion here. Just make sure it didn't crash.
  end

  it "resolves default changes to Toys at v0.19.0 tag" do
    repository.all_components.each { |component| request_spec.add(component) }
    request_spec.resolve_versions(repository.current_sha("toys/v0.19.0"), repository)
    # At this point, toys, toys-core, and toys-release were just released and
    # should show no changes, and common-tools had no updates since 0.18.0.
    assert_empty(request_spec.resolved_components)
  end

  it "resolves default changes to Toys expecting only toys-release changes" do
    repository.all_components.each { |component| request_spec.add(component) }
    request_spec.resolve_versions("450e87c777d642f2adf0add69cbcc0bca243c9d9", repository)
    # This is one commit after toys-release/v0.2.1.
    # At this point, only toys-release had updates.
    resolved_components = request_spec.resolved_components
    assert_equal(1, resolved_components.size)

    component = resolved_components[0]
    assert_equal("toys-release", component.component_name)
    assert_equal(::Gem::Version.new("0.2.2"), component.version)
    changeset = component.change_set
    assert_equal(1, changeset.change_groups.size)
    assert_equal("FIXED", changeset.change_groups[0].header)
    assert_equal(5, changeset.change_groups[0].changes.size)
  end

  it "resolves default changes to Toys with a coordination group" do
    repository.all_components.each { |component| request_spec.add(component) }
    request_spec.resolve_versions("47cfeffc9ba275dab7604e30038fed107636304f", repository)
    # This is one commit after toys/v0.19.0.
    # This commit modifies toys-core and toys-release, and should bring toys in
    # via the coordination group.
    resolved_components = request_spec.resolved_components
    assert_equal(3, resolved_components.size)

    component = resolved_components[0]
    assert_equal("toys", component.component_name)
    assert_equal(::Gem::Version.new("0.19.1"), component.version)
    changeset = component.change_set
    assert_equal(1, changeset.change_groups.size)
    assert_nil(changeset.change_groups[0].header)
    assert_equal(1, changeset.change_groups[0].changes.size)

    component = resolved_components[1]
    assert_equal("toys-core", component.component_name)
    assert_equal(::Gem::Version.new("0.19.1"), component.version)
    changeset = component.change_set
    assert_equal(1, changeset.change_groups.size)
    assert_equal("DOCS", changeset.change_groups[0].header)
    assert_equal(1, changeset.change_groups[0].changes.size)

    component = resolved_components[2]
    assert_equal("toys-release", component.component_name)
    assert_equal(::Gem::Version.new("0.3.2"), component.version)
    changeset = component.change_set
    assert_equal(1, changeset.change_groups.size)
    assert_equal("DOCS", changeset.change_groups[0].header)
    assert_equal(1, changeset.change_groups[0].changes.size)
  end

  it "resolves requested versioned changes to Toys" do
    request_spec.add(common_tools_component, version: "0.15.5.2")
    request_spec.resolve_versions("4c620495f915fef39d1583170beb6489d0c7073d", repository)
    # This commit is two commits before toys/v0.15.6. No actual changes were
    # made to common-tools. We should force a release to common-tools but
    # ignore the nonrequested components
    resolved_components = request_spec.resolved_components
    assert_equal(1, resolved_components.size)

    component = resolved_components[0]
    assert_equal("common-tools", component.component_name)
    assert_equal(::Gem::Version.new("0.15.5.2"), component.version)
    changeset = component.change_set
    assert_equal(1, changeset.change_groups.size)
    assert_nil(changeset.change_groups[0].header)
    assert_equal(1, changeset.change_groups[0].changes.size)
  end

  it "resolves requested semver changes to Toys" do
    request_spec.add(common_tools_component, version: "minor")
    request_spec.resolve_versions("4c620495f915fef39d1583170beb6489d0c7073d", repository)
    # This commit is two commits before toys/v0.15.6. No actual changes were
    # made to common-tools. We should force a release to common-tools but
    # ignore the nonrequested components
    resolved_components = request_spec.resolved_components
    assert_equal(1, resolved_components.size)

    component = resolved_components[0]
    assert_equal("common-tools", component.component_name)
    assert_equal(::Gem::Version.new("0.16.0"), component.version)
    changeset = component.change_set
    assert_equal(1, changeset.change_groups.size)
    assert_nil(changeset.change_groups[0].header)
    assert_equal(1, changeset.change_groups[0].changes.size)
  end

  it "resolves requested changes to Toys when a non-requested member of the same group has a change" do
    request_spec.add(toys_component)
    request_spec.resolve_versions("47cfeffc9ba275dab7604e30038fed107636304f", repository)
    # This is one commit after toys/v0.19.0.
    # This commit modifies toys-core and toys-release. The request for toys
    # should bring in both toys and toys-core but ignore toys-release.
    resolved_components = request_spec.resolved_components
    assert_equal(2, resolved_components.size)

    component = resolved_components[0]
    assert_equal("toys", component.component_name)
    assert_equal(::Gem::Version.new("0.19.1"), component.version)
    changeset = component.change_set
    assert_equal(1, changeset.change_groups.size)
    assert_nil(changeset.change_groups[0].header)
    assert_equal(1, changeset.change_groups[0].changes.size)

    component = resolved_components[1]
    assert_equal("toys-core", component.component_name)
    assert_equal(::Gem::Version.new("0.19.1"), component.version)
    changeset = component.change_set
    assert_equal(1, changeset.change_groups.size)
    assert_equal("DOCS", changeset.change_groups[0].header)
    assert_equal(1, changeset.change_groups[0].changes.size)
  end

  it "resolves requested versioned changes to Toys when a non-requested member of the same group has a change" do
    request_spec.add(toys_component, version: "0.21.0")
    request_spec.resolve_versions("47cfeffc9ba275dab7604e30038fed107636304f", repository)
    # This is one commit after toys/v0.19.0.
    # This commit modifies toys-core and toys-release. The request for toys
    # should bring in both toys and toys-core but ignore toys-release.
    resolved_components = request_spec.resolved_components
    assert_equal(2, resolved_components.size)

    component = resolved_components[0]
    assert_equal("toys", component.component_name)
    assert_equal(::Gem::Version.new("0.21.0"), component.version)
    changeset = component.change_set
    assert_equal(1, changeset.change_groups.size)
    assert_nil(changeset.change_groups[0].header)
    assert_equal(1, changeset.change_groups[0].changes.size)

    component = resolved_components[1]
    assert_equal("toys-core", component.component_name)
    assert_equal(::Gem::Version.new("0.21.0"), component.version)
    changeset = component.change_set
    assert_equal(1, changeset.change_groups.size)
    assert_equal("DOCS", changeset.change_groups[0].header)
    assert_equal(1, changeset.change_groups[0].changes.size)
  end

  it "resolves requested semver changes to Toys when a non-requested member of the same group has a change" do
    request_spec.add(toys_component, version: "minor")
    request_spec.resolve_versions("47cfeffc9ba275dab7604e30038fed107636304f", repository)
    # This is one commit after toys/v0.19.0.
    # This commit modifies toys-core and toys-release. The request for toys
    # should bring in both toys and toys-core but ignore toys-release.
    resolved_components = request_spec.resolved_components
    assert_equal(2, resolved_components.size)

    component = resolved_components[0]
    assert_equal("toys", component.component_name)
    assert_equal(::Gem::Version.new("0.20.0"), component.version)
    changeset = component.change_set
    assert_equal(1, changeset.change_groups.size)
    assert_nil(changeset.change_groups[0].header)
    assert_equal(1, changeset.change_groups[0].changes.size)

    component = resolved_components[1]
    assert_equal("toys-core", component.component_name)
    assert_equal(::Gem::Version.new("0.20.0"), component.version)
    changeset = component.change_set
    assert_equal(1, changeset.change_groups.size)
    assert_equal("DOCS", changeset.change_groups[0].header)
    assert_equal(1, changeset.change_groups[0].changes.size)
  end

  it "resolves updates via a dependency" do
    settings_text = <<~STRING
      components:
        - name: toys-core
          version_rb_path: lib/toys/core.rb
        - name: toys
          update_dependencies:
            dependencies: [toys-core]
            dependency_semver_threshold: patch
    STRING
    repo_settings_input.merge!(YAML.load(settings_text))
    request_spec.add(core_component)
    # At this point, a docs change was made to toys-core since the 0.19.0
    # release, but no changes were made to toys.
    request_spec.resolve_versions("47cfeffc9ba275dab7604e30038fed107636304f", repository)
    resolved_components = request_spec.resolved_components
    assert_equal(2, resolved_components.size)

    component = resolved_components[0]
    assert_equal("toys-core", component.component_name)
    assert_equal(::Gem::Version.new("0.19.1"), component.version)
    changeset = component.change_set
    assert_equal(1, changeset.change_groups.size)
    assert_equal("DOCS", changeset.change_groups[0].header)
    assert_empty(changeset.updated_dependency_versions)

    component = resolved_components[1]
    assert_equal("toys", component.component_name)
    assert_equal(::Gem::Version.new("0.19.1"), component.version)
    changeset = component.change_set
    assert_equal(1, changeset.change_groups.size)
    change_group = changeset.change_groups[0]
    assert_equal("DEPENDENCY", change_group.header)
    assert_equal(1, change_group.changes.size)
    assert_equal("Updated \"toys-core\" dependency to 0.19.1", change_group.changes[0])
    assert_equal({"toys-core" => Gem::Version.new("0.19.1")}, changeset.updated_dependency_versions)
  end

  it "resolves a release that includes both normal and dependency updates" do
    settings_text = <<~STRING
      components:
        - name: toys-release
        - name: toys
          update_dependencies:
            dependencies: [toys-release]
    STRING
    repo_settings_input.merge!(YAML.load(settings_text))
    request_spec.add(release_component)
    # At this point, just before toys 0.19.1, patches changes were made to toys
    # and minor changes to toys-release.
    request_spec.resolve_versions("8c20e807a5782348b271331c6404ce5b17ed6137", repository)
    resolved_components = request_spec.resolved_components
    assert_equal(2, resolved_components.size)

    component = resolved_components[0]
    assert_equal("toys-release", component.component_name)
    assert_equal(::Gem::Version.new("0.4.0"), component.version)
    assert_empty(component.change_set.updated_dependency_versions)

    component = resolved_components[1]
    assert_equal("toys", component.component_name)
    assert_equal(::Gem::Version.new("0.20.0"), component.version)
    changeset = component.change_set
    assert_equal(2, changeset.change_groups.size)
    change_group = changeset.change_groups.last
    assert_equal("DEPENDENCY", change_group.header)
    assert_equal(1, change_group.changes.size)
    assert_equal("Updated \"toys-release\" dependency to 0.4.0", change_group.changes[0])
    assert_equal({"toys-release" => Gem::Version.new("0.4.0")}, changeset.updated_dependency_versions)
  end

  # TODO: test error cases
end
