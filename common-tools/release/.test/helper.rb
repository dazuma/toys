# frozen_string_literal: true

require "stringio"
require "logger"
require "toys/utils/exec"

module ToysReleaser
  module Tests
    def self.setup_for_github_ci
      return unless ENV["GITHUB_ACTION"]
      puts "NOTICE: Unshallowing repo for GitHub CI"
      exec_service = ::Toys::Utils::Exec.new
      exec_service.exec(["git", "fetch", "--unshallow"])
    end

    class FakeToolContext
      class FakeExit < ::StandardError
      end

      def initialize(allow_passthru_exec: false, context_directory: nil)
        @log_io = ::StringIO.new
        @console_io = ::StringIO.new
        @exec_stubs = {}
        @capture_stubs = {}
        @ruby_stubs = {}
        @capture_ruby_stubs = {}
        self.logger = ::Logger.new(@log_io)
        self.allow_passthru_exec = allow_passthru_exec
        self.context_directory = context_directory || File.dirname(File.dirname(File.dirname(__dir__)))
      end

      def console_output
        @console_io.string
      end

      def log_output
        @log_io.string
      end

      def stub_exec(cmd, result)
        (@exec_stubs[cmd] ||= []).push(result)
        self
      end

      def stub_capture(cmd, result)
        (@capture_stubs[cmd] ||= []).push(result)
        self
      end

      def stub_ruby(script, result)
        (@ruby_stubs[script] ||= []).push(result)
        self
      end

      def stub_capture_ruby(script, result)
        (@capture_ruby_stubs[script] ||= []).push(result)
        self
      end

      def allow_passthru_exec=(setting)
        @exec_service = setting ? ::Toys::Utils::Exec.new : nil
      end

      attr_accessor :logger

      attr_accessor :context_directory

      def puts(message, *_args)
        @console_io.puts(message)
        self
      end

      def exit(result)
        raise FakeExit, result.to_s
      end

      def exec(cmd, **opts, &block)
        stub_results = @exec_stubs[cmd]
        return stub_results.shift if stub_results && stub_results.size > 0
        raise "Exec stub not found for #{cmd.inspect}" unless @exec_service
        @exec_service.exec(cmd, **opts, &block)
      end

      def capture(cmd, **opts, &block)
        stub_results = @capture_stubs[cmd]
        return stub_results.shift if stub_results && stub_results.size > 0
        raise "Capture stub not found for #{cmd.inspect}" unless @exec_service
        @exec_service.capture(cmd, **opts, &block)
      end

      def ruby(script, **opts, &block)
        stub_results = @ruby_stubs[script]
        return stub_results.shift if stub_results && stub_results.size > 0
        raise "Ruby stub not found for #{script.inspect}" unless @exec_service
        @exec_service.ruby(script, **opts, &block)
      end

      def capture_ruby(script, **opts, &block)
        stub_results = @capture_ruby_stubs[script]
        return stub_results.shift if stub_results && stub_results.size > 0
        raise "Capture-Ruby stub not found for #{script.inspect}" unless @exec_service
        @exec_service.capture_ruby(script, **opts, &block)
      end

      def find_data(filename)
        File.join(context_directory, ".toys", ".data", filename)
      end
    end
  end
end

::ToysReleaser::Tests.setup_for_github_ci
