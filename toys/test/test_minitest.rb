# frozen_string_literal: true

require "helper"
require "toys/utils/exec"

describe "minitest template" do
  let(:template_lookup) { Toys::ModuleLookup.new.add_path("toys/templates") }

  describe "unit functionality" do
    let(:template_class) { template_lookup.lookup(:minitest) }
    let(:template) { template_class.new }

    it "handles the name field" do
      assert_equal("test", template.name)
      template.name = "hi"
      assert_equal("hi", template.name)
      template.name = nil
      assert_equal("test", template.name)
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

    it "handles the files field" do
      assert_equal(["test/**/test*.rb"], template.files)
      template.files = "test/**/*_test.rb"
      assert_equal(["test/**/*_test.rb"], template.files)
      template.files = ["test/**/test*.rb", "spec/**/test*.rb"]
      assert_equal(["test/**/test*.rb", "spec/**/test*.rb"], template.files)
      template.files = nil
      assert_equal(["test/**/test*.rb"], template.files)
    end

    it "handles the gem_version field without bundler" do
      assert_equal(["~> 5.0"], template.gem_version)
      template.gem_version = "~> 5.1"
      assert_equal(["~> 5.1"], template.gem_version)
      template.gem_version = ["~> 5.14.0", "< 6.0"]
      assert_equal(["~> 5.14.0", "< 6.0"], template.gem_version)
      template.gem_version = nil
      assert_equal(["~> 5.0"], template.gem_version)
    end

    it "handles the seed field" do
      assert_nil(template.seed)
      template.seed = 1234
      assert_equal(1234, template.seed)
      template.seed = nil
      assert_nil(template.seed)
    end

    it "handles the verbpse field" do
      assert_equal(false, template.verbose)
      template.verbose = true
      assert_equal(true, template.verbose)
    end

    it "handles the warnings field" do
      assert_equal(true, template.warnings)
      template.warnings = false
      assert_equal(false, template.warnings)
    end

    it "handles the mt_compat field" do
      assert_nil(template.mt_compat)
      template.mt_compat = false
      assert_equal(false, template.mt_compat)
      template.mt_compat = true
      assert_equal(true, template.mt_compat)
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
                                    gem_version: "~> 5.1",
                                    libs: "src",
                                    files: "test_files/**/*_test.rb",
                                    seed: 1234,
                                    verbose: true,
                                    warnings: false,
                                    context_directory: "/path/to/context"
      assert_equal("hi", template.name)
      assert_equal(["~> 5.1"], template.gem_version)
      assert_equal(["src"], template.libs)
      assert_equal(["test_files/**/*_test.rb"], template.files)
      assert_equal(1234, template.seed)
      assert_equal(true, template.verbose)
      assert_equal(false, template.warnings)
      assert_equal("/path/to/context", template.context_directory)
    end
  end

  describe "integration functionality" do
    let(:cli) { Toys::CLI.new(middleware_stack: [], template_lookup: template_lookup) }
    let(:loader) { cli.loader }
    let(:cases_dir) { File.join(__dir__, "minitest-cases") }
    let(:exec_service) { Toys::Utils::Exec.new }

    it "runs passing tests" do
      dir = cases_dir
      loader.add_block do
        set_context_directory dir
        expand :minitest, files: "passing/*.rb"
      end
      out, _err = capture_subprocess_io do
        assert_equal(0, cli.run("test"))
      end
      assert_match(/0 failures/, out)
    end

    it "runs failing tests" do
      dir = cases_dir
      loader.add_block do
        set_context_directory dir
        expand :minitest, files: "failing/*.rb"
      end
      out, _err = capture_subprocess_io do
        assert_equal(1, cli.run("test"))
      end
      assert_match(/1 failure/, out)
    end

    it "honors context_directory argument" do
      dir = cases_dir
      loader.add_block do
        expand :minitest, files: "failing/*.rb", context_directory: dir
      end
      out, _err = capture_subprocess_io do
        assert_equal(1, cli.run("test"))
      end
      assert_match(/1 failure/, out)
    end

    it "passes MT_COMPAT" do
      dir = cases_dir
      loader.add_block do
        set_context_directory dir
        expand :minitest, files: "mt-compat/*.rb"
      end
      expected_failures = ENV["MT_COMPAT"] ? 0 : 1
      out, _err = capture_subprocess_io do
        assert_equal(expected_failures, cli.run("test"))
      end
      assert_match(/#{expected_failures} failure/, out)
    end

    it "sets MT_COMPAT" do
      dir = cases_dir
      loader.add_block do
        set_context_directory dir
        expand :minitest, files: "mt-compat/*.rb", mt_compat: true
      end
      old_mt_compat = ENV["MT_COMPAT"]
      begin
        out, _err = capture_subprocess_io do
          ENV["MT_COMPAT"] = nil
          assert_equal(0, cli.run("test"))
        end
      ensure
        ENV["MT_COMPAT"] = old_mt_compat
      end
      assert_match(/0 failures/, out)
    end

    it "clears MT_COMPAT" do
      dir = cases_dir
      loader.add_block do
        set_context_directory dir
        expand :minitest, files: "mt-compat/*.rb", mt_compat: false
      end
      old_mt_compat = ENV["MT_COMPAT"]
      begin
        out, _err = capture_subprocess_io do
          ENV["MT_COMPAT"] = "true"
          assert_equal(1, cli.run("test"))
        end
      ensure
        ENV["MT_COMPAT"] = old_mt_compat
      end
      assert_match(/1 failure/, out)
    end

    it "supports input streams" do
      dir = "#{cases_dir}/stream"
      args = ["--disable=gems", Toys.executable_path, "test"]
      result = exec_service.exec_ruby(args, chdir: dir,
                                      in: :controller, out: :capture) do |controller|
        controller.in.puts "hello"
      end
      assert(result.success?)
      assert_match(/0 failures/, result.captured_out)
      assert_match(/0 errors/, result.captured_out)
    end
  end
end
