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
    # You can set default configuration by passing options to the `include`
    # directive. For example, to log commands at the debug level for all
    # subprocesses spawned by this tool:
    #
    #     include :exec, log_level: Logger::DEBUG
    #
    # Two special options are also recognized by the mixin.
    #
    # *  A **:result_callback** proc may take a second argument. If it does,
    #    the tool object is passed as the second argument. This is useful if a
    #    `:result_callback` is applied to the entire tool by passing it to the
    #    `include` directive. In that case, the tool object is not otherwise in
    #    scope, so you cannot access it otherwise. For example, here is how to
    #    log the exit code for every subcommand:
    #
    #        callback = proc do |result, tool|
    #          tool.logger.info "Exit code: #{result.exit_code}"
    #        end
    #        include :exec, result_callback: callback
    #
    #    You may also pass a symbol as the `:result_callback`. The method with
    #    that name is then called as the callback. The method must take one
    #    argument, the result object.
    #
    # *  If **:exit_on_nonzero_status** is set to true, a nonzero exit code
    #    returned by the subprocess will also cause the tool to exit
    #    immediately with that same code.
    #
    #    This is particularly useful as an option to the `include` directive,
    #    where it causes any subprocess failure to abort the tool, similar to
    #    setting `set -e` in a bash script.
    #
    #        include :exec, exit_on_nonzero_status: true
    #
    module Exec
      include Mixin

      ##
      # Context key for the executor object.
      # @return [Object]
      #
      KEY = ::Object.new.freeze

      to_initialize do |opts = {}|
        require "toys/utils/exec"
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
        if opts.key?(:exit_on_nonzero_status)
          result_callback =
            if opts[:exit_on_nonzero_status]
              proc { |r| tool.exit(r.exit_code) if r.error? }
            end
          opts = opts.merge(result_callback: result_callback)
          opts.delete(:exit_on_nonzero_status)
        elsif opts.key?(:result_callback)
          orig_callback = opts[:result_callback]
          result_callback =
            if orig_callback.is_a?(::Symbol)
              tool.method(orig_callback)
            elsif orig_callback.respond_to?(:call)
              proc { |r| orig_callback.call(r, tool) }
            end
          opts = opts.merge(result_callback: result_callback)
        end
        opts
      end
    end
  end
end
