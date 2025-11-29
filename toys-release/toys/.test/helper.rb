# frozen_string_literal: true

require "minitest/autorun"
require "minitest/focus"
require "minitest/rg"

require "stringio"
require "logger"

require "toys-core"
require "toys/utils/exec"
require "toys/standard_mixins/exec"

$LOAD_PATH.unshift(::File.join(::File.dirname(__dir__), ".lib"))

require "toys/release/artifact_dir"
require "toys/release/change_set"
require "toys/release/changelog_file"
require "toys/release/component"
require "toys/release/environment_utils"
require "toys/release/performer"
require "toys/release/pipeline"
require "toys/release/pull_request"
require "toys/release/repo_settings"
require "toys/release/repository"
require "toys/release/request_logic"
require "toys/release/request_spec"
require "toys/release/semver"
require "toys/release/steps"
require "toys/release/version_rb_file"

module Toys
  module Release
    module Tests
      REPO_DIR = ::File.dirname(::File.dirname(::File.dirname(__dir__)))

      def self.setup
        if ::ENV["GITHUB_ACTION"]
          puts "NOTICE: Unshallowing repo for GitHub CI"
          exec_service = ::Toys::Utils::Exec.new
          exec_service.exec(["git", "fetch", "--unshallow"])
        end

        # Intentionally clobber keys to ensure the tests don't accidentally
        # push real releases.
        ::ENV["GEM_HOST_API_KEY"] = "this_key_does_not_work"

        # Signals to the releaser that we're just testing and shouldn't output
        # releaser errors using the github action syntax.
        ::ENV["TOYS_RELEASER_TESTING"] = "true"

        # Some tests require the toys executable. Ensure we have a path to it
        # when running the tests in a raw Ruby process.
        ::Toys.executable_path ||= ::ENV["TOYS_BIN_PATH"] || ::File.join(REPO_DIR, "toys", "bin", "toys")
      end

      FakePullRequest = ::Struct.new(:merge_commit_sha, :head_ref, keyword_init: true)

      class FakeToolContext
        class FakeExit < ::StandardError
        end

        class ResultInfo
          FakeStatus = ::Struct.new(:exitstatus, :termsig)

          def initialize(result_code, console_output: "", captured_output: nil, block: nil)
            status = FakeStatus.new(result_code)
            @result = Toys::Utils::Exec::Result.new("", captured_output, nil, status, nil)
            @console_output = console_output
            @block = block
          end

          attr_reader :result
          attr_reader :console_output

          def call
            @block&.call
          end

          def self.create(result_code, output: "", block: nil)
            new(result_code, console_output: output, block: block)
          end

          def self.create_capture(result_code, output: "", block: nil)
            new(result_code, captured_output: output, block: block)
          end
        end

        def initialize(allow_passthru_exec: false, context_directory: nil)
          @log_io = ::StringIO.new
          @console_io = ::StringIO.new
          @exec_stubs = {}
          @capture_stubs = {}
          @ruby_stubs = {}
          @capture_ruby_stubs = {}
          @separate_tool_stubs = {}
          @prevent_real_exec_prefixes = []
          self.logger = ::Logger.new(@log_io)
          self.logger.level = ::Logger::INFO
          self.allow_passthru_exec = allow_passthru_exec
          self.context_directory = context_directory || REPO_DIR
          self.repo_root_directory = REPO_DIR
        end

        attr_accessor :logger

        attr_accessor :context_directory

        attr_accessor :repo_root_directory

        def puts(message, *_args)
          @console_io.puts(message)
          self
        end

        def exit(result)
          raise FakeExit, result.to_s
        end

        def exec(cmd, **opts, &block)
          stub_check_results("exec_stubs", cmd) do
            @exec_service.exec(cmd, **opts, &block)
          end
        end

        def capture(cmd, **opts, &block)
          stub_check_results("capture_stubs", cmd, capture: true) do
            @exec_service.capture(cmd, **opts, &block)
          end
        end

        def ruby(script, **opts, &block)
          stub_check_results("ruby_stubs", script) do
            @exec_service.ruby(script, **opts, &block)
          end
        end

        def capture_ruby(script, **opts, &block)
          stub_check_results("capture_ruby_stubs", script, capture: true) do
            @exec_service.capture_ruby(script, **opts, &block)
          end
        end

        def exec_separate_tool(tool, **opts, &block)
          stub_check_results("separate_tool_stubs", tool) do
            Toys::StandardMixins::Exec._setup_clean_process(tool) do |command|
              @exec_service.exec(command, **opts, &block)
            end
          end
        end

        def find_data(filename)
          File.join(context_directory, ".toys", ".data", filename)
        end

        # Stubbing-related tools

        def console_output
          @console_io.string
        end

        def log_output
          @log_io.string
        end

        def allow_passthru_exec=(setting)
          @exec_service = setting ? ::Toys::Utils::Exec.new : nil
        end

        def stub_exec(cmd, result_code: 0, output: "", &block)
          (@exec_stubs[cmd] ||= []).push(ResultInfo.create(result_code, output: output, block: block))
          self
        end

        def stub_capture(cmd, result_code: 0, output: "", &block)
          (@capture_stubs[cmd] ||= []).push(ResultInfo.create_capture(result_code, output: output, block: block))
          self
        end

        def stub_ruby(script, result_code: 0, output: "", &block)
          (@ruby_stubs[script] ||= []).push(ResultInfo.create(result_code, output: output, block: block))
          self
        end

        def stub_capture_ruby(script, result_code: 0, output: "", &block)
          (@capture_ruby_stubs[script] ||= []).push(
            ResultInfo.create_capture(result_code, output: output, block: block)
          )
          self
        end

        def stub_separate_tool(tool, result_code: 0, output: "", &block)
          (@separate_tool_stubs[tool] ||= []).push(ResultInfo.create(result_code, output: output, block: block))
          self
        end

        def stub_check_results(name, cmd, capture: false)
          stub_results = instance_variable_get("@#{name}")[cmd]
          if stub_results && !stub_results.empty?
            result_info = stub_results.shift
            result_info.call
            @console_io.puts(result_info.console_output)
            capture ? result_info.result.captured_out : result_info.result
          else
            raise "#{name} not found for #{cmd.inspect}" unless @exec_service
            @prevent_real_exec_prefixes.each do |prefix|
              raise "Prevented real exec of #{cmd.inspect}" if cmd[0...prefix.size] == prefix
            end
            yield
          end
        end

        def prevent_real_exec_prefix(prefix)
          @prevent_real_exec_prefixes << prefix
        end
      end
    end
  end
end

::Toys::Release::Tests.setup
