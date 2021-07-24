# frozen_string_literal: true

require "helper"

describe "rubocop template" do
  let(:template_lookup) { Toys::ModuleLookup.new.add_path("toys/templates") }

  describe "unit functionality" do
    let(:template_class) { template_lookup.lookup(:rubocop) }
    let(:template) { template_class.new }

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

    it "handles the fail_on_error field" do
      assert_equal(true, template.fail_on_error)
      template.fail_on_error = false
      assert_equal(false, template.fail_on_error)
    end

    it "handles the options field" do
      assert_equal([], template.options)
      template.options = "-v"
      assert_equal(["-v"], template.options)
      template.options = ["-v", "--help"]
      assert_equal(["-v", "--help"], template.options)
      template.options = nil
      assert_equal([], template.options)
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

    it "handles the context_directory field" do
      assert_nil(template.context_directory)
      template.context_directory = "/path/to/somewhere"
      assert_equal("/path/to/somewhere", template.context_directory)
      template.context_directory = nil
      assert_nil(template.context_directory)
    end

    it "honors constructor args" do
      template = template_class.new name: "hi",
                                    gem_version: "~> 3.2",
                                    fail_on_error: false,
                                    options: "-v",
                                    context_directory: "/path/to/context"
      assert_equal("hi", template.name)
      assert_equal(["~> 3.2"], template.gem_version)
      assert_equal(false, template.fail_on_error)
      assert_equal(["-v"], template.options)
      assert_equal("/path/to/context", template.context_directory)
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

    it "honors context_directory setting" do
      dir = File.join(__dir__, "rubocop-cases", "passing")
      loader.add_block do
        expand :rubocop, options: ["--config", "config.yml"], context_directory: dir
      end
      out, _err = capture_subprocess_io do
        assert_equal(0, cli.run("rubocop"))
      end
      assert_match(/no offenses/, out)
    end
  end
end
