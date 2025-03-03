# frozen_string_literal: true

require "helper"

describe "rdoc template" do
  let(:template_lookup) { Toys::ModuleLookup.new.add_path("toys/templates") }

  describe "unit functionality" do
    let(:template_class) { template_lookup.lookup(:rdoc) }
    let(:template) { template_class.new }

    it "handles the name field" do
      assert_equal("rdoc", template.name)
      template.name = "hi"
      assert_equal("hi", template.name)
      template.name = nil
      assert_equal("rdoc", template.name)
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
      assert_equal([">= 6.1.0"], template.gem_version)
      template.gem_version = "~> 6.2"
      assert_equal(["~> 6.2"], template.gem_version)
      template.gem_version = ["~> 6.0", "< 6.2"]
      assert_equal(["~> 6.0", "< 6.2"], template.gem_version)
      template.gem_version = nil
      assert_equal([">= 6.1.0"], template.gem_version)
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
      assert_equal("html", template.output_dir)
      template.output_dir = "hi"
      assert_equal("hi", template.output_dir)
      template.output_dir = nil
      assert_equal("html", template.output_dir)
    end

    it "handles the markup field" do
      assert_nil(template.markup)
      template.markup = "tomdoc"
      assert_equal("tomdoc", template.markup)
      template.markup = nil
      assert_nil(template.markup)
    end

    it "handles the title field" do
      assert_nil(template.title)
      template.title = "My Gem"
      assert_equal("My Gem", template.title)
      template.title = nil
      assert_nil(template.title)
    end

    it "handles the main field" do
      assert_nil(template.main)
      template.main = "README.md"
      assert_equal("README.md", template.main)
      template.main = nil
      assert_nil(template.main)
    end

    it "handles the template field" do
      assert_nil(template.template)
      template.template = "mytmpl"
      assert_equal("mytmpl", template.template)
      template.template = nil
      assert_nil(template.template)
    end

    it "handles the generator field" do
      assert_nil(template.generator)
      template.generator = "mygen"
      assert_equal("mygen", template.generator)
      template.generator = nil
      assert_nil(template.generator)
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
                                    gem_version: "~> 6.2",
                                    files: "src/**/*.rb",
                                    output_dir: "my_docs",
                                    markup: "tomdoc",
                                    main: "README.md",
                                    template: "mytmpl",
                                    generator: "mygen",
                                    options: "-v",
                                    context_directory: "/path/to/context"
      assert_equal("hi", template.name)
      assert_equal(["~> 6.2"], template.gem_version)
      assert_equal(["src/**/*.rb"], template.files)
      assert_equal("my_docs", template.output_dir)
      assert_equal("tomdoc", template.markup)
      assert_equal("README.md", template.main)
      assert_equal("mytmpl", template.template)
      assert_equal("mygen", template.generator)
      assert_equal(["-v"], template.options)
      assert_equal("/path/to/context", template.context_directory)
    end
  end

  describe "integration functionality" do
    let(:cli) { Toys::CLI.new(middleware_stack: [], template_lookup: template_lookup) }
    let(:loader) { cli.loader }

    it "runs rdoc" do
      input_dir = File.join(File.dirname(__dir__), "test-data", "doc-case")
      output_dir = File.join(File.dirname(__dir__), "tmp")
      FileUtils.rm_rf(output_dir)
      loader.add_block do
        set_context_directory input_dir
        expand :rdoc, output_dir: output_dir
      end
      capture_subprocess_io do
        assert_equal(0, cli.run("rdoc"))
      end
      assert_path_exists(File.join(output_dir, "index.html"))
    end

    it "honors context_directory setting" do
      input_dir = File.join(File.dirname(__dir__), "test-data", "doc-case")
      output_dir = File.join(File.dirname(__dir__), "tmp")
      FileUtils.rm_rf(output_dir)
      loader.add_block do
        expand :rdoc, output_dir: output_dir, context_directory: input_dir
      end
      capture_subprocess_io do
        assert_equal(0, cli.run("rdoc"))
      end
      assert_path_exists(File.join(output_dir, "index.html"))
    end
  end
end
