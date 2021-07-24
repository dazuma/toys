# frozen_string_literal: true

require "helper"

describe "yardoc template" do
  let(:template_lookup) { Toys::ModuleLookup.new.add_path("toys/templates") }

  describe "unit functionality" do
    let(:template_class) { template_lookup.lookup(:yardoc) }
    let(:template) { template_class.new }

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

    it "handles the generate_output field" do
      assert_equal(true, template.generate_output)
      template.generate_output = false
      assert_equal(false, template.generate_output)
    end

    it "handles the generate_output_flag field" do
      assert_equal(false, template.generate_output_flag)
      template.generate_output_flag = true
      assert_equal(true, template.generate_output_flag)
    end

    it "handles the output_dir field" do
      assert_equal("doc", template.output_dir)
      template.output_dir = "hi"
      assert_equal("hi", template.output_dir)
      template.output_dir = nil
      assert_equal("doc", template.output_dir)
    end

    it "handles the fail_on_warning field" do
      assert_equal(false, template.fail_on_warning)
      template.fail_on_warning = true
      assert_equal(true, template.fail_on_warning)
    end

    it "handles the fail_on_undocumented_objects field" do
      assert_equal(false, template.fail_on_undocumented_objects)
      template.fail_on_undocumented_objects = true
      assert_equal(true, template.fail_on_undocumented_objects)
    end

    it "handles the show_public field" do
      assert_equal(true, template.show_public)
      template.show_public = false
      assert_equal(false, template.show_public)
    end

    it "handles the show_protected field" do
      assert_equal(false, template.show_protected)
      template.show_protected = true
      assert_equal(true, template.show_protected)
    end

    it "handles the show_private field" do
      assert_equal(false, template.show_private)
      template.show_private = true
      assert_equal(true, template.show_private)
    end

    it "handles the hide_private_tag field" do
      assert_equal(false, template.hide_private_tag)
      template.hide_private_tag = true
      assert_equal(true, template.hide_private_tag)
    end

    it "handles the readme field" do
      assert_nil(template.readme)
      template.readme = "README.md"
      assert_equal("README.md", template.readme)
      template.readme = nil
      assert_nil(template.readme)
    end

    it "handles the markup field" do
      assert_nil(template.markup)
      template.markup = "markdown"
      assert_equal("markdown", template.markup)
      template.markup = nil
      assert_nil(template.markup)
    end

    it "handles the template field" do
      assert_nil(template.template)
      template.template = "mytmpl"
      assert_equal("mytmpl", template.template)
      template.template = nil
      assert_nil(template.template)
    end

    it "handles the template_path field" do
      assert_nil(template.template_path)
      template.template_path = "templates"
      assert_equal("templates", template.template_path)
      template.template_path = nil
      assert_nil(template.template_path)
    end

    it "handles the format field" do
      assert_nil(template.format)
      template.format = "html"
      assert_equal("html", template.format)
      template.format = nil
      assert_nil(template.format)
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

    it "handles the stats_options field" do
      assert_equal([], template.stats_options)
      template.stats_options = "-v"
      assert_equal(["-v"], template.stats_options)
      template.stats_options = ["-v", "--help"]
      assert_equal(["-v", "--help"], template.stats_options)
      template.stats_options = nil
      assert_equal([], template.stats_options)
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
                                    gem_version: "~> 6.2",
                                    files: "src/**/*.rb",
                                    generate_output: false,
                                    generate_output_flag: true,
                                    output_dir: "my_docs",
                                    fail_on_warning: true,
                                    fail_on_undocumented_objects: true,
                                    show_public: false,
                                    show_protected: true,
                                    show_private: true,
                                    hide_private_tag: true,
                                    readme: "README.md",
                                    markup: "markdown",
                                    template: "mytmpl",
                                    template_path: "templates",
                                    format: "html",
                                    options: "-v",
                                    stats_options: "--help",
                                    context_directory: "/path/to/context"
      assert_equal("hi", template.name)
      assert_equal(["~> 6.2"], template.gem_version)
      assert_equal(["src/**/*.rb"], template.files)
      assert_equal(false, template.generate_output)
      assert_equal(true, template.generate_output_flag)
      assert_equal("my_docs", template.output_dir)
      assert_equal(true, template.fail_on_warning)
      assert_equal(true, template.fail_on_undocumented_objects)
      assert_equal(false, template.show_public)
      assert_equal(true, template.show_protected)
      assert_equal(true, template.show_private)
      assert_equal(true, template.hide_private_tag)
      assert_equal("README.md", template.readme)
      assert_equal("markdown", template.markup)
      assert_equal("mytmpl", template.template)
      assert_equal("templates", template.template_path)
      assert_equal("html", template.format)
      assert_equal(["-v"], template.options)
      assert_equal(["--help"], template.stats_options)
      assert_equal("/path/to/context", template.context_directory)
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

    it "honors context_directory setting" do
      input_dir = File.join(__dir__, "doc-case")
      output_dir = File.join(File.dirname(__dir__), "tmp")
      FileUtils.rm_rf(output_dir)
      loader.add_block do
        expand :yardoc, output_dir: output_dir, context_directory: input_dir
      end
      capture_subprocess_io do
        assert_equal(0, cli.run("yardoc"))
      end
      assert_path_exists(File.join(output_dir, "index.html"))
    end
  end
end
