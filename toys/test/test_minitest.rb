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

    it "sets the minitest gem version" do
      assert_equal([">= 5.0", "< 7"], template.gem_dependencies["minitest"])
      template.minitest = "~> 6.0"
      assert_equal(["~> 6.0"], template.gem_dependencies["minitest"])
      template.minitest = ["~> 5.14.0", "< 6.0"]
      assert_equal(["~> 5.14.0", "< 6.0"], template.gem_dependencies["minitest"])
      template.minitest = nil
      assert_equal([">= 5.0", "< 7"], template.gem_dependencies["minitest"])
    end

    it "sets the minitest-mock gem version" do
      refute_includes(template.gem_dependencies, "minitest-mock")
      template.minitest_mock = "= 5.27.0"
      assert_equal(["= 5.27.0"], template.gem_dependencies["minitest-mock"])
      template.minitest_mock = [">= 5.27", "< 5.28"]
      assert_equal([">= 5.27", "< 5.28"], template.gem_dependencies["minitest-mock"])
      template.minitest_mock = true
      assert_equal(["~> 5.27"], template.gem_dependencies["minitest-mock"])
      template.minitest_mock = nil
      refute_includes(template.gem_dependencies, "minitest-mock")
    end

    it "sets the minitest-focus gem version" do
      refute_includes(template.gem_dependencies, "minitest-focus")
      template.minitest_focus = "= 1.4.1"
      assert_equal(["= 1.4.1"], template.gem_dependencies["minitest-focus"])
      template.minitest_focus = [">= 1.4", "< 1.5"]
      assert_equal([">= 1.4", "< 1.5"], template.gem_dependencies["minitest-focus"])
      template.minitest_focus = true
      assert_equal(["~> 1.4", ">= 1.4.1"], template.gem_dependencies["minitest-focus"])
      template.minitest_focus = nil
      refute_includes(template.gem_dependencies, "minitest-focus")
    end

    it "sets the minitest-rg gem version" do
      refute_includes(template.gem_dependencies, "minitest-rg")
      template.minitest_rg = "= 5.4.0"
      assert_equal(["= 5.4.0"], template.gem_dependencies["minitest-rg"])
      template.minitest_rg = [">= 5.4", "< 5.5"]
      assert_equal([">= 5.4", "< 5.5"], template.gem_dependencies["minitest-rg"])
      template.minitest_rg = true
      assert_equal(["~> 5.4"], template.gem_dependencies["minitest-rg"])
      template.minitest_rg = nil
      refute_includes(template.gem_dependencies, "minitest-rg")
    end

    it "sets arbitrary gem versions" do
      assert_equal([">= 5.0", "< 7"], template.gem_dependencies["minitest"])
      refute_includes(template.gem_dependencies, "minitest-mock")
      refute_includes(template.gem_dependencies, "toys")
      template.update_gems({"minitest" => "~> 6.0", "minitest-mock" => "= 5.27.0", "toys" => "= 0.19.1"})
      assert_equal(["~> 6.0"], template.gem_dependencies["minitest"])
      assert_equal(["= 5.27.0"], template.gem_dependencies["minitest-mock"])
      assert_equal(["= 0.19.1"], template.gem_dependencies["toys"])
      template.update_gems({"minitest" => ["~> 5.14.0", "< 6.0"],
                            "minitest-mock" => [">= 5.27", "< 5.28"],
                            "toys" => [">= 0.19.1", "< 0.20"]})
      assert_equal(["~> 5.14.0", "< 6.0"], template.gem_dependencies["minitest"])
      assert_equal([">= 5.27", "< 5.28"], template.gem_dependencies["minitest-mock"])
      assert_equal([">= 0.19.1", "< 0.20"], template.gem_dependencies["toys"])
      template.update_gems({"minitest" => true, "minitest-mock" => true, "toys" => true})
      assert_equal([">= 5.0", "< 7"], template.gem_dependencies["minitest"])
      assert_equal(["~> 5.27"], template.gem_dependencies["minitest-mock"])
      assert_equal([], template.gem_dependencies["toys"])
      template.update_gems({"minitest" => nil, "minitest-mock" => nil, "toys" => nil})
      assert_equal([">= 5.0", "< 7"], template.gem_dependencies["minitest"])
      refute_includes(template.gem_dependencies, "minitest-mock")
      refute_includes(template.gem_dependencies, "toys")
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

    it "handles the bundler_settings field via the bundler writer" do
      assert_equal({setup: :manual}, template.bundler_settings)
      refute(template.default_to_bundler?)
      template.bundler = true
      assert_equal({setup: :manual}, template.bundler_settings)
      assert(template.default_to_bundler?)
      template.bundler = {groups: ["production"]}
      assert_equal({groups: ["production"], setup: :manual}, template.bundler_settings)
      assert(template.default_to_bundler?)
      template.bundler = false
      assert_equal({setup: :manual}, template.bundler_settings)
      refute(template.default_to_bundler?)
    end

    it "handles the bundler_settings field via use_bundler" do
      assert_equal({setup: :manual}, template.bundler_settings)
      refute(template.default_to_bundler?)
      template.use_bundler
      assert_equal({setup: :manual}, template.bundler_settings)
      assert(template.default_to_bundler?)
      template.use_bundler(groups: ["production"])
      assert_equal({groups: ["production"], setup: :manual}, template.bundler_settings)
      assert(template.default_to_bundler?)
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
                                    minitest: "~> 6.0",
                                    minitest_mock: [">= 5.27.0", "< 5.28"],
                                    minitest_focus: "= 1.4.1",
                                    minitest_rg: true,
                                    gems: {"toys" => "= 1.9.1"},
                                    libs: "src",
                                    files: "test_files/**/*_test.rb",
                                    seed: 1234,
                                    verbose: true,
                                    warnings: false,
                                    context_directory: "/path/to/context"
      assert_equal("hi", template.name)
      assert_equal(["src"], template.libs)
      assert_equal(["test_files/**/*_test.rb"], template.files)
      assert_equal(1234, template.seed)
      assert_equal(true, template.verbose)
      assert_equal(false, template.warnings)
      assert_equal("/path/to/context", template.context_directory)
      expected_gems = {
        "minitest" => ["~> 6.0"],
        "minitest-focus" => ["= 1.4.1"],
        "minitest-mock" => [">= 5.27.0", "< 5.28"],
        "minitest-rg" => ["~> 5.4"],
        "toys" => ["= 1.9.1"],
      }
      assert_equal(expected_gems, template.gem_dependencies)
    end
  end

  describe "integration functionality" do
    let(:middleware_stack) { [Toys::Middleware.spec(:add_verbosity_flags)] }
    let(:cli) { Toys::CLI.new(middleware_stack: middleware_stack, template_lookup: template_lookup) }
    let(:loader) { cli.loader }
    let(:cases_dir) { File.join(File.dirname(__dir__), "test-data", "minitest-cases") }
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
      assert_match(/0 errors/, out)
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

    it "chooses files" do
      dir = cases_dir
      loader.add_block do
        set_context_directory dir
        expand :minitest, files: "multiple/*.rb"
      end
      out, _err = capture_subprocess_io do
        assert_equal(0, cli.run("test", "multiple/bar.rb"))
      end
      assert_match(/0 failures/, out)
      assert_match(/0 errors/, out)
    end

    it "expands globs when choosing files with --globs" do
      dir = cases_dir
      loader.add_block do
        set_context_directory dir
        expand :minitest, files: "multiple/*.rb"
      end
      out, _err = capture_subprocess_io do
        assert_equal(0, cli.run("test", "--globs", "*/bar.rb"))
      end
      assert_match(/0 failures/, out)
      assert_match(/0 errors/, out)
    end

    it "warns if a glob doesn't match anything" do
      dir = cases_dir
      loader.add_block do
        set_context_directory dir
        expand :minitest, files: "multiple/*.rb"
      end
      out, err = capture_subprocess_io do
        assert_equal(0, cli.run("test", "--globs", "*/bar.rb", "foo/*.rb"))
      end
      assert_match(/0 failures/, out)
      assert_match(/0 errors/, out)
      assert_includes(err, 'Glob "foo/*.rb" did not match anything')
    end

    it "does not expand globs by default when choosing files" do
      dir = cases_dir
      loader.add_block do
        set_context_directory dir
        expand :minitest, files: "multiple/*.rb"
      end
      _out, err = capture_subprocess_io do
        assert_equal(1, cli.run("test", "*/bar.rb"))
      end
      assert_includes(err, "Unable to load test: */bar.rb")
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
      assert_match(/0 errors/, out)
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
      assert_match(/0 errors/, out)
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
      assert_match(/0 errors/, out)
    end

    it "supports input streams" do
      dir = "#{cases_dir}/stream"
      args = [Toys.executable_path, "test"]
      result = exec_service.exec_ruby(args, chdir: dir,
                                      in: :controller, out: :capture) do |controller|
        controller.in.puts "hello"
      end
      assert(result.success?)
      assert_match(/0 failures/, result.captured_out)
      assert_match(/0 errors/, result.captured_out)
    end

    it "does not load minitest-focus by default" do
      skip unless ENV["TOYS_TEST_INTEGRATION"]
      result = ::Bundler.with_unbundled_env do
        dir = "#{cases_dir}/focus"
        args = [Toys.executable_path, "test-without"]
        exec_service.exec_ruby(args, chdir: dir, out: :capture, err: :capture)
      end
      assert_equal(1, result.exit_code)
      assert_match(/undefined/, result.captured_err)
    end

    it "loads minitest-focus directly" do
      skip unless ENV["TOYS_TEST_INTEGRATION"]
      result = ::Bundler.with_unbundled_env do
        dir = "#{cases_dir}/focus"
        args = [Toys.executable_path, "test-direct"]
        exec_service.exec_ruby(args, chdir: dir, out: :capture, err: :capture)
      end
      assert_equal(0, result.exit_code)
      assert_match(/0 failures/, result.captured_out)
      assert_match(/0 errors/, result.captured_out)
    end

    it "loads minitest-focus from bundler" do
      skip unless ENV["TOYS_TEST_INTEGRATION"]
      result = ::Bundler.with_unbundled_env do
        dir = "#{cases_dir}/focus"
        args = [Toys.executable_path, "test-bundle"]
        exec_service.exec_ruby(args, chdir: dir, out: :capture, err: :capture)
      end
      assert_equal(0, result.exit_code)
      assert_match(/0 failures/, result.captured_out)
      assert_match(/0 errors/, result.captured_out)
    end

    it "recognizes the --use-gem flag with no version" do
      skip unless ENV["TOYS_TEST_INTEGRATION"]
      result = ::Bundler.with_unbundled_env do
        dir = "#{cases_dir}/focus"
        args = [Toys.executable_path, "test-without", "--use-gem", "minitest-focus"]
        exec_service.exec_ruby(args, chdir: dir, out: :capture, err: :capture)
      end
      assert_equal(0, result.exit_code)
      assert_match(/0 failures/, result.captured_out)
      assert_match(/0 errors/, result.captured_out)
    end

    it "recognizes the --use-gem flag with versions" do
      skip unless ENV["TOYS_TEST_INTEGRATION"]
      result = ::Bundler.with_unbundled_env do
        dir = "#{cases_dir}/focus"
        args = [Toys.executable_path, "test-without", "--use-gem", "minitest-focus , ~>1.4, >=1.4.1"]
        exec_service.exec_ruby(args, chdir: dir, out: :capture, err: :capture)
      end
      assert_equal(0, result.exit_code)
      assert_match(/0 failures/, result.captured_out)
      assert_match(/0 errors/, result.captured_out)
    end

    it "recognizes the --omit-gem flag" do
      skip unless ENV["TOYS_TEST_INTEGRATION"]
      result = ::Bundler.with_unbundled_env do
        dir = "#{cases_dir}/focus"
        args = [Toys.executable_path, "test-direct", "--omit-gem", "minitest-focus"]
        exec_service.exec_ruby(args, chdir: dir, out: :capture, err: :capture)
      end
      assert_equal(1, result.exit_code)
      assert_match(/undefined/, result.captured_err)
    end

    it "recognizes the --use-gem flag overriding default bundler" do
      skip unless ENV["TOYS_TEST_INTEGRATION"]
      result = ::Bundler.with_unbundled_env do
        dir = "#{cases_dir}/focus"
        args = [Toys.executable_path, "test-bundle", "--use-gem", "minitest"]
        exec_service.exec_ruby(args, chdir: dir, out: :capture, err: :capture)
      end
      assert_equal(1, result.exit_code)
      assert_match(/undefined/, result.captured_err)
    end

    it "recognizes the --gemfile-path flag" do
      skip unless ENV["TOYS_TEST_INTEGRATION"]
      result = ::Bundler.with_unbundled_env do
        dir = "#{cases_dir}/focus"
        args = [Toys.executable_path, "test-without", "--gemfile-path", "Gemfile"]
        exec_service.exec_ruby(args, chdir: dir, out: :capture, err: :capture)
      end
      assert_equal(0, result.exit_code)
      assert_match(/0 failures/, result.captured_out)
      assert_match(/0 errors/, result.captured_out)
    end

    it "catches mutually exclusive gem arguments" do
      skip unless ENV["TOYS_TEST_INTEGRATION"]
      result = ::Bundler.with_unbundled_env do
        dir = "#{cases_dir}/focus"
        args = [Toys.executable_path, "test-bundle", "--gemfile-path", "Gemfile", "--use-gem", "minitest"]
        exec_service.exec_ruby(args, chdir: dir, out: :capture, err: :capture)
      end
      assert_equal(1, result.exit_code)
      assert_match(/mutually exclusive/, result.captured_err)
    end

    it "catches bad --use-gem syntax" do
      skip unless ENV["TOYS_TEST_INTEGRATION"]
      result = ::Bundler.with_unbundled_env do
        dir = "#{cases_dir}/focus"
        args = [Toys.executable_path, "test-bundle", "--use-gem", ","]
        exec_service.exec_ruby(args, chdir: dir, out: :capture, err: :capture)
      end
      assert_equal(1, result.exit_code)
      assert_match(/Bad format for --use-gem/, result.captured_err)
    end

    it "ignores --omit-gem=minitest" do
      skip unless ENV["TOYS_TEST_INTEGRATION"]
      result = ::Bundler.with_unbundled_env do
        dir = "#{cases_dir}/focus"
        args = [Toys.executable_path, "test-direct", "--omit-gem", "minitest"]
        exec_service.exec_ruby(args, chdir: dir, out: :capture, err: :capture)
      end
      assert_equal(0, result.exit_code)
      assert_match(/0 failures/, result.captured_out)
      assert_match(/0 errors/, result.captured_out)
      assert_match(/You cannot omit the minitest gem/, result.captured_err)
    end

    it "recognizes the --include flag" do
      dir = cases_dir
      loader.add_block do
        set_context_directory dir
        expand :minitest, files: "multiple/*.rb"
      end
      out, _err = capture_subprocess_io do
        assert_equal(0, cli.run("test", "--include", "/passes/"))
      end
      assert_match(/0 failures/, out)
      assert_match(/0 errors/, out)
    end

    it "recognizes the --exclude flag" do
      dir = cases_dir
      loader.add_block do
        set_context_directory dir
        expand :minitest, files: "multiple/*.rb"
      end
      out, _err = capture_subprocess_io do
        assert_equal(0, cli.run("test", "--exclude", "/fails/"))
      end
      assert_match(/0 failures/, out)
      assert_match(/0 errors/, out)
    end

    it "recognizes the --verbose flag" do
      dir = cases_dir
      loader.add_block do
        set_context_directory dir
        expand :minitest, files: "passing/*.rb"
      end
      out, _err = capture_subprocess_io do
        assert_equal(0, cli.run("test", "--verbose"))
      end
      assert_match(/0 failures/, out)
      assert_match(/0 errors/, out)
      assert_includes(out, "foo#test_0001_passes =")
    end

    it "runs preload code" do
      dir = cases_dir
      loader.add_block do
        set_context_directory dir
        expand :minitest, files: "passing/*.rb"
      end
      out, _err = capture_subprocess_io do
        assert_equal(0, cli.run("test", "--preload-code", "puts 'PRELOAD RAN'"))
      end
      assert_match(/PRELOAD RAN/, out)
    end
  end
end
