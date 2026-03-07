# frozen_string_literal: true

require "helper"

describe Toys::CI::Mixin do
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
  let(:push_event_path) { File.join(data_dir, "push-event.json") }
  let(:pr_event_path) { File.join(data_dir, "pr-event.json") }

  describe "job types" do
    it "runs a succeeding tool job" do
      cli.add_config_block(context_directory: basic_tools_dir) do
        tool "ci" do
          include Toys::CI::Mixin

          def run
            toys_ci_init
            Dir.chdir(context_directory) do
              toys_ci_tool_job("Foo", ["foo"])
            end
            toys_ci_report_results
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
          include Toys::CI::Mixin

          def run
            toys_ci_init
            Dir.chdir(context_directory) do
              toys_ci_tool_job("Bar", ["bar"])
            end
            toys_ci_report_results
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
          include Toys::CI::Mixin

          def run
            toys_ci_init
            Dir.chdir(context_directory) do
              toys_ci_cmd_job("Echo", ["echo", "CMD SUCCEEDED"])
            end
            toys_ci_report_results
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
          include Toys::CI::Mixin

          def run
            toys_ci_init
            Dir.chdir(context_directory) do
              toys_ci_cmd_job("Hoho", ["hohohohohohoho"])
            end
            toys_ci_report_results
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
          include Toys::CI::Mixin

          def run
            toys_ci_init
            Dir.chdir(context_directory) do
              toys_ci_job("Good Block") do
                puts "BLOCK SUCCEEDED"
                true
              end
            end
            toys_ci_report_results
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
          include Toys::CI::Mixin

          def run
            toys_ci_init
            Dir.chdir(context_directory) do
              toys_ci_job("Bad Block") do
                puts "BLOCK FAILED"
                false
              end
            end
            toys_ci_report_results
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

  describe "final results" do
    it "succeeds when all jobs succeed" do
      cli.add_config_block(context_directory: basic_tools_dir) do
        tool "ci" do
          include Toys::CI::Mixin

          def run
            toys_ci_init
            Dir.chdir(context_directory) do
              toys_ci_tool_job("Foo", ["foo"])
              toys_ci_cmd_job("Echo", ["echo", "CMD SUCCEEDED"])
            end
            puts "Test: toys_ci_failed_jobs = #{toys_ci_failed_jobs.size}"
            puts "Test: toys_ci_successful_jobs = #{toys_ci_successful_jobs.size}"
            puts "Test: toys_ci_skipped_jobs = #{toys_ci_skipped_jobs.size}"
            toys_ci_report_results
          end
        end
      end

      out, _err = capture_subprocess_io do
        assert_equal(0, cli.run("ci"))
      end
      assert_includes(out, "FOO SUCCEEDED")
      assert_includes(out, "SUCCEEDED: Foo")
      assert_includes(out, "CMD SUCCEEDED")
      assert_includes(out, "SUCCEEDED: Echo")
      assert_includes(out, "CI: ALL 2 RUNNABLE JOBS SUCCEEDED")
      assert_includes(out, "Test: toys_ci_failed_jobs = 0")
      assert_includes(out, "Test: toys_ci_successful_jobs = 2")
      assert_includes(out, "Test: toys_ci_skipped_jobs = 0")
    end

    it "fails when at least one of many jobs fails" do
      cli.add_config_block(context_directory: basic_tools_dir) do
        tool "ci" do
          include Toys::CI::Mixin

          def run
            toys_ci_init
            Dir.chdir(context_directory) do
              toys_ci_tool_job("Bar", ["bar"])
              toys_ci_tool_job("Foo", ["foo"])
            end
            puts "Test: toys_ci_failed_jobs = #{toys_ci_failed_jobs.size}"
            puts "Test: toys_ci_successful_jobs = #{toys_ci_successful_jobs.size}"
            puts "Test: toys_ci_skipped_jobs = #{toys_ci_skipped_jobs.size}"
            toys_ci_report_results
          end
        end
      end

      out, _err = capture_subprocess_io do
        assert_equal(1, cli.run("ci"))
      end
      assert_includes(out, "FOO SUCCEEDED")
      assert_includes(out, "SUCCEEDED: Foo")
      assert_includes(out, "BAR FAILED")
      assert_includes(out, "FAILED: Bar")
      assert_includes(out, "CI: FAILED 1 OF 2 RUNNABLE JOBS")
      assert_includes(out, "Test: toys_ci_failed_jobs = 1")
      assert_includes(out, "Test: toys_ci_successful_jobs = 1")
      assert_includes(out, "Test: toys_ci_skipped_jobs = 0")
    end

    it "fails if no jobs are run" do
      cli.add_config_block(context_directory: basic_tools_dir) do
        tool "ci" do
          include Toys::CI::Mixin

          def run
            toys_ci_init
            puts "Test: toys_ci_failed_jobs = #{toys_ci_failed_jobs.size}"
            puts "Test: toys_ci_successful_jobs = #{toys_ci_successful_jobs.size}"
            puts "Test: toys_ci_skipped_jobs = #{toys_ci_skipped_jobs.size}"
            toys_ci_report_results
          end
        end
      end

      out, _err = capture_subprocess_io do
        assert_equal(2, cli.run("ci"))
      end
      assert_includes(out, "CI: NO JOBS REQUESTED")
      assert_includes(out, "Test: toys_ci_failed_jobs = 0")
      assert_includes(out, "Test: toys_ci_successful_jobs = 0")
      assert_includes(out, "Test: toys_ci_skipped_jobs = 0")
    end

    it "returns 0 on success when exit: false is passed" do
      cli.add_config_block(context_directory: basic_tools_dir) do
        tool "ci" do
          include Toys::CI::Mixin

          def run
            toys_ci_init
            Dir.chdir(context_directory) do
              toys_ci_tool_job("Foo", ["foo"])
              toys_ci_cmd_job("Echo", ["echo", "CMD SUCCEEDED"])
            end
            result = toys_ci_report_results(exit: false)
            puts "Result: #{result}"
          end
        end
      end

      out, _err = capture_subprocess_io do
        assert_equal(0, cli.run("ci"))
      end
      assert_includes(out, "CI: ALL 2 RUNNABLE JOBS SUCCEEDED")
      assert_includes(out, "Result: 0")
    end

    it "returns 1 on failure when exit: false is passed" do
      cli.add_config_block(context_directory: basic_tools_dir) do
        tool "ci" do
          include Toys::CI::Mixin

          def run
            toys_ci_init
            Dir.chdir(context_directory) do
              toys_ci_tool_job("Bar", ["bar"])
              toys_ci_tool_job("Foo", ["foo"])
            end
            result = toys_ci_report_results(exit: false)
            puts "Result: #{result}"
          end
        end
      end

      out, _err = capture_subprocess_io do
        assert_equal(0, cli.run("ci"))
      end
      assert_includes(out, "CI: FAILED 1 OF 2 RUNNABLE JOBS")
      assert_includes(out, "Result: 1")
    end

    it "returns 2 when no jobs are run and exit: false is passed" do
      cli.add_config_block(context_directory: basic_tools_dir) do
        tool "ci" do
          include Toys::CI::Mixin

          def run
            toys_ci_init
            result = toys_ci_report_results(exit: false)
            puts "Result: #{result}"
          end
        end
      end

      out, _err = capture_subprocess_io do
        assert_equal(0, cli.run("ci"))
      end
      assert_includes(out, "CI: NO JOBS REQUESTED")
      assert_includes(out, "Result: 2")
    end

    it "handles fail-fast" do
      cli.add_config_block(context_directory: basic_tools_dir) do
        tool "ci" do
          include Toys::CI::Mixin

          def run
            toys_ci_init(fail_fast: true)
            Dir.chdir(context_directory) do
              toys_ci_tool_job("Bar", ["bar"])
              toys_ci_tool_job("Foo", ["foo"])
            end
            toys_ci_report_results
          end
        end
      end

      out, _err = capture_subprocess_io do
        assert_equal(1, cli.run("ci"))
      end
      refute_includes(out, "FOO SUCCEEDED")
      assert_includes(out, "BAR FAILED")
      assert_includes(out, "FAILED: Bar")
      assert_includes(out, "TERMINATING CI")
    end

    it "handles jobs with no trigger path" do
      cli.add_config_block(context_directory: basic_tools_dir) do
        tool "ci" do
          include Toys::CI::Mixin

          def run
            Toys::TestHelper.stub_changed_files(self, "mybranch", []) do
              toys_ci_init(limit_by_changes_since: "mybranch")
            end
            Dir.chdir(context_directory) do
              toys_ci_tool_job("Foo", ["foo"])
            end
            toys_ci_report_results
          end
        end
      end

      out, _err = capture_subprocess_io do
        assert_equal(0, cli.run("ci"))
      end
      assert_includes(out, "FOO SUCCEEDED")
    end

    it "filters jobs based on matching trigger directory" do
      cli.add_config_block(context_directory: basic_tools_dir) do
        tool "ci" do
          include Toys::CI::Mixin

          def run
            changed_files = ["foo/hi.rb", "foo/ho.rb"]
            Toys::TestHelper.stub_changed_files(self, "mybranch", changed_files) do
              toys_ci_init(limit_by_changes_since: "mybranch")
            end
            Dir.chdir(context_directory) do
              toys_ci_tool_job("Foo", ["foo"], trigger_paths: "foo")
              toys_ci_tool_job("Bar", ["bar"], trigger_paths: "bar")
            end
            toys_ci_report_results
          end
        end
      end

      out, _err = capture_subprocess_io do
        assert_equal(0, cli.run("ci"))
      end
      assert_includes(out, "FOO SUCCEEDED")
      assert_includes(out, "SKIPPING BECAUSE NO CHANGES FOUND: Bar")
      assert_includes(out, "CI: SKIPPED 1 OF 2 JOBS")
      assert_includes(out, "CI: ALL 1 RUNNABLE JOBS SUCCEEDED")
    end

    it "filters jobs based on matching trigger file" do
      cli.add_config_block(context_directory: basic_tools_dir) do
        tool "ci" do
          include Toys::CI::Mixin

          def run
            changed_files = ["foo/hi.rb", "foo/ho.rb"]
            Toys::TestHelper.stub_changed_files(self, "mybranch", changed_files) do
              toys_ci_init(limit_by_changes_since: "mybranch")
            end
            Dir.chdir(context_directory) do
              toys_ci_tool_job("Foo", ["foo"], trigger_paths: "foo/ho.rb")
              toys_ci_tool_job("Bar", ["bar"], trigger_paths: "bar")
            end
            toys_ci_report_results
          end
        end
      end

      out, _err = capture_subprocess_io do
        assert_equal(0, cli.run("ci"))
      end
      assert_includes(out, "FOO SUCCEEDED")
      assert_includes(out, "SKIPPING BECAUSE NO CHANGES FOUND: Bar")
      assert_includes(out, "CI: SKIPPED 1 OF 2 JOBS")
      assert_includes(out, "CI: ALL 1 RUNNABLE JOBS SUCCEEDED")
    end

    it "skips all jobs" do
      cli.add_config_block(context_directory: basic_tools_dir) do
        tool "ci" do
          include Toys::CI::Mixin

          def run
            changed_files = ["foo/hi.rb", "foo/ho.rb"]
            Toys::TestHelper.stub_changed_files(self, "mybranch", changed_files) do
              toys_ci_init(limit_by_changes_since: "mybranch")
            end
            Dir.chdir(context_directory) do
              toys_ci_tool_job("Foo", ["foo"], trigger_paths: "foo/wha.rb")
              toys_ci_tool_job("Bar", ["bar"], trigger_paths: "bar")
            end
            toys_ci_report_results
          end
        end
      end

      out, _err = capture_subprocess_io do
        assert_equal(0, cli.run("ci"))
      end
      assert_includes(out, "SKIPPING BECAUSE NO CHANGES FOUND: Foo")
      assert_includes(out, "SKIPPING BECAUSE NO CHANGES FOUND: Bar")
      assert_includes(out, "CI: ALL 2 JOBS SKIPPED")
    end
  end

  describe "toys_ci_github_event_base_sha" do
    it "loads a push event" do
      test_case = self

      cli.add_config_block(context_directory: basic_tools_dir) do
        tool "ci" do
          include Toys::CI::Mixin

          static :event_path, test_case.push_event_path

          def run
            puts toys_ci_github_event_base_sha("push", event_path).inspect
          end
        end
      end

      out, _err = capture_subprocess_io do
        assert_equal(0, cli.run("ci"))
      end
      assert_includes(out, '"shapush1234567890"')
    end

    it "loads a pull request event" do
      test_case = self

      cli.add_config_block(context_directory: basic_tools_dir) do
        tool "ci" do
          include Toys::CI::Mixin

          static :event_path, test_case.pr_event_path

          def run
            puts toys_ci_github_event_base_sha("pull_request", event_path).inspect
          end
        end
      end

      out, _err = capture_subprocess_io do
        assert_equal(0, cli.run("ci"))
      end
      assert_includes(out, '"shapr1234567890"')
    end

    it "catches wrong event type" do
      test_case = self

      cli.add_config_block(context_directory: basic_tools_dir) do
        tool "ci" do
          include Toys::CI::Mixin

          static :event_path, test_case.pr_event_path

          def run
            puts toys_ci_github_event_base_sha("pull_request_target", event_path).inspect
          end
        end
      end

      out, _err = capture_subprocess_io do
        assert_equal(0, cli.run("ci"))
      end
      assert_includes(out, "nil")
    end

    it "catches no such file" do
      test_case = self

      cli.add_config_block(context_directory: basic_tools_dir) do
        tool "ci" do
          include Toys::CI::Mixin

          static :event_path, test_case.basic_tools_dir

          def run
            puts toys_ci_github_event_base_sha("pull_request_target", event_path).inspect
          end
        end
      end

      out, _err = capture_subprocess_io do
        assert_equal(0, cli.run("ci"))
      end
      assert_includes(out, "nil")
    end
  end
end
