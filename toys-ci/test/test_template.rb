# frozen_string_literal: true

require "helper"

describe Toys::CI::Template do
  let(:logger) {
    Logger.new(StringIO.new).tap do |lgr|
      lgr.level = Logger::WARN
    end
  }
  let(:executable_name) { "toys" }
  let(:cli) {
    Toys::CLI.new(executable_name: executable_name, logger: logger, middleware_stack: [])
  }
  let(:data_dir) { File.join(File.dirname(__dir__), "test-data") }
  let(:basic_tools_dir) { File.join(data_dir, "basic-tools") }

  describe "job types" do
    it "runs a succeeding tool job" do
      cli.add_config_block(context_directory: basic_tools_dir) do
        tool "ci" do
          expand Toys::CI::Template do |ci|
            ci.tool_job("Foo", ["foo"])
          end
        end
      end

      out, _err = capture_subprocess_io do
        assert_equal(0, cli.run("ci"))
      end
      assert_includes(out, "FOO SUCCEEDED")
      assert_includes(out, "SUCCEEDED: Foo")
    end

    it "runs a failing tool job" do
      cli.add_config_block(context_directory: basic_tools_dir) do
        tool "ci" do
          expand Toys::CI::Template do |ci|
            ci.tool_job("Bar", ["bar"])
          end
        end
      end

      out, _err = capture_subprocess_io do
        assert_equal(1, cli.run("ci"))
      end
      assert_includes(out, "BAR FAILED")
      assert_includes(out, "FAILED: Bar")
    end

    it "runs a succeeding cmd job" do
      cli.add_config_block(context_directory: basic_tools_dir) do
        tool "ci" do
          expand Toys::CI::Template do |ci|
            ci.cmd_job("Echo", ["echo", "CMD SUCCEEDED"])
          end
        end
      end

      out, _err = capture_subprocess_io do
        assert_equal(0, cli.run("ci"))
      end
      assert_includes(out, "CMD SUCCEEDED")
      assert_includes(out, "SUCCEEDED: Echo")
    end

    it "runs a failing cmd job" do
      cli.add_config_block(context_directory: basic_tools_dir) do
        tool "ci" do
          expand Toys::CI::Template do |ci|
            ci.cmd_job("Hoho", ["hohohohohohoho"])
          end
        end
      end

      out, _err = capture_subprocess_io do
        assert_equal(1, cli.run("ci"))
      end
      assert_includes(out, "FAILED: Hoho")
    end

    it "runs a succeeding block job" do
      cli.add_config_block(context_directory: basic_tools_dir) do
        tool "ci" do
          expand Toys::CI::Template do |ci|
            ci.job("Good Block") do
              puts "BLOCK SUCCEEDED"
              true
            end
          end
        end
      end

      out, _err = capture_subprocess_io do
        assert_equal(0, cli.run("ci"))
      end
      assert_includes(out, "BLOCK SUCCEEDED")
      assert_includes(out, "SUCCEEDED: Good Block")
    end

    it "runs a failing block job" do
      cli.add_config_block(context_directory: basic_tools_dir) do
        tool "ci" do
          expand Toys::CI::Template do |ci|
            ci.job("Bad Block") do
              puts "BLOCK FAILED"
              false
            end
          end
        end
      end

      out, _err = capture_subprocess_io do
        assert_equal(1, cli.run("ci"))
      end
      assert_includes(out, "BLOCK FAILED")
      assert_includes(out, "FAILED: Bad Block")
    end
  end

  describe "with an --all flag" do
    it "runs no jobs by default" do
      cli.add_config_block(context_directory: basic_tools_dir) do
        tool "ci" do
          expand Toys::CI::Template do |ci|
            ci.tool_job("Foo", ["foo"])
            ci.tool_job("Bar", ["bar"])
            ci.all_flag = true
          end
        end
      end

      out, _err = capture_subprocess_io do
        assert_equal(2, cli.run("ci"))
      end
      assert_includes(out, "CI: NO JOBS REQUESTED")
      refute_includes(out, "FOO SUCCEEDED")
      refute_includes(out, "BAR FAILED")
    end

    it "runs all jobs if the --all flag is given" do
      cli.add_config_block(context_directory: basic_tools_dir) do
        tool "ci" do
          expand Toys::CI::Template do |ci|
            ci.tool_job("Foo", ["foo"])
            ci.tool_job("Bar", ["bar"])
            ci.all_flag = true
          end
        end
      end

      out, _err = capture_subprocess_io do
        assert_equal(1, cli.run("ci", "--all"))
      end
      assert_includes(out, "FOO SUCCEEDED")
      assert_includes(out, "BAR FAILED")
    end

    it "runs individual tools given their flag" do
      cli.add_config_block(context_directory: basic_tools_dir) do
        tool "ci" do
          expand Toys::CI::Template do |ci|
            ci.tool_job("Foo", ["foo"], flag: :foo)
            ci.tool_job("Bar", ["bar"], flag: :bar)
            ci.all_flag = true
          end
        end
      end

      out, _err = capture_subprocess_io do
        assert_equal(0, cli.run("ci", "--foo"))
      end
      assert_includes(out, "FOO SUCCEEDED")
      refute_includes(out, "BAR FAILED")
    end

    it "runs individual tools given their override flag" do
      cli.add_config_block(context_directory: basic_tools_dir) do
        tool "ci" do
          expand Toys::CI::Template do |ci|
            ci.tool_job("Foo", ["foo"], flag: :foo, override_flags: "foo-override")
            ci.tool_job("Bar", ["bar"], flag: :bar)
            ci.all_flag = true
          end
        end
      end

      out, _err = capture_subprocess_io do
        assert_equal(0, cli.run("ci", "--foo-override"))
      end
      assert_includes(out, "FOO SUCCEEDED")
      refute_includes(out, "BAR FAILED")
    end

    it "omits individual tools given --all and their negative flag" do
      cli.add_config_block(context_directory: basic_tools_dir) do
        tool "ci" do
          expand Toys::CI::Template do |ci|
            ci.tool_job("Foo", ["foo"], flag: :foo)
            ci.tool_job("Bar", ["bar"], flag: :bar)
            ci.all_flag = true
          end
        end
      end

      out, _err = capture_subprocess_io do
        assert_equal(0, cli.run("ci", "--all", "--no-bar"))
      end
      assert_includes(out, "FOO SUCCEEDED")
      refute_includes(out, "BAR FAILED")
    end

    it "omits individual tools given --all and their negative override flag" do
      cli.add_config_block(context_directory: basic_tools_dir) do
        tool "ci" do
          expand Toys::CI::Template do |ci|
            ci.tool_job("Foo", ["foo"], flag: :foo)
            ci.tool_job("Bar", ["bar"], flag: :bar, override_flags: "bar-override")
            ci.all_flag = true
          end
        end
      end

      out, _err = capture_subprocess_io do
        assert_equal(0, cli.run("ci", "--all", "--no-bar-override"))
      end
      assert_includes(out, "FOO SUCCEEDED")
      refute_includes(out, "BAR FAILED")
    end
  end

  describe "with an --only flag" do
    it "runs all jobs by default" do
      cli.add_config_block(context_directory: basic_tools_dir) do
        tool "ci" do
          expand Toys::CI::Template do |ci|
            ci.tool_job("Foo", ["foo"])
            ci.tool_job("Bar", ["bar"])
            ci.only_flag = true
          end
        end
      end

      out, _err = capture_subprocess_io do
        assert_equal(1, cli.run("ci"))
      end
      assert_includes(out, "FOO SUCCEEDED")
      assert_includes(out, "BAR FAILED")
    end

    it "runs no jobs if the --only flag is given by itself" do
      cli.add_config_block(context_directory: basic_tools_dir) do
        tool "ci" do
          expand Toys::CI::Template do |ci|
            ci.tool_job("Foo", ["foo"])
            ci.tool_job("Bar", ["bar"])
            ci.only_flag = true
          end
        end
      end

      out, _err = capture_subprocess_io do
        assert_equal(2, cli.run("ci", "--only"))
      end
      assert_includes(out, "CI: NO JOBS REQUESTED")
      refute_includes(out, "FOO SUCCEEDED")
      refute_includes(out, "BAR FAILED")
    end

    it "omits individual tools given their negative flag" do
      cli.add_config_block(context_directory: basic_tools_dir) do
        tool "ci" do
          expand Toys::CI::Template do |ci|
            ci.tool_job("Foo", ["foo"], flag: :foo)
            ci.tool_job("Bar", ["bar"], flag: :bar)
            ci.only_flag = true
          end
        end
      end

      out, _err = capture_subprocess_io do
        assert_equal(0, cli.run("ci", "--no-bar"))
      end
      assert_includes(out, "FOO SUCCEEDED")
      refute_includes(out, "BAR FAILED")
    end

    it "runs individual tools given --only and their flag" do
      cli.add_config_block(context_directory: basic_tools_dir) do
        tool "ci" do
          expand Toys::CI::Template do |ci|
            ci.tool_job("Foo", ["foo"], flag: :foo)
            ci.tool_job("Bar", ["bar"], flag: :bar)
            ci.only_flag = true
          end
        end
      end

      out, _err = capture_subprocess_io do
        assert_equal(0, cli.run("ci", "--only", "--foo"))
      end
      assert_includes(out, "FOO SUCCEEDED")
      refute_includes(out, "BAR FAILED")
    end
  end

  describe "with jobs_disabled_by_default" do
    it "runs no jobs by default" do
      cli.add_config_block(context_directory: basic_tools_dir) do
        tool "ci" do
          expand Toys::CI::Template do |ci|
            ci.tool_job("Foo", ["foo"])
            ci.tool_job("Bar", ["bar"])
            ci.jobs_disabled_by_default = true
          end
        end
      end

      out, _err = capture_subprocess_io do
        assert_equal(2, cli.run("ci"))
      end
      assert_includes(out, "CI: NO JOBS REQUESTED")
      refute_includes(out, "FOO SUCCEEDED")
      refute_includes(out, "BAR FAILED")
    end

    it "runs individual tools given their flag" do
      cli.add_config_block(context_directory: basic_tools_dir) do
        tool "ci" do
          expand Toys::CI::Template do |ci|
            ci.tool_job("Foo", ["foo"], flag: :foo)
            ci.tool_job("Bar", ["bar"], flag: :bar)
            ci.jobs_disabled_by_default = true
          end
        end
      end

      out, _err = capture_subprocess_io do
        assert_equal(0, cli.run("ci", "--foo"))
      end
      assert_includes(out, "FOO SUCCEEDED")
      refute_includes(out, "BAR FAILED")
    end
  end

  describe "with a collection" do
    it "activates the entire collection" do
      cli.add_config_block(context_directory: basic_tools_dir) do
        tool "ci" do
          expand Toys::CI::Template do |ci|
            ci.tool_job("Foo", ["foo"], flag: :foo)
            ci.tool_job("Bar", ["bar"], flag: :bar)
            ci.collection("All Foobar", :foobar, [:foo, :bar])
            ci.jobs_disabled_by_default = true
          end
        end
      end

      out, _err = capture_subprocess_io do
        assert_equal(1, cli.run("ci", "--foobar"))
      end
      assert_includes(out, "FOO SUCCEEDED")
      assert_includes(out, "BAR FAILED")
    end

    it "activates the entire collection via override flag" do
      cli.add_config_block(context_directory: basic_tools_dir) do
        tool "ci" do
          expand Toys::CI::Template do |ci|
            ci.tool_job("Foo", ["foo"], flag: :foo)
            ci.tool_job("Bar", ["bar"], flag: :bar)
            ci.collection("All Foobar", :foobar, [:foo, :bar], override_flags: "foo-bar")
            ci.jobs_disabled_by_default = true
          end
        end
      end

      out, _err = capture_subprocess_io do
        assert_equal(1, cli.run("ci", "--foo-bar"))
      end
      assert_includes(out, "FOO SUCCEEDED")
      assert_includes(out, "BAR FAILED")
    end

    it "overrides collection activation with individual deactivation" do
      cli.add_config_block(context_directory: basic_tools_dir) do
        tool "ci" do
          expand Toys::CI::Template do |ci|
            ci.tool_job("Foo", ["foo"], flag: :foo)
            ci.tool_job("Bar", ["bar"], flag: :bar)
            ci.collection("All Foobar", :foobar, [:foo, :bar])
            ci.jobs_disabled_by_default = true
          end
        end
      end

      out, _err = capture_subprocess_io do
        assert_equal(0, cli.run("ci", "--foobar", "--no-bar"))
      end
      assert_includes(out, "FOO SUCCEEDED")
      refute_includes(out, "BAR FAILED")
    end

    it "deactivates the entire collection" do
      cli.add_config_block(context_directory: basic_tools_dir) do
        tool "ci" do
          expand Toys::CI::Template do |ci|
            ci.tool_job("Foo", ["foo"], flag: :foo)
            ci.tool_job("Bar", ["bar"], flag: :bar)
            ci.collection("All Foobar", :foobar, [:foo, :bar])
          end
        end
      end

      out, _err = capture_subprocess_io do
        assert_equal(2, cli.run("ci", "--no-foobar"))
      end
      assert_includes(out, "CI: NO JOBS REQUESTED")
      refute_includes(out, "FOO SUCCEEDED")
      refute_includes(out, "BAR FAILED")
    end

    it "deactivates the entire collection via override flag" do
      cli.add_config_block(context_directory: basic_tools_dir) do
        tool "ci" do
          expand Toys::CI::Template do |ci|
            ci.tool_job("Foo", ["foo"], flag: :foo)
            ci.tool_job("Bar", ["bar"], flag: :bar)
            ci.collection("All Foobar", :foobar, [:foo, :bar], override_flags: "foo-bar")
          end
        end
      end

      out, _err = capture_subprocess_io do
        assert_equal(2, cli.run("ci", "--no-foo-bar"))
      end
      assert_includes(out, "CI: NO JOBS REQUESTED")
      refute_includes(out, "FOO SUCCEEDED")
      refute_includes(out, "BAR FAILED")
    end

    it "overrides collection deactivation with individual activation" do
      cli.add_config_block(context_directory: basic_tools_dir) do
        tool "ci" do
          expand Toys::CI::Template do |ci|
            ci.tool_job("Foo", ["foo"], flag: :foo)
            ci.tool_job("Bar", ["bar"], flag: :bar)
            ci.collection("All Foobar", :foobar, [:foo, :bar])
          end
        end
      end

      out, _err = capture_subprocess_io do
        assert_equal(0, cli.run("ci", "--no-foobar", "--foo"))
      end
      assert_includes(out, "FOO SUCCEEDED")
      refute_includes(out, "BAR FAILED")
    end
  end

  it "executes a before_run block" do
    cli.add_config_block(context_directory: basic_tools_dir) do
      tool "ci" do
        expand Toys::CI::Template do |ci|
          ci.tool_job("Foo", ["foo"], flag: :foo)
          ci.tool_job("Bar", ["bar"], flag: :bar)
          ci.before_run do
            set(:bar, false)
          end
        end
      end
    end

    out, _err = capture_subprocess_io do
      assert_equal(0, cli.run("ci", "--foo", "--bar"))
    end
    assert_includes(out, "FOO SUCCEEDED")
    refute_includes(out, "BAR FAILED")
  end

  describe "fail-fast" do
    it "handles fail_fast_default set to true" do
      cli.add_config_block(context_directory: basic_tools_dir) do
        tool "ci" do
          expand Toys::CI::Template do |ci|
            ci.tool_job("Bar", ["bar"], flag: :bar)
            ci.tool_job("Foo", ["foo"], flag: :foo)
            ci.fail_fast_default = true
          end
        end
      end

      out, _err = capture_subprocess_io do
        assert_equal(1, cli.run("ci"))
      end
      refute_includes(out, "FOO SUCCEEDED")
      assert_includes(out, "BAR FAILED")
      assert_includes(out, "TERMINATING CI")
    end

    it "enables fail fast with the flag" do
      cli.add_config_block(context_directory: basic_tools_dir) do
        tool "ci" do
          expand Toys::CI::Template do |ci|
            ci.tool_job("Bar", ["bar"], flag: :bar)
            ci.tool_job("Foo", ["foo"], flag: :foo)
            ci.fail_fast_flag = true
          end
        end
      end

      out, _err = capture_subprocess_io do
        assert_equal(1, cli.run("ci", "--fail-fast"))
      end
      refute_includes(out, "FOO SUCCEEDED")
      assert_includes(out, "BAR FAILED")
      assert_includes(out, "TERMINATING CI")
    end

    it "disables fail fast with the flag when default is true" do
      cli.add_config_block(context_directory: basic_tools_dir) do
        tool "ci" do
          expand Toys::CI::Template do |ci|
            ci.tool_job("Bar", ["bar"], flag: :bar)
            ci.tool_job("Foo", ["foo"], flag: :foo)
            ci.fail_fast_flag = true
            ci.fail_fast_default = true
          end
        end
      end

      out, _err = capture_subprocess_io do
        assert_equal(1, cli.run("ci", "--no-fail-fast"))
      end
      assert_includes(out, "FOO SUCCEEDED")
      assert_includes(out, "BAR FAILED")
      assert_includes(out, "CI: FAILED 1 OF 2 RUNNABLE JOBS")
    end
  end

  describe "with base_ref" do
    let(:save_envs) { ["GITHUB_EVENT_NAME", "GITHUB_EVENT_PATH"] }
    let(:push_event_path) { File.join(data_dir, "push-event.json") }
    let(:pr_event_path) { File.join(data_dir, "pr-event.json") }

    before do
      @save_env_vars = save_envs.to_h { |name| [name, ::ENV[name]] }
    end

    after do
      @save_env_vars.each do |name, val|
        if val
          ::ENV[name] = val
        else
          ::ENV.delete(name)
        end
      end
    end

    it "runs all jobs if no base ref given" do
      cli.add_config_block(context_directory: basic_tools_dir) do
        tool "ci" do
          expand Toys::CI::Template do |ci|
            ci.tool_job("Foo", ["foo"], trigger_paths: "foo")
            ci.tool_job("Bar", ["bar"], trigger_paths: "bar")
            ci.base_ref_flag = true
          end
        end
      end

      out, _err = capture_subprocess_io do
        assert_equal(1, cli.run("ci"))
      end
      assert_includes(out, "FOO SUCCEEDED")
      assert_includes(out, "BAR FAILED")
    end

    it "checks that base_ref gets passed in" do
      cli.add_config_block(context_directory: basic_tools_dir) do
        tool "ci" do
          expand Toys::CI::Template do |ci|
            ci.tool_job("Foo", ["foo"], trigger_paths: "foo")
            ci.tool_job("Bar", ["bar"], trigger_paths: "bar")
            ci.base_ref_flag = true
            ci.before_run do
              ::Toys::TestHelper.stub_changed_files(self, "shabase12345678", ["foo/hello.rb", "what.rb"])
            end
          end
        end
      end

      out, _err = capture_subprocess_io do
        assert_equal(0, cli.run("ci", "--base-ref", "shabase12345678"))
      end
      assert_includes(out, "FOO SUCCEEDED")
      assert_includes(out, "SKIPPING BECAUSE NO CHANGES FOUND: Bar")
    end

    it "checks that base_ref comes from push event" do
      cli.add_config_block(context_directory: basic_tools_dir) do
        tool "ci" do
          expand Toys::CI::Template do |ci|
            ci.tool_job("Foo", ["foo"], trigger_paths: "foo")
            ci.tool_job("Bar", ["bar"], trigger_paths: "bar")
            ci.use_github_base_ref_flag = true
            ci.before_run do
              ::Toys::TestHelper.stub_changed_files(self, "shapush1234567890", ["foo/hello.rb", "what.rb"])
            end
          end
        end
      end

      ENV["GITHUB_EVENT_NAME"] = "push"
      ENV["GITHUB_EVENT_PATH"] = push_event_path
      out, _err = capture_subprocess_io do
        assert_equal(0, cli.run("ci", "--use-github-base-ref"))
      end
      assert_includes(out, "FOO SUCCEEDED")
      assert_includes(out, "SKIPPING BECAUSE NO CHANGES FOUND: Bar")
    end

    it "checks that base_ref comes from pull_request event" do
      cli.add_config_block(context_directory: basic_tools_dir) do
        tool "ci" do
          expand Toys::CI::Template do |ci|
            ci.tool_job("Foo", ["foo"], trigger_paths: "foo")
            ci.tool_job("Bar", ["bar"], trigger_paths: "bar")
            ci.use_github_base_ref_flag = true
            ci.before_run do
              ::Toys::TestHelper.stub_changed_files(self, "shapr1234567890", ["foo/hello.rb", "what.rb"])
            end
          end
        end
      end

      ENV["GITHUB_EVENT_NAME"] = "pull_request"
      ENV["GITHUB_EVENT_PATH"] = pr_event_path
      out, _err = capture_subprocess_io do
        assert_equal(0, cli.run("ci", "--use-github-base-ref"))
      end
      assert_includes(out, "FOO SUCCEEDED")
      assert_includes(out, "SKIPPING BECAUSE NO CHANGES FOUND: Bar")
    end
  end
end
