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
  module Utils
    ##
    # A service that executes subprocesses.
    #
    # This service provides a convenient interface for controlling spawned
    # processes and their streams. It also provides shortcuts for common cases
    # such as invoking Ruby in a subprocess or capturing output in a string.
    #
    # ## Stream handling
    #
    # By default, subprocess streams are connected to the corresponding streams
    # in the parent process.
    #
    # Alternately, input streams may be read from a string you provide, and
    # you may direct output streams to be captured and their contents exposed
    # in the result object.
    #
    # You may also connect subprocess streams to a controller, which you can
    # then manipulate by providing a block. Your block may read and write
    # connected streams to interact with the process. For example, to redirect
    # data into a subprocess you can connect its input stream to the controller
    # using the `:in_from` option (see below). Then, in your block, you can
    # write to that stream via the controller.
    #
    # ## Configuration options
    #
    # A variety of options can be used to control subprocesses. These include:
    #
    # *  **:env** (Hash) Environment variables to pass to the subprocess
    # *  **:logger** (Logger) Logger to use for logging the actual command.
    #    If not present, the command is not logged.
    # *  **:log_level** (Integer) Log level for logging the actual command.
    #    Defaults to Logger::INFO if not present.
    # *  **:in_from** (`:controller`,String) Connects the input stream of the
    #    subprocess. If set to `:controller`, the controller will control the
    #    input stream. If set to a string, that string will be written to the
    #    input stream. If not set, the input stream will be connected to the
    #    STDIN for the Toys process itself.
    # *  **:out_to** (`:controller`,`:capture`) Connects the standard output
    #    stream of the subprocess. If set to `:controller`, the controller
    #    will control the output stream. If set to `:capture`, the output will
    #    be captured in a string that is available in the
    #    {Toys::Utils::Exec::Result} object. If not set, the subprocess
    #    standard out is connected to STDOUT of the Toys process.
    # *  **:err_to** (`:controller`,`:capture`) Connects the standard error
    #    stream of the subprocess. If set to `:controller`, the controller
    #    will control the output stream. If set to `:capture`, the output will
    #    be captured in a string that is available in the
    #    {Toys::Utils::Exec::Result} object. If not set, the subprocess
    #    standard out is connected to STDERR of the Toys process.
    #
    # In addition, the following options recognized by `Process#spawn` are
    # supported.
    #
    # *  `:chdir`
    # *  `:close_others`
    # *  `:new_pgroup`
    # *  `:pgroup`
    # *  `:umask`
    # *  `:unsetenv_others`
    #
    # Any other options are ignored.
    #
    # Configuration options may be provided to any method that starts a
    # subprocess. You may also modify default values by calling
    # {Toys::Utils::Exec#config_defaults}.
    #
    class Exec
      ##
      # Create an exec service.
      #
      # @param [Hash] opts Initial default options.
      #
      def initialize(opts = {}, &block)
        @default_opts = Opts.new(&block).add(opts)
      end

      ##
      # Set default options
      #
      # @param [Hash] opts New default options to set
      #
      def configure_defaults(opts = {})
        @default_opts.add(opts)
        self
      end

      ##
      # Execute a command. The command may be given as a single string to pass
      # to a shell, or an array of strings indicating a posix command.
      #
      # If you provide a block, a {Toys::Utils::Exec::Controller} will be
      # yielded to it, allowing you to interact with the subprocess streams.
      #
      # @param [String,Array<String>] cmd The command to execute.
      # @param [Hash] opts The command options. See the section on
      #     configuration options in the {Toys::Utils::Exec} module docs.
      # @yieldparam controller [Toys::Utils::Exec::Controller] A controller
      #     for the subprocess streams.
      #
      # @return [Toys::Utils::Exec::Result] The subprocess result, including
      #     exit code and any captured output.
      #
      def exec(cmd, opts = {}, &block)
        spawn_cmd =
          if cmd.is_a?(::Array)
            if cmd.size == 1 && cmd.first.is_a?(::String)
              [[cmd.first, opts[:argv0] || cmd.first]]
            else
              cmd
            end
          else
            [cmd]
          end
        exec_opts = Opts.new(@default_opts).add(opts)
        executor = Executor.new(exec_opts, spawn_cmd)
        executor.execute(&block)
      end

      ##
      # Spawn a ruby process and pass the given arguments to it.
      #
      # If you provide a block, a {Toys::Utils::Exec::Controller} will be
      # yielded to it, allowing you to interact with the subprocess streams.
      #
      # @param [String,Array<String>] args The arguments to ruby.
      # @param [Hash] opts The command options. See the section on
      #     configuration options in the {Toys::Utils::Exec} module docs.
      # @yieldparam controller [Toys::Utils::Exec::Controller] A controller
      #     for the subprocess streams.
      #
      # @return [Toys::Utils::Result] The subprocess result, including
      #     exit code and any captured output.
      #
      def ruby(args, opts = {}, &block)
        cmd = args.is_a?(::Array) ? [::RbConfig.ruby] + args : "#{::RbConfig.ruby} #{args}"
        exec(cmd, {argv0: "ruby"}.merge(opts), &block)
      end

      ##
      # Execute the given string in a shell. Returns the exit code.
      #
      # @param [String] cmd The shell command to execute.
      # @param [Hash] opts The command options. See the section on
      #     configuration options in the {Toys::Utils::Exec} module docs.
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
      #     configuration options in the {Toys::Utils::Exec} module docs.
      #
      # @return [String] What was written to standard out.
      #
      def capture(cmd, opts = {})
        exec(cmd, opts.merge(out_to: :capture)).captured_out
      end

      ##
      # An internal helper class storing the configuration of a subprocess invocation
      # @private
      #
      class Opts
        ##
        # Option keys that belong to exec configuration
        # @private
        #
        CONFIG_KEYS = %i[
          env
          err_to
          in_from
          logger
          log_level
          nonzero_status_handler
          out_to
        ].freeze

        ##
        # Option keys that belong to spawn configuration
        # @private
        #
        SPAWN_KEYS = %i[
          chdir
          close_others
          new_pgroup
          pgroup
          umask
          unsetenv_others
        ].freeze

        def initialize(parent = nil)
          if parent
            @config_opts = ::Hash.new { |_h, k| parent.config_opts[k] }
            @spawn_opts = ::Hash.new { |_h, k| parent.spawn_opts[k] }
          elsif block_given?
            @config_opts = ::Hash.new { |_h, k| yield k }
            @spawn_opts = ::Hash.new { |_h, k| yield k }
          else
            @config_opts = {}
            @spawn_opts = {}
          end
        end

        def add(config)
          config.each do |k, v|
            if CONFIG_KEYS.include?(k)
              @config_opts[k] = v
            elsif SPAWN_KEYS.include?(k)
              @spawn_opts[k] = v
            end
          end
          self
        end

        def delete(*keys)
          keys.each do |k|
            if CONFIG_KEYS.include?(k)
              @config_opts.delete(k)
            elsif SPAWN_KEYS.include?(k)
              @spawn_opts.delete(k)
            end
          end
          self
        end

        attr_reader :config_opts
        attr_reader :spawn_opts
      end

      ##
      # An object of this type is passed to a subcommand control block.
      # You may use this object to interact with the subcommand's streams,
      # and/or send signals to the process.
      #
      class Controller
        ## @private
        def initialize(ins, out, err, pid)
          @in = ins
          @out = out
          @err = err
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
        def initialize(out, err, status)
          @captured_out = out
          @captured_err = err
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
      # An object that manages the execution of a subcommand
      # @private
      #
      class Executor
        def initialize(exec_opts, spawn_cmd)
          @spawn_cmd = spawn_cmd
          @config_opts = exec_opts.config_opts
          @spawn_opts = exec_opts.spawn_opts
          @captures = {}
          @controller_streams = {}
          @join_threads = []
          @child_streams = []
        end

        def execute(&block)
          setup_in_stream
          setup_out_stream(:out, :out_to, :out)
          setup_out_stream(:err, :err_to, :err)
          log_command
          wait_thread = start_process
          status = control_process(wait_thread, &block)
          create_result(status)
        end

        private

        def log_command
          logger = @config_opts[:logger]
          if logger && @config_opts[:log_level] != false
            cmd_str = @spawn_cmd.size == 1 ? @spawn_cmd.first : @spawn_cmd.inspect
            logger.add(@config_opts[:log_level] || ::Logger::INFO, cmd_str)
          end
        end

        def start_process
          args = []
          args << @config_opts[:env] if @config_opts[:env]
          args.concat(@spawn_cmd)
          pid = ::Process.spawn(*args, @spawn_opts)
          @child_streams.each(&:close)
          ::Process.detach(pid)
        end

        def control_process(wait_thread)
          begin
            if block_given?
              controller = Controller.new(
                @controller_streams[:in], @controller_streams[:out], @controller_streams[:err],
                wait_thread.pid
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
          nonzero_status_handler = @config_opts[:nonzero_status_handler]
          nonzero_status_handler.call(status) if nonzero_status_handler && status.exitstatus != 0
          Result.new(@captures[:out], @captures[:err], status)
        end

        def setup_in_stream
          setting = @config_opts[:in_from]
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
          setting = @config_opts[config_key]
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
