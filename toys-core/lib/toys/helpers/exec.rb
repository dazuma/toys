# Copyright 2018 Daniel Azuma
#
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice,
#   this list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# * Neither the name of the copyright holder, nor the names of any other
#   contributors to this software, may be used to endorse or promote products
#   derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
;

require "logger"

module Toys
  module Helpers
    ##
    # A set of helper methods for invoking subcommands. Provides shortcuts for
    # common cases such as invoking Ruby in a subprocess or capturing output
    # in a string. Also provides an interface for controlling a spawned
    # process's streams.
    #
    # ## Configuration options
    #
    # A variety of options can be used to control subprocesses. These include:
    #
    # *  **:env** (Hash) Environment variables to pass to the subprocess
    # *  **:log_level** (Integer) If set, the actual command will be logged
    #    at the given level.
    # *  **:in_from** (`:controller`,String) Connects the input stream of the
    #    subprocess. If set to `:controller`, the controller will control the
    #    input stream. If set to a string, that string will be written to the
    #    input stream. If not set, the input stream will be connected to the
    #    STDIN for the Toys process itself.
    # *  **:out_to** (`:controller`,`:capture`) Connects the standard output
    #    stream of the subprocess. If set to `:controller`, the controller
    #    will control the output stream. If set to `:capture`, the output will
    #    be captured in a string that is available in the
    #    {Toys::Helpers::Exec::Result} object. If not set, the subprocess
    #    standard out is connected to STDOUT of the Toys process.
    # *  **:err_to** (`:controller`,`:capture`) Connects the standard error
    #    stream of the subprocess. See `:out_to` for more details.
    # *  **:out_err_to** (`:controller`,`:capture`) Combines the standard out
    #    and error streams of the subprocess and connects them. See `:out_to`
    #    for more details.
    # *  **:exit_on_nonzero_status** (Boolean) If true, a nonzero status code
    #    will cause the entire tool to terminate. Default is false.
    #
    # In addition, any options recognized by `Process#spawn` are supported.
    # These include `:umask`, `:pgroup`, `:chdir`, and many others.
    #
    # Configuration options may be provided to any method that starts a
    # subprocess. You may also set default values for this tool by calling
    # {Toys::Helpers::Exec#configure_exec}.
    #
    module Exec
      ##
      # Set default configuration keys.
      #
      # @param [Hash] opts The default options. See the section on
      #     configuration options in the {Toys::Helpers::Exec} module docs.
      #
      def configure_exec(opts = {})
        @exec_config ||= {}
        @exec_config.merge!(opts)
      end

      ##
      # Execute a command. The command may be given as a single string to pass
      # to a shell, or an array of strings indicating a posix command.
      #
      # If you provide a block, a {Toys::Helpers::Exec::Controller} will be
      # yielded to it, allowing you to interact with the subprocess streams.
      #
      # @param [String,Array<String>] cmd The command to execute.
      # @param [Hash] opts The command options. See the section on
      #     configuration options in the {Toys::Helpers::Exec} module docs.
      # @yieldparam controller [Toys::Helpers::Exec::Controller] A controller
      #     for the subprocess streams.
      #
      # @return [Toys::Helpers::Result] The subprocess result, including
      #     exit code and any captured output.
      #
      def exec(cmd, opts = {}, &block)
        exec_opts = ExecOpts.new(self)
        exec_opts.add(@exec_config) if defined? @exec_config
        exec_opts.add(opts)
        executor = Executor.new(exec_opts, cmd)
        executor.execute(&block)
      end

      ##
      # Spawn a ruby process and pass the given arguments to it.
      #
      # If you provide a block, a {Toys::Helpers::Exec::Controller} will be
      # yielded to it, allowing you to interact with the subprocess streams.
      #
      # @param [String,Array<String>] args The arguments to ruby.
      # @param [Hash] opts The command options. See the section on
      #     configuration options in the {Toys::Helpers::Exec} module docs.
      # @yieldparam controller [Toys::Helpers::Exec::Controller] A controller
      #     for the subprocess streams.
      #
      # @return [Toys::Helpers::Result] The subprocess result, including
      #     exit code and any captured output.
      #
      def ruby(args, opts = {}, &block)
        cmd =
          if args.is_a?(Array)
            [[Exec.ruby_binary, "ruby"]] + args
          else
            "#{Exec.ruby_binary} #{args}"
          end
        exec(cmd, opts, &block)
      end

      ##
      # Execute the given string in a shell. Returns the exit code.
      #
      # @param [String] cmd The shell command to execute.
      # @param [Hash] opts The command options. See the section on
      #     configuration options in the {Toys::Helpers::Exec} module docs.
      # @yieldparam controller [Toys::Helpers::Exec::Controller] A controller
      #     for the subprocess streams.
      #
      # @return [Integer] The exit code
      #
      def sh(cmd, opts = {})
        exec(cmd, opts).exit_code
      end

      ##
      # Execute a command. The command may be given as a single string to pass
      # to a shell, or an array of strings indicating a posix command.
      #
      # Captures standard out and returns it as a string.
      #
      # @param [String,Array<String>] cmd The command to execute.
      # @param [Hash] opts The command options. See the section on
      #     configuration options in the {Toys::Helpers::Exec} module docs.
      # @yieldparam controller [Toys::Helpers::Exec::Controller] A controller
      #     for the subprocess streams.
      #
      # @return [String] What was written to standard out.
      #
      def capture(cmd, opts = {})
        exec(cmd, opts.merge(out_to: :capture)).captured_out
      end

      ##
      # Returns the paty to the Ruby binary
      # @return [String] Path to the Ruby binary
      #
      def self.ruby_binary
        ::File.join(::RbConfig::CONFIG["bindir"], ::RbConfig::CONFIG["ruby_install_name"])
      end

      ##
      # An object of this type is passed to a subcommand control block.
      # You may use this object to interact with the subcommand's streams,
      # and/or send signals to the process.
      #
      class Controller
        ## @private
        def initialize(ins, out, err, out_err, pid)
          @in = ins
          @out = out
          @err = err
          @out_err = out_err
          @pid = pid
        end

        ##
        # Return the subcommand's standard input stream (which can be written
        # to), if the command was configured with `in_from: :controller`.
        # Returns `nil` otherwise.
        # @return [IO,nil]
        #
        attr_reader :in

        ##
        # Return the subcommand's standard output stream (which can be read
        # from), if the command was configured with `out_to: :controller`.
        # Returns `nil` otherwise.
        # @return [IO,nil]
        #
        attr_reader :out

        ##
        # Return the subcommand's standard error stream (which can be read
        # from), if the command was configured with `err_to: :controller`.
        # Returns `nil` otherwise.
        # @return [IO,nil]
        #
        attr_reader :err

        ##
        # Return the subcommand's combined standard output and error stream
        # (which can be read from), if the command was configured with
        # `out_err_to: :controller`. Returns `nil` otherwise.
        # @return [IO,nil]
        #
        attr_reader :out_err

        ##
        # Returns the process ID.
        # @return [Integer]
        #
        attr_reader :pid

        ##
        # Send the given signal to the process. The signal may be specified
        # by name or number.
        #
        # @param [Integer,String] signal The signal to send.
        #
        def kill(signal)
          ::Process.kill(signal, pid)
        end
      end

      ##
      # The return result from a subcommand
      #
      class Result
        ## @private
        def initialize(out, err, out_err, status)
          @captured_out = out
          @captured_err = err
          @captured_out_err = out_err
          @status = status
        end

        ##
        # Returns the captured output string, if the command was configured
        # with `out_to: :capture`. Returns `nil` otherwise.
        # @return [String,nil]
        #
        attr_reader :captured_out

        ##
        # Returns the captured error string, if the command was configured
        # with `err_to: :capture`. Returns `nil` otherwise.
        # @return [String,nil]
        #
        attr_reader :captured_err

        ##
        # Returns the captured combined output and error string, if the command
        # was configured with `out_err_to: :capture`. Returns `nil` otherwise.
        # @return [String,nil]
        #
        attr_reader :captured_out_err

        ##
        # Returns the status code object.
        # @return [Process::Status]
        #
        attr_reader :status

        ##
        # Returns the numeric status code.
        # @return [Integer]
        #
        def exit_code
          status.exitstatus
        end

        ##
        # Returns true if the subprocess terminated with a zero status.
        # @return [Boolean]
        #
        def success?
          exit_code.zero?
        end

        ##
        # Returns true if the subprocess terminated with a nonzero status.
        # @return [Boolean]
        #
        def error?
          !exit_code.zero?
        end
      end

      ##
      # An internal helper class storing the configuration of a subcommand invocation
      # @private
      #
      class ExecOpts
        ##
        # Option keys that belong to exec configuration rather than spawn
        # @private
        #
        CONFIG_KEYS = %i[
          exit_on_nonzero_status
          env
          log_level
          in_from
          out_to
          err_to
          out_err_to
        ].freeze

        def initialize(context)
          @context = context
          @config = {exit_on_nonzero_status: @context.get(Context::EXIT_ON_NONZERO_STATUS)}
          @spawn_opts = {}
        end

        def add(config)
          config.each do |k, v|
            if CONFIG_KEYS.include?(k)
              @config[k] = v
            else
              @spawn_opts[k] = v
            end
          end
        end

        attr_reader :config
        attr_reader :spawn_opts
        attr_reader :context
      end

      ##
      # An object that manages the execution of a subcommand
      # @private
      #
      class Executor
        def initialize(exec_opts, cmd)
          @cmd = Array(cmd)
          @config = exec_opts.config
          @context = exec_opts.context
          @spawn_opts = exec_opts.spawn_opts.dup
          @captures = {}
          @controller_streams = {}
          @join_threads = []
          @child_streams = []
        end

        def execute(&block)
          setup_in_stream
          setup_out_stream(:out, :out_to, :out)
          setup_out_stream(:err, :err_to, :err)
          setup_out_stream(:out_err, :out_err_to, [:out, :err])
          log_command
          wait_thread = start_process
          status = control_process(wait_thread, &block)
          create_result(status)
        end

        private

        def log_command
          unless @config[:log_level] == false
            cmd_str = @cmd.size == 1 ? @cmd.first : @cmd.inspect
            @context.logger.add(@config[:log_level] || ::Logger::INFO, cmd_str)
          end
        end

        def start_process
          args = []
          args << @config[:env] if @config[:env]
          args.concat(@cmd)
          pid = ::Process.spawn(*args, @spawn_opts)
          @child_streams.each(&:close)
          ::Process.detach(pid)
        end

        def control_process(wait_thread)
          begin
            if block_given?
              controller = Controller.new(
                @controller_streams[:in], @controller_streams[:out], @controller_streams[:err],
                @controller_streams[:out_err], wait_thread.pid
              )
              yield controller
            end
          ensure
            @controller_streams.each_value(&:close)
          end
          @join_threads.each(&:join)
          wait_thread.value
        end

        def create_result(status)
          if @config[:exit_on_nonzero_status]
            exit_status = status.exitstatus
            @context.exit(exit_status) if exit_status != 0
          end
          Result.new(@captures[:out], @captures[:err], @captures[:out_err], status)
        end

        def setup_in_stream
          setting = @config[:in_from]
          if setting
            r, w = ::IO.pipe
            @spawn_opts[:in] = r
            w.sync = true
            @child_streams << r
            case setting
            when :controller
              @controller_streams[:in] = w
            when String
              write_string_thread(w, setting)
            else
              raise "Unknown type for in_from"
            end
          end
        end

        def setup_out_stream(stream_name, config_key, spawn_key)
          setting = @config[config_key]
          if setting
            r, w = ::IO.pipe
            @spawn_opts[spawn_key] = w
            @child_streams << w
            case setting
            when :controller
              @controller_streams[stream_name] = r
            when :capture
              @join_threads << capture_stream_thread(r, stream_name)
            else
              raise "Unknown type for #{config_key}"
            end
          end
        end

        def write_string_thread(stream, string)
          ::Thread.new do
            begin
              stream.write string
            ensure
              stream.close
            end
          end
        end

        def capture_stream_thread(stream, name)
          ::Thread.new do
            begin
              @captures[name] = stream.read
            ensure
              stream.close
            end
          end
        end
      end
    end
  end
end
