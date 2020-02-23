# frozen_string_literal: true

require "helper"

describe "yardoc template" do
  let(:template_lookup) { Toys::ModuleLookup.new.add_path("toys/templates") }

  describe "unit functionality" do
    let(:template) { template_lookup.lookup(:yardoc).new }

    it "handles the name field" do
      assert_equal("yardoc", template.name)
      template.name = "hi"
      assert_equal("hi", template.name)
      template.name = nil
      assert_equal("yardoc", template.name)
    end

    it "handles the files field" do
      assert_equal(["lib/**/*.rb"], template.files)
      template.files = "src/**/*.rb"
      assert_equal(["src/**/*.rb"], template.files)
      template.files = ["lib/**/*.rb", "src/**/*.rb"]
      assert_equal(["lib/**/*.rb", "src/**/*.rb"], template.files)
      template.files = nil
      assert_equal(["lib/**/*.rb"], template.files)
    end

    it "handles the gem_version field without bundler" do
      assert_equal(["~> 0.9"], template.gem_version)
      template.gem_version = "~> 6.2"
      assert_equal(["~> 6.2"], template.gem_version)
      template.gem_version = ["~> 6.0", "< 6.2"]
      assert_equal(["~> 6.0", "< 6.2"], template.gem_version)
      template.gem_version = nil
      assert_equal(["~> 0.9"], template.gem_version)
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

    it "handles the output_dir field" do
      assert_equal("doc", template.output_dir)
      template.output_dir = "hi"
      assert_equal("hi", template.output_dir)
      template.output_dir = nil
      assert_equal("doc", template.output_dir)
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

    it "runs yardoc" do
      input_dir = File.join(__dir__, "doc-case")
      output_dir = File.join(File.dirname(__dir__), "tmp")
      FileUtils.rm_rf(output_dir)
      loader.add_block do
        set_context_directory input_dir
        expand :yardoc, output_dir: output_dir
      end
      capture_subprocess_io do
        assert_equal(0, cli.run("yardoc"))
      end
      assert_path_exists(File.join(output_dir, "index.html"))
    end
  end
end
