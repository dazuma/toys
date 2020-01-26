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
    #  *  A **:result_callback** proc may take a second argument. If it does,
    #     the context object is passed as the second argument. This is useful
    #     if a `:result_callback` is applied to the entire tool by passing it
    #     to the `include` directive. In that case, `self` is not set to the
    #     context object as it normally would be in a tool's `run` method, so
    #     you cannot access it otherwise. For example, here is how to log the
    #     exit code for every subcommand:
    #
    #         tool "mytool" do
    #           callback = proc do |result, context|
    #             context.logger.info "Exit code: #{result.exit_code}"
    #           end
    #           include :exec, result_callback: callback
    #           # ...
    #         end
    #
    #     You may also pass a symbol as the `:result_callback`. The method with
    #     that name is then called as the callback. The method must take one
    #     argument, the result object.
    #
    #  *  If **:exit_on_nonzero_status** is set to true, a nonzero exit code
    #     returned by the subprocess will also cause the tool to exit
    #     immediately with that same code.
    #
    #     This is particularly useful as an option to the `include` directive,
    #     where it causes any subprocess failure to abort the tool, similar to
    #     setting `set -e` in a bash script.
    #
    #         include :exec, exit_on_nonzero_status: true
    #
    #     **:e** can be used as a shortcut for **:exit_on_nonzero_status**
    #
    #         include :exec, e: true
    #
    module Exec
      include Mixin

      ##
      # Context key for the executor object.
      # @return [Object]
      #
      KEY = ::Object.new.freeze

      on_initialize do |**opts|
        require "toys/utils/exec"
        context = self
        opts = Exec._setup_exec_opts(opts, context)
        context[KEY] = Utils::Exec.new(**opts) do |k|
          case k
          when :logger
            context[Context::Key::LOGGER]
          when :cli
            context[Context::Key::CLI]
          end
        end
      end

      ##
      # Set default configuration keys.
      #
      # All options listed in the {Toys::Utils::Exec} documentation are
      # supported, plus the `exit_on_nonzero_status` option.
      #
      # @param opts [keywords] The default options.
      # @return [self]
      #
      def configure_exec(**opts)
        opts = Exec._setup_exec_opts(opts, self)
        self[KEY].configure_defaults(**opts)
        self
      end

      ##
      # Execute a command. The command may be given as a single string to pass
      # to a shell, or an array of strings indicating a posix command.
      #
      # If the process is not set to run in the background, and a block is
      # provided, a {Toys::Utils::Exec::Controller} will be yielded to it.
      #
      # @param cmd [String,Array<String>] The command to execute.
      # @param opts [keywords] The command options. All options listed in the
      #     {Toys::Utils::Exec} documentation are supported, plus the
      #     `exit_on_nonzero_status` option.
      # @yieldparam controller [Toys::Utils::Exec::Controller] A controller for
      #     the subprocess streams.
      #
      # @return [Toys::Utils::Exec::Controller] The subprocess controller, if
      #     the process is running in the background.
      # @return [Toys::Utils::Exec::Result] The result, if the process ran in
      #     the foreground.
      #
      def exec(cmd, **opts, &block)
        opts = Exec._setup_exec_opts(opts, self)
        self[KEY].exec(cmd, **opts, &block)
      end

      ##
      # Spawn a ruby process and pass the given arguments to it.
      #
      # If the process is not set to run in the background, and a block is
      # provided, a {Toys::Utils::Exec::Controller} will be yielded to it.
      #
      # @param args [String,Array<String>] The arguments to ruby.
      # @param opts [keywords] The command options. All options listed in the
      #     {Toys::Utils::Exec} documentation are supported, plus the
      #     `exit_on_nonzero_status` option.
      # @yieldparam controller [Toys::Utils::Exec::Controller] A controller for
      #     for the subprocess streams.
      #
      # @return [Toys::Utils::Exec::Controller] The subprocess controller, if
      #     the process is running in the background.
      # @return [Toys::Utils::Exec::Result] The result, if the process ran in
      #     the foreground.
      #
      def exec_ruby(args, **opts, &block)
        opts = Exec._setup_exec_opts(opts, self)
        self[KEY].exec_ruby(args, **opts, &block)
      end
      alias ruby exec_ruby

      ##
      # Execute a proc in a forked subprocess.
      #
      # If the process is not set to run in the background, and a block is
      # provided, a {Toys::Utils::Exec::Controller} will be yielded to it.
      #
      # Beware that some Ruby environments (e.g. JRuby, and Ruby on Windows)
      # do not support this method because they do not support fork.
      #
      # @param func [Proc] The proc to call.
      # @param opts [keywords] The command options. Most options listed in the
      #     {Toys::Utils::Exec} documentation are supported, plus the
      #     `exit_on_nonzero_status` option.
      # @yieldparam controller [Toys::Utils::Exec::Controller] A controller
      #     for the subprocess streams.
      #
      # @return [Toys::Utils::Exec::Controller] The subprocess controller, if
      #     the process is running in the background.
      # @return [Toys::Utils::Exec::Result] The result, if the process ran in
      #     the foreground.
      #
      def exec_proc(func, **opts, &block)
        opts = Exec._setup_exec_opts(opts, self)
        self[KEY].exec_proc(func, **opts, &block)
      end

      ##
      # Execute a tool in the current CLI in a forked process.
      #
      # The command may be given as a single string or an array of strings,
      # representing the tool to run and the arguments to pass.
      #
      # If the process is not set to run in the background, and a block is
      # provided, a {Toys::Utils::Exec::Controller} will be yielded to it.
      #
      # Beware that some Ruby environments (e.g. JRuby, and Ruby on Windows)
      # do not support this method because they do not support fork.
      #
      # @param cmd [String,Array<String>] The tool to execute.
      # @param opts [keywords] The command options. Most options listed in the
      #     {Toys::Utils::Exec} documentation are supported, plus the
      #     `exit_on_nonzero_status` option.
      # @yieldparam controller [Toys::Utils::Exec::Controller] A controller
      #     for the subprocess streams.
      #
      # @return [Toys::Utils::Exec::Controller] The subprocess controller, if
      #     the process is running in the background.
      # @return [Toys::Utils::Exec::Result] The result, if the process ran in
      #     the foreground.
      #
      def exec_tool(cmd, **opts, &block)
        func = Exec._make_tool_caller(cmd)
        opts = Exec._setup_exec_opts(opts, self)
        self[KEY].exec_proc(func, **opts, &block)
      end

      ##
      # Execute a tool in a separately spawned process.
      #
      # The command may be given as a single string or an array of strings,
      # representing the tool to run and the arguments to pass.
      #
      # If the process is not set to run in the background, and a block is
      # provided, a {Toys::Utils::Exec::Controller} will be yielded to it.
      #
      # An entirely separate spawned process is run for this tool, using the
      # setting of {Toys.executable_path}. Thus, this method can be run only if
      # that setting is present. The normal Toys gem does set it, but if you
      # are writing your own executable using Toys-Core, you will need to set
      # it explicitly for this method to work. Furthermore, Bundler, if
      # present, is reset to its "unbundled" environment. Thus, the tool found,
      # the behavior of the CLI, and the gem environment, might not be the same
      # as those of the calling tool.
      #
      # This method is often used if you are already in a bundle and need to
      # run a tool that uses a different bundle. It may also be necessary on
      # environments without "fork" (such as JRuby or Ruby on Windows).
      #
      # @param cmd [String,Array<String>] The tool to execute.
      # @param opts [keywords] The command options. Most options listed in the
      #     {Toys::Utils::Exec} documentation are supported, plus the
      #     `exit_on_nonzero_status` option.
      # @yieldparam controller [Toys::Utils::Exec::Controller] A controller
      #     for the subprocess streams.
      #
      # @return [Toys::Utils::Exec::Controller] The subprocess controller, if
      #     the process is running in the background.
      # @return [Toys::Utils::Exec::Result] The result, if the process ran in
      #     the foreground.
      #
      def exec_separate_tool(cmd, **opts, &block)
        Exec._setup_clean_process(cmd) do |clean_cmd|
          exec(clean_cmd, **opts, &block)
        end
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
      # @param cmd [String,Array<String>] The command to execute.
      # @param opts [keywords] The command options. All options listed in the
      #     {Toys::Utils::Exec} documentation are supported, plus the
      #     `exit_on_nonzero_status` option.
      # @yieldparam controller [Toys::Utils::Exec::Controller] A controller
      #     for the subprocess streams.
      #
      # @return [String] What was written to standard out.
      #
      def capture(cmd, **opts, &block)
        opts = Exec._setup_exec_opts(opts, self)
        self[KEY].capture(cmd, **opts, &block)
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
      # @param args [String,Array<String>] The arguments to ruby.
      # @param opts [keywords] The command options. All options listed in the
      #     {Toys::Utils::Exec} documentation are supported, plus the
      #     `exit_on_nonzero_status` option.
      # @yieldparam controller [Toys::Utils::Exec::Controller] A controller
      #     for the subprocess streams.
      #
      # @return [String] What was written to standard out.
      #
      def capture_ruby(args, **opts, &block)
        opts = Exec._setup_exec_opts(opts, self)
        self[KEY].capture_ruby(args, **opts, &block)
      end

      ##
      # Execute a proc in a forked subprocess.
      #
      # Captures standard out and returns it as a string.
      # Cannot be run in the background.
      #
      # If a block is provided, a {Toys::Utils::Exec::Controller} will be
      # yielded to it.
      #
      # Beware that some Ruby environments (e.g. JRuby, and Ruby on Windows)
      # do not support this method because they do not support fork.
      #
      # @param func [Proc] The proc to call.
      # @param opts [keywords] The command options. Most options listed in the
      #     {Toys::Utils::Exec} documentation are supported, plus the
      #     `exit_on_nonzero_status` option.
      # @yieldparam controller [Toys::Utils::Exec::Controller] A controller
      #     for the subprocess streams.
      #
      # @return [String] What was written to standard out.
      #
      def capture_proc(func, **opts, &block)
        opts = Exec._setup_exec_opts(opts, self)
        self[KEY].capture_proc(func, **opts, &block)
      end

      ##
      # Execute a tool in the current CLI in a forked process.
      #
      # Captures standard out and returns it as a string.
      # Cannot be run in the background.
      #
      # The command may be given as a single string or an array of strings,
      # representing the tool to run and the arguments to pass.
      #
      # If a block is provided, a {Toys::Utils::Exec::Controller} will be
      # yielded to it.
      #
      # Beware that some Ruby environments (e.g. JRuby, and Ruby on Windows)
      # do not support this method because they do not support fork.
      #
      # @param cmd [String,Array<String>] The tool to execute.
      # @param opts [keywords] The command options. Most options listed in the
      #     {Toys::Utils::Exec} documentation are supported, plus the
      #     `exit_on_nonzero_status` option.
      # @yieldparam controller [Toys::Utils::Exec::Controller] A controller
      #     for the subprocess streams.
      #
      # @return [String] What was written to standard out.
      #
      def capture_tool(cmd, **opts, &block)
        func = Exec._make_tool_caller(cmd)
        opts = Exec._setup_exec_opts(opts, self)
        self[KEY].capture_proc(func, **opts, &block)
      end

      ##
      # Execute a tool in a separately spawned process.
      #
      # Captures standard out and returns it as a string.
      # Cannot be run in the background.
      #
      # The command may be given as a single string or an array of strings,
      # representing the tool to run and the arguments to pass.
      #
      # If a block is provided, a {Toys::Utils::Exec::Controller} will be
      # yielded to it.
      #
      # An entirely separate spawned process is run for this tool, using the
      # setting of {Toys.executable_path}. Thus, this method can be run only if
      # that setting is present. The normal Toys gem does set it, but if you
      # are writing your own executable using Toys-Core, you will need to set
      # it explicitly for this method to work. Furthermore, Bundler, if
      # present, is reset to its "unbundled" environment. Thus, the tool found,
      # the behavior of the CLI, and the gem environment, might not be the same
      # as those of the calling tool.
      #
      # This method is often used if you are already in a bundle and need to
      # run a tool that uses a different bundle. It may also be necessary on
      # environments without "fork" (such as JRuby or Ruby on Windows).
      #
      # @param cmd [String,Array<String>] The tool to execute.
      # @param opts [keywords] The command options. Most options listed in the
      #     {Toys::Utils::Exec} documentation are supported, plus the
      #     `exit_on_nonzero_status` option.
      # @yieldparam controller [Toys::Utils::Exec::Controller] A controller
      #     for the subprocess streams.
      #
      # @return [String] What was written to standard out.
      #
      def capture_separate_tool(cmd, **opts, &block)
        Exec._setup_clean_process(cmd) do |clean_cmd|
          capture(clean_cmd, **opts, &block)
        end
      end

      ##
      # Execute the given string in a shell. Returns the exit code.
      # Cannot be run in the background.
      #
      # If a block is provided, a {Toys::Utils::Exec::Controller} will be
      # yielded to it.
      #
      # @param cmd [String] The shell command to execute.
      # @param opts [keywords] The command options. All options listed in the
      #     {Toys::Utils::Exec} documentation are supported, plus the
      #     `exit_on_nonzero_status` option.
      # @yieldparam controller [Toys::Utils::Exec::Controller] A controller
      #     for the subprocess streams.
      #
      # @return [Integer] The exit code
      #
      def sh(cmd, **opts, &block)
        opts = Exec._setup_exec_opts(opts, self)
        self[KEY].sh(cmd, **opts, &block)
      end

      ##
      # Exit if the given status code is nonzero. Otherwise, returns 0.
      #
      # @param status [Integer,Process::Status,Toys::Utils::Exec::Result]
      # @return [Integer]
      #
      def exit_on_nonzero_status(status)
        status = status.exit_code if status.respond_to?(:exit_code)
        status = status.exitstatus if status.respond_to?(:exitstatus)
        Context.exit(status) unless status.zero?
        0
      end

      ## @private
      def self._make_tool_caller(cmd)
        cmd = ::Shellwords.split(cmd) if cmd.is_a?(::String)
        proc { |config| ::Kernel.exit(config[:cli].run(*cmd)) }
      end

      ## @private
      def self._setup_exec_opts(opts, context)
        if opts.key?(:result_callback)
          opts = _setup_result_callback_option(opts, context)
        end
        if opts.key?(:exit_on_nonzero_status) || opts.key?(:e)
          opts = _setup_e_option(opts, context)
        end
        opts
      end

      ## @private
      def self._setup_e_option(opts, context)
        e_options = [:exit_on_nonzero_status, :e]
        if e_options.any? { |k| opts[k] }
          result_callback = proc { |r| context.exit(r.exit_code) if r.error? }
          opts = opts.merge(result_callback: result_callback)
        end
        opts.reject { |k, _v| e_options.include?(k) }
      end

      ## @private
      def self._setup_result_callback_option(opts, context)
        orig_callback = opts[:result_callback]
        result_callback =
          if orig_callback.is_a?(::Symbol)
            context.method(orig_callback)
          elsif orig_callback.respond_to?(:call)
            proc { |r| orig_callback.call(r, context) }
          end
        opts.merge(result_callback: result_callback)
      end

      ## @private
      def self._setup_clean_process(cmd)
        raise ::ArgumentError, "Toys process is unknown" unless ::Toys.executable_path
        cmd = ::Shellwords.split(cmd) if cmd.is_a?(::String)
        cmd = Array(::Toys.executable_path) + cmd
        if defined?(::Bundler)
          if ::Bundler.respond_to?(:with_unbundled_env)
            ::Bundler.with_unbundled_env { yield(cmd) }
          else
            ::Bundler.with_clean_env { yield(cmd) }
          end
        else
          yield(cmd)
        end
      end
    end
  end
end
