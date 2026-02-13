# frozen_string_literal: true

require "yaml"
require_relative "helper"

describe Toys::Release::RepoSettings do
  let(:fake_tool_context) { Toys::Release::Tests::FakeToolContext.new }
  let(:environment_utils) { Toys::Release::EnvironmentUtils.new(fake_tool_context) }

  it "loads the toys repo settings" do
    settings = Toys::Release::RepoSettings.load_from_environment(environment_utils)
    assert_empty(settings.errors)
    assert_empty(settings.warnings)

    assert_equal("dazuma/toys", settings.repo_path)
    assert_equal("main", settings.main_branch)
    assert_equal("Daniel Azuma", settings.git_user_name)
    assert_equal("dazuma@gmail.com", settings.git_user_email)
    assert_nil(settings.required_checks_regexp)
    assert_equal(900, settings.required_checks_timeout)
    assert_equal("dazuma", settings.repo_owner)
    assert_equal(false, settings.signoff_commits?)
    assert_equal(true, settings.enable_release_automation?)
    assert_equal(:delete, settings.issue_number_suffix_handling)
    assert_equal("BREAKING CHANGE", settings.breaking_change_header)
    assert_equal("No significant updates.", settings.no_significant_updates_notice)
    assert_equal("*", settings.changelog_bullet)

    assert_equal(["toys", "toys-core", "toys-release", "common-tools"], settings.all_component_names)
    assert_equal(["toys", "toys-core", "toys-release", "common-tools"], settings.all_component_settings.map(&:name))
    assert_equal([["toys", "toys-core"]], settings.coordination_groups)

    feat_tag_settings = settings.commit_tag_named("feat")
    assert_equal("feat", feat_tag_settings.tag)
    assert_equal("ADDED", feat_tag_settings.header)
    assert_equal(Toys::Release::Semver::MINOR, feat_tag_settings.semver)
    fix_tag_settings = settings.commit_tag_named("fix")
    assert_equal("fix", fix_tag_settings.tag)
    assert_equal("FIXED", fix_tag_settings.header)
    assert_equal(Toys::Release::Semver::PATCH, fix_tag_settings.semver)
    docs_tag_settings = settings.commit_tag_named("docs")
    assert_equal("docs", docs_tag_settings.tag)
    assert_equal("DOCS", docs_tag_settings.header)
    assert_equal(Toys::Release::Semver::PATCH, docs_tag_settings.semver)
    chore_tag_settings = settings.commit_tag_named("chore")
    assert_equal("chore", chore_tag_settings.tag)
    assert_equal(:hidden, chore_tag_settings.header)
    assert_equal(Toys::Release::Semver::NONE, chore_tag_settings.semver)

    toys_core_settings = settings.component_settings("toys-core")
    assert_equal("toys-core", toys_core_settings.name)
    assert_equal("toys-core", toys_core_settings.directory)
    assert_equal("CHANGELOG.md", toys_core_settings.changelog_path)
    assert_equal("gems/toys-core", toys_core_settings.gh_pages_directory)
    assert_equal("version", toys_core_settings.gh_pages_version_var)
    assert(toys_core_settings.gh_pages_enabled)
    assert_equal("lib/toys/core.rb", toys_core_settings.version_rb_path)
    assert_nil(toys_core_settings.step_named("copy_core_docs"))
    assert_empty(toys_core_settings.step_named("build_yard").inputs)
    assert_equal("redcarpet", toys_core_settings.step_named("build_yard").options["uses_gems"])
    assert_equal(:delete, toys_core_settings.issue_number_suffix_handling)
    assert_equal("BREAKING CHANGE", toys_core_settings.breaking_change_header)
    assert_equal("No significant updates.", toys_core_settings.no_significant_updates_notice)

    feat_tag_settings = toys_core_settings.commit_tag_named("feat")
    assert_equal("feat", feat_tag_settings.tag)
    assert_equal("ADDED", feat_tag_settings.header)
    assert_equal(Toys::Release::Semver::MINOR, feat_tag_settings.semver)
    fix_tag_settings = toys_core_settings.commit_tag_named("fix")
    assert_equal("fix", fix_tag_settings.tag)
    assert_equal("FIXED", fix_tag_settings.header)
    assert_equal(Toys::Release::Semver::PATCH, fix_tag_settings.semver)
    docs_tag_settings = toys_core_settings.commit_tag_named("docs")
    assert_equal("docs", docs_tag_settings.tag)
    assert_equal("DOCS", docs_tag_settings.header)
    assert_equal(Toys::Release::Semver::PATCH, docs_tag_settings.semver)
    chore_tag_settings = toys_core_settings.commit_tag_named("chore")
    assert_equal("chore", chore_tag_settings.tag)
    assert_equal(:hidden, chore_tag_settings.header)
    assert_equal(Toys::Release::Semver::NONE, chore_tag_settings.semver)

    toys_settings = settings.component_settings("toys")
    assert_equal("toys", toys_settings.name)
    assert_equal("toys", toys_settings.directory)
    assert_equal("CHANGELOG.md", toys_settings.changelog_path)
    assert_equal("gems/toys", toys_settings.gh_pages_directory)
    assert_equal("version", toys_settings.gh_pages_version_var)
    assert(toys_settings.gh_pages_enabled)
    assert_equal("lib/toys/version.rb", toys_settings.version_rb_path)
    assert_equal(["copy-core-docs"], toys_settings.step_named("copy_core_docs").options["tool"])
    assert_equal(1, toys_settings.step_named("build_yard").inputs.size)
    assert_equal("copy_core_docs", toys_settings.step_named("build_yard").inputs.first.step_name)
    assert_equal(1, toys_settings.step_named("copy_core_docs").outputs.size)
    assert_equal("core-docs", toys_settings.step_named("copy_core_docs").outputs.first.source_path)
    assert_equal(:delete, toys_settings.issue_number_suffix_handling)
    assert_equal("BREAKING CHANGE", toys_settings.breaking_change_header)
    assert_equal("No significant updates.", toys_settings.no_significant_updates_notice)

    toys_release_settings = settings.component_settings("toys-release")
    assert_equal("toys-release", toys_release_settings.name)
    assert_equal("toys-release", toys_release_settings.directory)
    assert_equal("CHANGELOG.md", toys_release_settings.changelog_path)
    assert_equal("gems/toys-release", toys_release_settings.gh_pages_directory)
    assert_equal("version_toys_release", toys_release_settings.gh_pages_version_var)
    assert(toys_release_settings.gh_pages_enabled)
    assert_equal("lib/toys/release/version.rb", toys_release_settings.version_rb_path)
    assert_nil(toys_release_settings.step_named("copy_core_docs"))
    assert_empty(toys_release_settings.step_named("build_yard").inputs)
    assert_equal(:delete, toys_release_settings.issue_number_suffix_handling)
    assert_equal("BREAKING CHANGE", toys_release_settings.breaking_change_header)
    assert_equal("No significant updates.", toys_release_settings.no_significant_updates_notice)

    common_tools_settings = settings.component_settings("common-tools")
    assert_equal("common-tools", common_tools_settings.name)
    assert_equal("common-tools", common_tools_settings.directory)
    assert_equal("CHANGELOG.md", common_tools_settings.changelog_path)
    assert_equal(".lib/version.rb", common_tools_settings.version_rb_path)
    assert_nil(common_tools_settings.step_named("build_yard"))
    refute(common_tools_settings.gh_pages_enabled)
  end

  it "detects unknown top level keys" do
    input = YAML.load(<<~STRING)
      repository: dazuma/toys
    STRING
    settings = Toys::Release::RepoSettings.new(input)
    assert_includes(settings.errors, 'Unknown top level key "repository" in releases.yml')
  end

  it "enforces required top level keys" do
    input = YAML.load(<<~STRING)
      repository: dazuma/toys
    STRING
    settings = Toys::Release::RepoSettings.new(input)
    assert_includes(settings.errors, 'Required key "repo" missing from releases.yml')
    assert_includes(settings.errors, 'Required key "git_user_name" missing from releases.yml')
    assert_includes(settings.errors, 'Required key "git_user_email" missing from releases.yml')
  end

  describe "with custom steps" do
    it "replaces steps completely" do
      input = YAML.load(<<~STRING)
        steps:
          - name: bundle
          - name: build_yard
        components:
          - name: foo
      STRING
      settings = Toys::Release::RepoSettings.new(input)
      foo_component = settings.component_settings("foo")
      assert_equal(["bundle", "build_yard"], foo_component.steps.map(&:name))
    end

    it "prepends steps" do
      input = YAML.load(<<~STRING)
        prepend_steps:
          - name: step1
            type: command
            command: ["echo", "hello"]
        components:
          - name: foo
      STRING
      settings = Toys::Release::RepoSettings.new(input)
      foo_component = settings.component_settings("foo")
      assert_equal("step1", foo_component.steps[0].name)
      assert_equal("bundle", foo_component.steps[1].name)
    end

    it "prepends steps before a named step" do
      input = YAML.load(<<~STRING)
        prepend_steps:
          before: build_gem
          steps:
            - name: step1
              type: command
              command: ["echo", "hello"]
        components:
          - name: foo
      STRING
      settings = Toys::Release::RepoSettings.new(input)
      foo_component = settings.component_settings("foo")
      assert_equal("bundle", foo_component.steps[0].name)
      assert_equal("step1", foo_component.steps[1].name)
    end

    it "appends steps" do
      input = YAML.load(<<~STRING)
        append_steps:
          - name: step1
            type: command
            command: ["echo", "hello"]
        components:
          - name: foo
      STRING
      settings = Toys::Release::RepoSettings.new(input)
      foo_component = settings.component_settings("foo")
      steps = foo_component.steps
      assert_equal("step1", steps[-1].name)
      assert_equal("push_gh_pages", steps[-2].name)
    end

    it "appends steps before a named step" do
      input = YAML.load(<<~STRING)
        append_steps:
          after: release_gem
          steps:
            - name: step1
              type: command
              command: ["echo", "hello"]
        components:
          - name: foo
      STRING
      settings = Toys::Release::RepoSettings.new(input)
      foo_component = settings.component_settings("foo")
      steps = foo_component.steps
      assert_equal("push_gh_pages", steps[-1].name)
      assert_equal("step1", steps[-2].name)
    end

    it "flags missing input step name" do
      input = YAML.load(<<~STRING)
        steps:
          - name: bundle
          - name: build_yard
            inputs:
              - source_path: Gemfile.lock
      STRING
      settings = Toys::Release::RepoSettings.new(input)
      assert_includes(settings.errors, 'Missing required key "name" in input for step "build_yard"')
    end

    it "flags unknown keys in input" do
      input = YAML.load(<<~STRING)
        steps:
          - name: bundle
          - name: build_yard
            inputs:
              - name: bundle
                foo: bar
      STRING
      settings = Toys::Release::RepoSettings.new(input)
      assert_includes(settings.errors, 'Unknown key "foo" in input for step "build_yard"')
    end

    it "flags unknown keys in output" do
      input = YAML.load(<<~STRING)
        steps:
          - name: bundle
          - name: build_yard
            outputs:
              - foo: bar
      STRING
      settings = Toys::Release::RepoSettings.new(input)
      assert_includes(settings.errors, 'Unknown key "foo" in output for step "build_yard"')
    end
  end

  describe "with custom commit tags" do
    it "loads a hidden header" do
      input = YAML.load(<<~STRING)
        commit_tags:
          - tag: internal
            header: null
      STRING
      settings = Toys::Release::RepoSettings.new(input)
      tag_settings = settings.commit_tags.find { |tag| tag.tag == "internal" }
      assert_equal("internal", tag_settings.tag)
      assert_equal(:hidden, tag_settings.header)
      assert_equal(Toys::Release::Semver::NONE, tag_settings.semver)
    end

    it "loads a scope" do
      input = YAML.load(<<~STRING)
        commit_tags:
          - tag: chore
            header: null
            scopes:
              - scope: deps
                header: DEPENDENCIES
                semver: patch
      STRING
      settings = Toys::Release::RepoSettings.new(input)
      tag_settings = settings.commit_tags.find { |tag| tag.tag == "chore" }
      assert_equal("chore", tag_settings.tag)
      assert_equal(:hidden, tag_settings.header)
      assert_equal(Toys::Release::Semver::NONE, tag_settings.semver)
      assert_equal(:hidden, tag_settings.header("foo"))
      assert_equal(Toys::Release::Semver::NONE, tag_settings.semver("foo"))
      assert_equal("DEPENDENCIES", tag_settings.header("deps"))
      assert_equal(Toys::Release::Semver::PATCH, tag_settings.semver("deps"))
    end

    it "flags unknown keys" do
      input = YAML.load(<<~STRING)
        commit_tags:
          - tag: chore
            header: null
            foo: hello
            scopes:
              - scope: deps
                header: DEPENDENCIES
                semver: patch
                bar: hello
      STRING
      settings = Toys::Release::RepoSettings.new(input)
      assert_includes(settings.errors, 'Unknown key "foo" in configuration of tag "chore"')
      assert_includes(settings.errors, 'Unknown key "bar" in configuration of tag "chore(deps)"')
    end

    it "flags missing tag key" do
      input = YAML.load(<<~STRING)
        commit_tags:
          - semver: minor
      STRING
      settings = Toys::Release::RepoSettings.new(input)
      assert(settings.errors.any? { |err| err.include?("Commit tag missing") })
    end

    it "flags missing scope key" do
      input = YAML.load(<<~STRING)
        commit_tags:
          - tag: chore
            scopes:
              - semver: minor
      STRING
      settings = Toys::Release::RepoSettings.new(input)
      assert(settings.errors.any? { |err| err.include?('Commit tag scope missing under tag "chore"') })
    end
  end

  describe "component settings" do
    it "inherits and overrides update_dependency_header" do
      input = YAML.load(<<~STRING)
        components:
          - name: foo
            update_dependency_header: DEPS
          - name: bar
      STRING
      settings = Toys::Release::RepoSettings.new(input)

      foo_component = settings.component_settings("foo")
      assert_equal("DEPS", foo_component.update_dependency_header)

      bar_component = settings.component_settings("bar")
      assert_equal("DEPENDENCY", bar_component.update_dependency_header)
    end

    it "inherits and overrides breaking_change_header" do
      input = YAML.load(<<~STRING)
        components:
          - name: foo
            breaking_change_header: BREAK
          - name: bar
      STRING
      settings = Toys::Release::RepoSettings.new(input)

      foo_component = settings.component_settings("foo")
      assert_equal("BREAK", foo_component.breaking_change_header)

      bar_component = settings.component_settings("bar")
      assert_equal("BREAKING CHANGE", bar_component.breaking_change_header)
    end

    it "overrides commit tags" do
      input = YAML.load(<<~STRING)
        components:
          - name: foo
            commit_tags:
              - tag: feat
                header: FEATURE
                semver: minor
              - tag: fix
                semver: patch
          - name: bar
      STRING
      settings = Toys::Release::RepoSettings.new(input)
      assert_equal(["foo", "bar"], settings.all_component_names)

      foo_component = settings.component_settings("foo")
      foo_feat_tag = foo_component.commit_tag_named("feat")
      assert_equal("FEATURE", foo_feat_tag.header)
      foo_docs_tag = foo_component.commit_tag_named("docs")
      assert_equal(:hidden, foo_docs_tag.header)

      bar_component = settings.component_settings("bar")
      bar_feat_tag = bar_component.commit_tag_named("feat")
      assert_equal("ADDED", bar_feat_tag.header)
      bar_docs_tag = bar_component.commit_tag_named("docs")
      assert_equal("DOCS", bar_docs_tag.header)
    end

    it "overrides steps" do
      input = YAML.load(<<~STRING)
        components:
          - name: foo
            steps:
              - name: bundle
              - name: build_yard
          - name: bar
      STRING
      settings = Toys::Release::RepoSettings.new(input)
      assert_equal(["foo", "bar"], settings.all_component_names)

      foo_component = settings.component_settings("foo")
      assert_equal(["bundle", "build_yard"], foo_component.steps.map(&:name))

      bar_component = settings.component_settings("bar")
      assert_includes(bar_component.steps.map(&:name), "build_gem")
    end
  end

  describe "with update_dependencies" do
    it "defaults to no updates" do
      input = YAML.load(<<~STRING)
        components:
          - name: comp_a
      STRING
      settings = Toys::Release::RepoSettings.new(input)
      component = settings.component_settings("comp_a")
      assert_nil(component.update_dependencies)
    end

    it "uses the default levels" do
      input = YAML.load(<<~STRING)
        components:
          - name: comp_a
          - name: comp_b
          - name: comp_all
            update_dependencies:
              dependencies: [comp_a, comp_b]
      STRING
      settings = Toys::Release::RepoSettings.new(input)
      component = settings.component_settings("comp_all")
      update_settings = component.update_dependencies
      assert_equal(["comp_a", "comp_b"], update_settings.dependencies)
      assert_equal(Toys::Release::Semver::MINOR, update_settings.dependency_semver_threshold)
      assert_equal(Toys::Release::Semver::MINOR, update_settings.pessimistic_constraint_level)
    end

    it "sets custom levels" do
      input = YAML.load(<<~STRING)
        components:
          - name: comp_a
          - name: comp_b
          - name: comp_all
            update_dependencies:
              dependencies: [comp_a, comp_b]
              dependency_semver_threshold: patch
              pessimistic_constraint_level: patch
      STRING
      settings = Toys::Release::RepoSettings.new(input)
      component = settings.component_settings("comp_all")
      update_settings = component.update_dependencies
      assert_equal(Toys::Release::Semver::PATCH, update_settings.dependency_semver_threshold)
      assert_equal(Toys::Release::Semver::PATCH, update_settings.pessimistic_constraint_level)
    end

    it "recognizes all and exact" do
      input = YAML.load(<<~STRING)
        components:
          - name: comp_a
          - name: comp_b
          - name: comp_all
            update_dependencies:
              dependencies: [comp_a, comp_b]
              dependency_semver_threshold: all
              pessimistic_constraint_level: exact
      STRING
      settings = Toys::Release::RepoSettings.new(input)
      component = settings.component_settings("comp_all")
      update_settings = component.update_dependencies
      assert_equal(Toys::Release::Semver::NONE, update_settings.dependency_semver_threshold)
      assert_equal(Toys::Release::Semver::NONE, update_settings.pessimistic_constraint_level)
    end

    it "errors if the dependencies key is absent" do
      input = YAML.load(<<~STRING)
        components:
          - name: comp_a
          - name: comp_b
          - name: comp_all
            update_dependencies:
              dependency_semver_threshold: all
      STRING
      settings = Toys::Release::RepoSettings.new(input)
      expected_error = "update_dependencies is missing required key \"dependencies\""
      assert(settings.errors.any? { |err| err.include?(expected_error) })
    end

    it "errors if a component with update_dependencies is in a coordination group" do
      input = YAML.load(<<~STRING)
        components:
          - name: comp_a
          - name: comp_b
          - name: comp_all
            update_dependencies:
              dependencies: [comp_a, comp_b]
        coordination_groups:
          - [comp_all, comp_a]
      STRING
      settings = Toys::Release::RepoSettings.new(input)
      expected_error = "Component comp_all cannot be in a coordination group and have update_dependencies"
      assert(settings.errors.any? { |err| err.include?(expected_error) })
    end

    it "errors if a dependency does not exist" do
      input = YAML.load(<<~STRING)
        components:
          - name: comp_a
          - name: comp_b
          - name: comp_all
            update_dependencies:
              dependencies: [comp_a, comp_c]
      STRING
      settings = Toys::Release::RepoSettings.new(input)
      expected_error = "Component comp_all depends on nonexistent component comp_c"
      assert(settings.errors.any? { |err| err.include?(expected_error) })
    end

    it "errors if a component depends on itself" do
      input = YAML.load(<<~STRING)
        components:
          - name: comp_a
          - name: comp_b
          - name: comp_all
            update_dependencies:
              dependencies: [comp_a, comp_all]
      STRING
      settings = Toys::Release::RepoSettings.new(input)
      expected_error = "Component comp_all depends on itself"
      assert(settings.errors.any? { |err| err.include?(expected_error) })
    end

    it "errors if there are transitive dependencies" do
      input = YAML.load(<<~STRING)
        components:
          - name: comp_a
          - name: comp_b
            update_dependencies:
              dependencies: [comp_a]
          - name: comp_c
            update_dependencies:
              dependencies: [comp_b]
      STRING
      settings = Toys::Release::RepoSettings.new(input)
      expected_error = "Component comp_c depends on comp_b which also has dependencies"
      assert(settings.errors.any? { |err| err.include?(expected_error) })
    end
  end

  describe "top level settings" do
    it "sets global update_dependency_header" do
      input = YAML.load(<<~STRING)
        update_dependency_header: DEPS
      STRING
      settings = Toys::Release::RepoSettings.new(input)

      assert_equal("DEPS", settings.update_dependency_header)
    end

    it "sets global breaking_change_header" do
      input = YAML.load(<<~STRING)
        breaking_change_header: BREAK
      STRING
      settings = Toys::Release::RepoSettings.new(input)

      assert_equal("BREAK", settings.breaking_change_header)
    end

    it "accepts a dash changelog_bullet" do
      input = YAML.load(<<~STRING)
        changelog_bullet: "-"
      STRING
      settings = Toys::Release::RepoSettings.new(input)
      assert_equal("-", settings.changelog_bullet)
      refute(settings.errors.any? { |err| err.include?("changelog_bullet") })
    end

    it "rejects an invalid changelog_bullet" do
      input = YAML.load(<<~STRING)
        changelog_bullet: "+"
      STRING
      settings = Toys::Release::RepoSettings.new(input)
      assert_equal("*", settings.changelog_bullet)
      assert(settings.errors.any? { |err| err.include?("changelog_bullet") })
    end
  end
end
