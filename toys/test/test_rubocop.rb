# frozen_string_literal: true

require "helper"

describe "rubocop template" do
  let(:template_lookup) { Toys::ModuleLookup.new.add_path("toys/templates") }

  describe "unit functionality" do
    let(:template) { template_lookup.lookup(:rubocop).new }

    it "handles the name field" do
      assert_equal("rubocop", template.name)
      template.name = "hi"
      assert_equal("hi", template.name)
      template.name = nil
      assert_equal("rubocop", template.name)
    end

    it "handles the gem_version field without bundler" do
      assert_equal([], template.gem_version)
      template.gem_version = "~> 6.2"
      assert_equal(["~> 6.2"], template.gem_version)
      template.gem_version = ["~> 6.0", "< 6.2"]
      assert_equal(["~> 6.0", "< 6.2"], template.gem_version)
      template.gem_version = nil
      assert_equal([], template.gem_version)
    end

    it "handles the gem_version field with bundler" do
      template.use_bundler
      assert_equal([], template.gem_version)
      template.gem_version = "~> 6.2"
      assert_equal(["~> 6.2"], template.gem_version)
      template.gem_version = ["~> 6.0", "< 6.2"]
      assert_equal(["~> 6.0", "< 6.2"], template.gem_version)
      template.gem_version = nil
      assert_equal([], template.gem_version)
    end

    it "handles the bundler_settings field via the bundler writer" do
      assert_equal(false, template.bundler_settings)
      template.bundler = true
      assert_equal({}, template.bundler_settings)
      template.bundler = {groups: ["production"]}
      assert_equal({groups: ["production"]}, template.bundler_settings)
      template.bundler = false
      assert_equal(false, template.bundler_settings)
    end

    it "handles the bundler_settings field via use_bundler" do
      assert_equal(false, template.bundler_settings)
      template.use_bundler
      assert_equal({}, template.bundler_settings)
      template.use_bundler(groups: ["production"])
      assert_equal({groups: ["production"]}, template.bundler_settings)
    end
  end

  describe "integration functionality" do
    let(:cli) { Toys::CLI.new(middleware_stack: [], template_lookup: template_lookup) }
    let(:loader) { cli.loader }

    it "runs passing tests" do
      loader.add_block do
        set_context_directory File.join(__dir__, "rubocop-cases", "passing")
        expand :rubocop, options: ["--config", "config.yml"]
      end
      out, _err = capture_subprocess_io do
        assert_equal(0, cli.run("rubocop"))
      end
      assert_match(/no offenses/, out)
    end

    it "runs failing tests" do
      loader.add_block do
        set_context_directory File.join(__dir__, "rubocop-cases", "failing")
        expand :rubocop, options: ["--config", "config.yml"]
      end
      out, _err = capture_subprocess_io do
        assert_equal(1, cli.run("rubocop"))
      end
      refute_match(/no offenses/, out)
    end
  end
end
