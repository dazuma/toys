# frozen_string_literal: true

# Copyright 2019 Daniel Azuma
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.
;

require "toys/utils/exec"

module Toys
  module StandardMixins
    ##
    # A set of helper methods for invoking subcommands. Provides shortcuts for
    # common cases such as invoking Ruby in a subprocess or capturing output
    # in a string. Also provides an interface for controlling a spawned
    # process's streams.
    #
    # You may make these methods available to your tool by including the
    # following directive in your tool configuration:
    #
    #     include :exec
    #
    # This is a frontend for {Toys::Utils::Exec}. More information is
    # available in that class's documentation.
    #
    # ## Configuration Options
    #
    # Subprocesses may be configured using the options in the
    # {Toys::Utils::Exec} class. These include a variety of options supported
    # by `Process#spawn`, and some options supported by {Toys::Utils::Exec}
    # itself.
    #
    # In addition, this mixin supports one more option,
    # `exit_on_nonzero_status`. When set to true, if any subprocess returns a
    # nonzero result code, the tool will immediately exit with that same code,
    # similar to `set -e` in a bash script.
    #
    # You can set initial configuration by passing options to the `include`
    # directive. For example:
    #
    #     include :exec, exit_on_nonzero_status: true
    #
    module Exec
      include Mixin

      ##
      # Context key for the executor object.
      # @return [Object]
      #
      KEY = ::Object.new.freeze

      to_initialize do |opts = {}|
        tool = self
        opts = Exec._setup_exec_opts(opts, tool)
        tool[KEY] = Utils::Exec.new(opts) do |k|
          case k
          when :logger
            tool[Tool::Keys::LOGGER]
          when :cli
            tool[Tool::Keys::CLI]
          end
        end
      end

      ##
      # Set default configuration keys.
      #
      # All options listed in the {Toys::Utils::Exec} documentation are
      # supported, plus the `exit_on_nonzero_status` option.
      #
      # @param [Hash] opts The default options.
      #
      def configure_exec(opts = {})
        self[KEY].configure_defaults(Exec._setup_exec_opts(opts, self))
      end

      ##
      # Execute a command. The command may be given as a single string to pass
      # to a shell, or an array of strings indicating a posix command.
      #
      # If the process is not set to run in the background, and a block is
      # provided, a {Toys::Utils::Exec::Controller} will be yielded to it.
      #
      # @param [String,Array<String>] cmd The command to execute.
      # @param [Hash] opts The command options. All options listed in the
      #     {Toys::Utils::Exec} documentation are supported, plus the
      #     `exit_on_nonzero_status` option.
      # @yieldparam controller [Toys::Utils::Exec::Controller] A controller for
      #     the subprocess streams.
      #
      # @return [Toys::Utils::Exec::Controller,Toys::Utils::Exec::Result] The
      #     subprocess controller or result, depending on whether the process
      #     is running in the background or foreground.
      #
      def exec(cmd, opts = {}, &block)
        self[KEY].exec(cmd, Exec._setup_exec_opts(opts, self), &block)
      end

      ##
      # Spawn a ruby process and pass the given arguments to it.
      #
      # If the process is not set to run in the background, and a block is
      # provided, a {Toys::Utils::Exec::Controller} will be yielded to it.
      #
      # @param [String,Array<String>] args The arguments to ruby.
      # @param [Hash] opts The command options. All options listed in the
      #     {Toys::Utils::Exec} documentation are supported, plus the
      #     `exit_on_nonzero_status` option.
      # @yieldparam controller [Toys::Utils::Exec::Controller] A controller for
      #     for the subprocess streams.
      #
      # @return [Toys::Utils::Exec::Controller,Toys::Utils::Exec::Result] The
      #     subprocess controller or result, depending on whether the process
      #     is running in the background or foreground.
      #
      def exec_ruby(args, opts = {}, &block)
        self[KEY].exec_ruby(args, Exec._setup_exec_opts(opts, self), &block)
      end
      alias ruby exec_ruby

      ##
      # Execute a proc in a subprocess.
      #
      # If the process is not set to run in the background, and a block is
      # provided, a {Toys::Utils::Exec::Controller} will be yielded to it.
      #
      # @param [Proc] func The proc to call.
      # @param [Hash] opts The command options. Most options listed in the
      #     {Toys::Utils::Exec} documentation are supported, plus the
      #     `exit_on_nonzero_status` option.
      # @yieldparam controller [Toys::Utils::Exec::Controller] A controller
      #     for the subprocess streams.
      #
      # @return [Toys::Utils::Exec::Controller,Toys::Utils::Exec::Result] The
      #     subprocess controller or result, depending on whether the process
      #     is running in the background or foreground.
      #
      def exec_proc(func, opts = {}, &block)
        self[KEY].exec_proc(func, Exec._setup_exec_opts(opts, self), &block)
      end

      ##
      # Execute a tool. The command may be given as a single string or an array
      # of strings, representing the tool to run and the arguments to pass.
      #
      # If the process is not set to run in the background, and a block is
      # provided, a {Toys::Utils::Exec::Controller} will be yielded to it.
      #
      # @param [String,Array<String>] cmd The tool to execute.
      # @param [Hash] opts The command options. Most options listed in the
      #     {Toys::Utils::Exec} documentation are supported, plus the
      #     `exit_on_nonzero_status` option.
      # @yieldparam controller [Toys::Utils::Exec::Controller] A controller
      #     for the subprocess streams.
      #
      # @return [Toys::Utils::Exec::Controller,Toys::Utils::Exec::Result] The
      #     subprocess controller or result, depending on whether the process
      #     is running in the background or foreground.
      #
      def exec_tool(cmd, opts = {}, &block)
        func = Exec._make_tool_caller(cmd)
        self[KEY].exec_proc(func, Exec._setup_exec_opts(opts, self), &block)
      end

      ##
      # Execute a command. The command may be given as a single string to pass
      # to a shell, or an array of strings indicating a posix command.
      #
      # Captures standard out and returns it as a string.
      # Cannot be run in the background.
      #
      # If a block is provided, a {Toys::Utils::Exec::Controller} will be
      # yielded to it.
      #
      # @param [String,Array<String>] cmd The command to execute.
      # @param [Hash] opts The command options. All options listed in the
      #     {Toys::Utils::Exec} documentation are supported, plus the
      #     `exit_on_nonzero_status` option.
      # @yieldparam controller [Toys::Utils::Exec::Controller] A controller
      #     for the subprocess streams.
      #
      # @return [String] What was written to standard out.
      #
      def capture(cmd, opts = {}, &block)
        self[KEY].capture(cmd, Exec._setup_exec_opts(opts, self), &block)
      end

      ##
      # Spawn a ruby process and pass the given arguments to it.
      #
      # Captures standard out and returns it as a string.
      # Cannot be run in the background.
      #
      # If a block is provided, a {Toys::Utils::Exec::Controller} will be
      # yielded to it.
      #
      # @param [String,Array<String>] args The arguments to ruby.
      # @param [Hash] opts The command options. All options listed in the
      #     {Toys::Utils::Exec} documentation are supported, plus the
      #     `exit_on_nonzero_status` option.
      # @yieldparam controller [Toys::Utils::Exec::Controller] A controller
      #     for the subprocess streams.
      #
      # @return [String] What was written to standard out.
      #
      def capture_ruby(args, opts = {}, &block)
        self[KEY].capture_ruby(args, Exec._setup_exec_opts(opts, self), &block)
      end

      ##
      # Execute a proc in a subprocess.
      #
      # Captures standard out and returns it as a string.
      # Cannot be run in the background.
      #
      # If a block is provided, a {Toys::Utils::Exec::Controller} will be
      # yielded to it.
      #
      # @param [Proc] func The proc to call.
      # @param [Hash] opts The command options. Most options listed in the
      #     {Toys::Utils::Exec} documentation are supported, plus the
      #     `exit_on_nonzero_status` option.
      # @yieldparam controller [Toys::Utils::Exec::Controller] A controller
      #     for the subprocess streams.
      #
      # @return [String] What was written to standard out.
      #
      def capture_proc(func, opts = {}, &block)
        self[KEY].capture_proc(func, Exec._setup_exec_opts(opts, self), &block)
      end

      ##
      # Execute a tool. The command may be given as a single string or an array
      # of strings, representing the tool to run and the arguments to pass.
      #
      # Captures standard out and returns it as a string.
      # Cannot be run in the background.
      #
      # If a block is provided, a {Toys::Utils::Exec::Controller} will be
      # yielded to it.
      #
      # @param [String,Array<String>] cmd The tool to execute.
      # @param [Hash] opts The command options. Most options listed in the
      #     {Toys::Utils::Exec} documentation are supported, plus the
      #     `exit_on_nonzero_status` option.
      # @yieldparam controller [Toys::Utils::Exec::Controller] A controller
      #     for the subprocess streams.
      #
      # @return [String] What was written to standard out.
      #
      def capture_tool(cmd, opts = {}, &block)
        func = Exec._make_tool_caller(cmd)
        self[KEY].capture_proc(func, Exec._setup_exec_opts(opts, self), &block)
      end

      ##
      # Execute the given string in a shell. Returns the exit code.
      # Cannot be run in the background.
      #
      # If a block is provided, a {Toys::Utils::Exec::Controller} will be
      # yielded to it.
      #
      # @param [String] cmd The shell command to execute.
      # @param [Hash] opts The command options. All options listed in the
      #     {Toys::Utils::Exec} documentation are supported, plus the
      #     `exit_on_nonzero_status` option.
      # @yieldparam controller [Toys::Utils::Exec::Controller] A controller
      #     for the subprocess streams.
      #
      # @return [Integer] The exit code
      #
      def sh(cmd, opts = {}, &block)
        self[KEY].sh(cmd, Exec._setup_exec_opts(opts, self), &block)
      end

      ##
      # Exit if the given status code is nonzero. Otherwise, returns 0.
      #
      # @param [Integer,Process::Status,Toys::Utils::Exec::Result] status
      #
      def exit_on_nonzero_status(status)
        status = status.exit_code if status.respond_to?(:exit_code)
        status = status.exitstatus if status.respond_to?(:exitstatus)
        Tool.exit(status) unless status.zero?
        0
      end

      ## @private
      def self._make_tool_caller(cmd)
        cmd = ::Shellwords.split(cmd) if cmd.is_a?(::String)
        proc { |config| ::Kernel.exit(config[:cli].run(*cmd)) }
      end

      ## @private
      def self._setup_exec_opts(opts, tool)
        return opts unless opts.key?(:exit_on_nonzero_status)
        nonzero_status_handler =
          if opts[:exit_on_nonzero_status]
            proc { |s| tool.exit(s.exitstatus) }
          end
        opts = opts.merge(nonzero_status_handler: nonzero_status_handler)
        opts.delete(:exit_on_nonzero_status)
        opts
      end
    end
  end
end
