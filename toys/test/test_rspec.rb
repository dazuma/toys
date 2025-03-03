# frozen_string_literal: true

require "helper"
require "toys/utils/exec"

describe "rspec template" do
  let(:template_lookup) { Toys::ModuleLookup.new.add_path("toys/templates") }

  describe "unit functionality" do
    let(:template_class) { template_lookup.lookup(:rspec) }
    let(:template) { template_class.new }

    it "handles the name field" do
      assert_equal("spec", template.name)
      template.name = "hi"
      assert_equal("hi", template.name)
      template.name = nil
      assert_equal("spec", template.name)
    end

    it "handles the libs field" do
      assert_equal(["lib"], template.libs)
      template.libs = "src"
      assert_equal(["src"], template.libs)
      template.libs = ["src", "lib"]
      assert_equal(["src", "lib"], template.libs)
      template.libs = nil
      assert_equal(["lib"], template.libs)
    end

    it "handles the gem_version field without bundler" do
      assert_equal(["~> 3.1"], template.gem_version)
      template.gem_version = "~> 5.1"
      assert_equal(["~> 5.1"], template.gem_version)
      template.gem_version = ["~> 5.14.0", "< 6.0"]
      assert_equal(["~> 5.14.0", "< 6.0"], template.gem_version)
      template.gem_version = nil
      assert_equal(["~> 3.1"], template.gem_version)
    end

    it "handles the gem_version field with bundler" do
      template.use_bundler
      assert_equal([], template.gem_version)
      template.gem_version = "~> 5.1"
      assert_equal(["~> 5.1"], template.gem_version)
      template.gem_version = ["~> 5.14.0", "< 6.0"]
      assert_equal(["~> 5.14.0", "< 6.0"], template.gem_version)
      template.gem_version = nil
      assert_equal([], template.gem_version)
    end

    it "handles the options field" do
      assert_nil(template.options)
      template.options = "myoptions/.rspec"
      assert_equal("myoptions/.rspec", template.options)
      template.options = nil
      assert_nil(template.options)
    end

    it "handles the order field" do
      assert_equal("defined", template.order)
      template.order = "rand"
      assert_equal("rand", template.order)
      template.order = nil
      assert_equal("defined", template.order)
    end

    it "handles the format field" do
      assert_equal("p", template.format)
      template.format = "documentation"
      assert_equal("documentation", template.format)
      template.format = nil
      assert_equal("p", template.format)
    end

    it "handles the out field" do
      assert_nil(template.out)
      template.out = "results.txt"
      assert_equal("results.txt", template.out)
      template.out = nil
      assert_nil(template.out)
    end

    it "handles the backtrace field" do
      assert_equal(false, template.backtrace)
      template.backtrace = true
      assert_equal(true, template.backtrace)
    end

    it "handles the pattern field" do
      assert_equal("spec/**/*_spec.rb", template.pattern)
      template.pattern = "myspecs/**/*_spec.rb"
      assert_equal("myspecs/**/*_spec.rb", template.pattern)
      template.pattern = nil
      assert_equal("spec/**/*_spec.rb", template.pattern)
    end

    it "handles the warnings field" do
      assert_equal(true, template.warnings)
      template.warnings = false
      assert_equal(false, template.warnings)
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
                                    libs: "src",
                                    options: "myoptions/.rspec",
                                    order: "rand",
                                    format: "documentation",
                                    out: "results.txt",
                                    backtrace: true,
                                    pattern: "myspecs/**/*_spec.rb",
                                    warnings: false,
                                    context_directory: "/path/to/context"
      assert_equal("hi", template.name)
      assert_equal(["~> 3.2"], template.gem_version)
      assert_equal(["src"], template.libs)
      assert_equal("myoptions/.rspec", template.options)
      assert_equal("rand", template.order)
      assert_equal("documentation", template.format)
      assert_equal("results.txt", template.out)
      assert_equal(true, template.backtrace)
      assert_equal("myspecs/**/*_spec.rb", template.pattern)
      assert_equal(false, template.warnings)
      assert_equal("/path/to/context", template.context_directory)
    end
  end

  describe "integration functionality" do
    let(:cli) { Toys::CLI.new(middleware_stack: [], template_lookup: template_lookup) }
    let(:loader) { cli.loader }
    let(:cases_dir) { File.join(File.dirname(__dir__), "test-data", "rspec-cases") }
    let(:exec_service) { Toys::Utils::Exec.new }

    it "executes a successful spec" do
      dir = cases_dir
      loader.add_block do
        set_context_directory dir
        expand :rspec, libs: "lib1", pattern: "spec/*_spec.rb"
      end
      out, _err = capture_subprocess_io do
        assert_equal(0, cli.run("spec"))
      end
      assert_match(/1 example, 0 failures/, out)
    end

    it "executes an unsuccessful spec" do
      dir = cases_dir
      loader.add_block do
        set_context_directory dir
        expand :rspec, libs: "lib2", pattern: "spec/*_spec.rb"
      end
      out, _err = capture_subprocess_io do
        refute_equal(0, cli.run("spec"))
      end
      assert_match(/1 example, 1 failure/, out)
    end

    it "honors the context_directory setting" do
      dir = cases_dir
      loader.add_block do
        expand :rspec, libs: "lib1", pattern: "spec/*_spec.rb", context_directory: dir
      end
      out, _err = capture_subprocess_io do
        assert_equal(0, cli.run("spec"))
      end
      assert_match(/1 example, 0 failures/, out)
    end

    it "supports input streams" do
      dir = "#{cases_dir}/stream"
      args = ["--disable=gems", Toys.executable_path, "spec"]
      result = exec_service.exec_ruby(args, chdir: dir,
                                      in: :controller, out: :capture) do |controller|
        controller.in.puts "foo"
      end
      assert(result.success?)
      assert_match(/0 failures/, result.captured_out)
    end
  end
end
