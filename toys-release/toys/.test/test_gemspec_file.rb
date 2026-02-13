# frozen_string_literal: true

require_relative "helper"

describe Toys::Release::GemspecFile do
  let(:fake_tool_context) { Toys::Release::Tests::FakeToolContext.new(allow_passthru_exec: true) }
  let(:environment_utils) { Toys::Release::EnvironmentUtils.new(fake_tool_context) }
  let(:release_gemspec_path) { File.join(File.dirname(File.dirname(__dir__)), "toys-release.gemspec") }
  let(:release_gemspec_file) { Toys::Release::GemspecFile.new(release_gemspec_path, environment_utils) }
  let(:empty_gemspec_file) { Toys::Release::GemspecFile.new(nil, environment_utils) }

  describe ".transform_version_constraints" do
    let(:standard_input) do
      {
        "a" => Gem::Version.new("1"),
        "b" => Gem::Version.new("1.2"),
        "c" => Gem::Version.new("1.2.3"),
        "d" => Gem::Version.new("1.2.3.4"),
      }
    end

    it "handles both thresholds at minor" do
      expected_result = {
        "a" => ["~> 1.0"],
        "b" => ["~> 1.2"],
        "c" => ["~> 1.2"],
        "d" => ["~> 1.2"],
      }
      result = Toys::Release::GemspecFile.transform_version_constraints(
        standard_input, Toys::Release::Semver::MINOR, Toys::Release::Semver::MINOR
      )
      assert_equal(expected_result, result)
    end

    it "handles update significance threshold higher than pessimistic constraint" do
      expected_result = {
        "a" => ["~> 1.0"],
        "b" => ["~> 1.2"],
        "c" => ["~> 1.2", ">= 1.2.3"],
        "d" => ["~> 1.2", ">= 1.2.3"],
      }
      result = Toys::Release::GemspecFile.transform_version_constraints(
        standard_input, Toys::Release::Semver::PATCH, Toys::Release::Semver::MINOR
      )
      assert_equal(expected_result, result)
    end

    it "handles update significance threshold lower than pessimistic constraint" do
      expected_result = {
        "a" => ["~> 1.0.0"],
        "b" => ["~> 1.2.0"],
        "c" => ["~> 1.2.0"],
        "d" => ["~> 1.2.0"],
      }
      result = Toys::Release::GemspecFile.transform_version_constraints(
        standard_input, Toys::Release::Semver::MINOR, Toys::Release::Semver::PATCH
      )
      assert_equal(expected_result, result)
    end

    it "handles update significance threshold at all" do
      expected_result = {
        "a" => ["~> 1.0"],
        "b" => ["~> 1.2"],
        "c" => ["~> 1.2", ">= 1.2.3"],
        "d" => ["~> 1.2", ">= 1.2.3.4"],
      }
      result = Toys::Release::GemspecFile.transform_version_constraints(
        standard_input, Toys::Release::Semver::NONE, Toys::Release::Semver::MINOR
      )
      assert_equal(expected_result, result)
    end

    it "handles pessimistic constraint at exact" do
      expected_result = {
        "a" => ["= 1"],
        "b" => ["= 1.2"],
        "c" => ["= 1.2.3"],
        "d" => ["= 1.2.3.4"],
      }
      result = Toys::Release::GemspecFile.transform_version_constraints(
        standard_input, Toys::Release::Semver::MINOR, Toys::Release::Semver::NONE
      )
      assert_equal(expected_result, result)
    end
  end

  describe "#current_dependencies" do
    let(:expected_constraints) do
      {
        "one-dependency" => ["~> 1.0"],
        "another-dep" => [">= 2.1", "< 4"],
        "no-versions" => [],
      }
    end

    it "returns an empty hash when nothing found" do
      empty_gemspec_file.content = "# Hello\n# World\n"
      assert_empty(empty_gemspec_file.current_dependencies)
    end

    it "finds add_dependency without parens" do
      empty_gemspec_file.content = <<~STR
        Gem::Specification.new do |spec|
          spec.name = "my_gem"
          spec.add_dependency "one-dependency", "~> 1.0"
          spec.version = "0.1"
          spec.add_dependency "another-dep", ">= 2.1", "< 4"
          spec.add_dependency "no-versions"
        end
      STR
      assert_equal(expected_constraints, empty_gemspec_file.current_dependencies)
    end

    it "finds add_dependency with parens" do
      empty_gemspec_file.content = <<~STR
        Gem::Specification.new do |spec|
          spec.name = "my_gem"
          spec.add_dependency("one-dependency", "~> 1.0")
          spec.version = "0.1"
          spec.add_dependency("another-dep", ">= 2.1", "< 4")
          spec.add_dependency("no-versions")
        end
      STR
      assert_equal(expected_constraints, empty_gemspec_file.current_dependencies)
    end

    it "finds add_dependency with single quotes" do
      empty_gemspec_file.content = <<~STR
        Gem::Specification.new do |spec|
          spec.name = 'my_gem'
          spec.add_dependency 'one-dependency', '~> 1.0'
          spec.version = '0.1'
          spec.add_dependency 'another-dep', '>= 2.1', '< 4'
          spec.add_dependency 'no-versions'
        end
      STR
      assert_equal(expected_constraints, empty_gemspec_file.current_dependencies)
    end
  end

  describe "#update_dependencies" do
    let(:double_quoted_content) do
      <<~STR
        Gem::Specification.new do |spec|
          spec.name = "my_gem"
          spec.add_dependency "one-dependency", "~> 1.0"
          spec.version = "0.1"
          spec.add_dependency "another-dep", ">= 2.1", "< 4"
          spec.add_dependency "no-versions"
        end
      STR
    end
    let(:single_quoted_content) { double_quoted_content.tr('"', "'") }
    let(:parenthesized_double_quoted_content) do
      <<~STR
        Gem::Specification.new do |spec|
          spec.name = "my_gem"
          spec.add_dependency("one-dependency", "~> 1.0")
          spec.version = "0.1"
          spec.add_dependency("another-dep", ">= 2.1", "< 4")
          spec.add_dependency("no-versions")
        end
      STR
    end
    let(:parenthesized_single_quoted_content) { parenthesized_double_quoted_content.tr('"', "'") }

    it "handles an empty update" do
      empty_gemspec_file.content = double_quoted_content.dup
      assert(empty_gemspec_file.update_dependencies({}))
      assert_equal(double_quoted_content, empty_gemspec_file.content)
    end

    it "updates one item and leaves others alone" do
      empty_gemspec_file.content = double_quoted_content.dup
      updates = {"one-dependency" => ["~> 1.1"]}
      assert(empty_gemspec_file.update_dependencies(updates))
      expected_content = <<~STR
        Gem::Specification.new do |spec|
          spec.name = "my_gem"
          spec.add_dependency "one-dependency", "~> 1.1"
          spec.version = "0.1"
          spec.add_dependency "another-dep", ">= 2.1", "< 4"
          spec.add_dependency "no-versions"
        end
      STR
      assert_equal(expected_content, empty_gemspec_file.content)
    end

    it "notes inability to find an item" do
      skip
      empty_gemspec_file.content = double_quoted_content.dup
      updates = {
        "one-dependency" => [">= 1.1.3", "< 2"],
        "not-found" => ["~> 2.2"],
      }
      refute(empty_gemspec_file.update_dependencies(updates))
      expected_content = <<~STR
        Gem::Specification.new do |spec|
          spec.name = "my_gem"
          spec.add_dependency "one-dependency", ">= 1.1.3", "< 2"
          spec.version = "0.1"
          spec.add_dependency "another-dep", ">= 2.1", "< 4"
          spec.add_dependency "no-versions"
        end
      STR
      assert_equal(expected_content, empty_gemspec_file.content)
    end

    it "handles double quoted content" do
      empty_gemspec_file.content = double_quoted_content.dup
      updates = {
        "one-dependency" => [">= 1.1.3", "< 2"],
        "another-dep" => [],
        "no-versions" => ["~> 2.2"],
      }
      assert(empty_gemspec_file.update_dependencies(updates))
      expected_content = <<~STR
        Gem::Specification.new do |spec|
          spec.name = "my_gem"
          spec.add_dependency "one-dependency", ">= 1.1.3", "< 2"
          spec.version = "0.1"
          spec.add_dependency "another-dep"
          spec.add_dependency "no-versions", "~> 2.2"
        end
      STR
      assert_equal(expected_content, empty_gemspec_file.content)
    end

    it "handles single quoted content" do
      empty_gemspec_file.content = single_quoted_content.dup
      updates = {
        "one-dependency" => [">= 1.1.3", "< 2"],
        "another-dep" => [],
        "no-versions" => ["~> 2.2"],
      }
      assert(empty_gemspec_file.update_dependencies(updates))
      expected_content = <<~STR
        Gem::Specification.new do |spec|
          spec.name = 'my_gem'
          spec.add_dependency 'one-dependency', '>= 1.1.3', '< 2'
          spec.version = '0.1'
          spec.add_dependency 'another-dep'
          spec.add_dependency 'no-versions', '~> 2.2'
        end
      STR
      assert_equal(expected_content, empty_gemspec_file.content)
    end

    it "handles parenthesized double quoted content" do
      empty_gemspec_file.content = parenthesized_double_quoted_content.dup
      updates = {
        "one-dependency" => [">= 1.1.3", "< 2"],
        "another-dep" => [],
        "no-versions" => ["~> 2.2"],
      }
      assert(empty_gemspec_file.update_dependencies(updates))
      expected_content = <<~STR
        Gem::Specification.new do |spec|
          spec.name = "my_gem"
          spec.add_dependency("one-dependency", ">= 1.1.3", "< 2")
          spec.version = "0.1"
          spec.add_dependency("another-dep")
          spec.add_dependency("no-versions", "~> 2.2")
        end
      STR
      assert_equal(expected_content, empty_gemspec_file.content)
    end

    it "handles parenthesized single quoted content" do
      empty_gemspec_file.content = parenthesized_single_quoted_content.dup
      updates = {
        "one-dependency" => [">= 1.1.3", "< 2"],
        "another-dep" => [],
        "no-versions" => ["~> 2.2"],
      }
      assert(empty_gemspec_file.update_dependencies(updates))
      expected_content = <<~STR
        Gem::Specification.new do |spec|
          spec.name = 'my_gem'
          spec.add_dependency('one-dependency', '>= 1.1.3', '< 2')
          spec.version = '0.1'
          spec.add_dependency('another-dep')
          spec.add_dependency('no-versions', '~> 2.2')
        end
      STR
      assert_equal(expected_content, empty_gemspec_file.content)
    end
  end
end
