# frozen_string_literal: true

require "rbconfig"
require "logger"
require "shellwords"

module Toys
  module Utils
    ##
    # A service that executes subprocesses.
    #
    # This service provides a convenient interface for controlling spawned
    # processes and their streams. It also provides shortcuts for common cases
    # such as invoking Ruby in a subprocess or capturing output in a string.
    #
    # This class is not loaded by default. Before using it directly, you should
    # `require "toys/utils/exec"`
    #
    # ### Controlling processes
    #
    # A process can be started in the *foreground* or the *background*. If you
    # start a foreground process, it will "take over" your standard input and
    # output streams by default, and it will keep control until it completes.
    # If you start a background process, its streams will be redirected to null
    # by default, and control will be returned to you immediately.
    #
    # When a process is running, you can control it using a
    # {Toys::Utils::Exec::Controller} object. Use a controller to interact with
    # the process's input and output streams, send it signals, or wait for it
    # to complete.
    #
    # When running a process in the foreground, the controller will be yielded
    # to an optional block. For example, the following code starts a process in
    # the foreground and passes its output stream to a controller.
    #
    #     exec_service.exec(["git", "init"], out: :controller) do |controller|
    #       loop do
    #         line = controller.out.gets
    #         break if line.nil?
    #         puts "Got line: #{line}"
    #       end
    #     end
    #
    # When running a process in the background, the controller is returned from
    # the method that starts the process:
    #
    #     controller = exec_service.exec(["git", "init"], background: true)
    #
    # ### Stream handling
    #
    # By default, subprocess streams are connected to the corresponding streams
    # in the parent process. You can change this behavior, redirecting streams
    # or providing ways to control them, using the `:in`, `:out`, and `:err`
    # options.
    #
    # Three general strategies are available for custom stream handling. First,
    # you can redirect to other streams such as files, IO objects, or Ruby
    # strings. Some of these options map directly to options provided by the
    # `Process#spawn` method. Second, you can use a controller to manipulate
    # the streams programmatically. Third, you can capture output stream data
    # and make it available in the result.
    #
    # Following is a full list of the stream handling options, along with how
    # to specify them using the `:in`, `:out`, and `:err` options.
    #
    #  *  **Inherit parent stream:** You can inherit the corresponding stream
    #     in the parent process by passing `:inherit` as the option value. This
    #     is the default if the subprocess is *not* run in the background.
    #
    #  *  **Redirect to null:** You can redirect to a null stream by passing
    #     `:null` as the option value. This connects to a stream that is not
    #     closed but contains no data, i.e. `/dev/null` on unix systems. This
    #     is the default if the subprocess is run in the background.
    #
    #  *  **Close the stream:** You can close the stream by passing `:close` as
    #     the option value. This is the same as passing `:close` to
    #     `Process#spawn`.
    #
    #  *  **Redirect to a file:** You can redirect to a file. This reads from
    #     an existing file when connected to `:in`, and creates or appends to a
    #     file when connected to `:out` or `:err`. To specify a file, use the
    #     setting `[:file, "/path/to/file"]`. You can also, when writing a
    #     file, append an optional mode and permission code to the array. For
    #     example, `[:file, "/path/to/file", "a", 0644]`.
    #
    #  *  **Redirect to an IO object:** You can redirect to an IO object in the
    #     parent process, by passing the IO object as the option value. You can
    #     use any IO object. For example, you could connect the child's output
    #     to the parent's error using `out: $stderr`, or you could connect to
    #     an existing File stream. Unlike `Process#spawn`, this works for IO
    #     objects that do not have a corresponding file descriptor (such as
    #     StringIO objects). In such a case, a thread will be spawned to pipe
    #     the IO data through to the child process.
    #
    #  *  **Redirect to a pipe:** You can redirect to a pipe created using
    #     `IO.pipe` (i.e. a two-element array of read and write IO objects) by
    #     passing the array as the option value. This will connect the
    #     appropriate IO (either read or write), and close it in the parent.
    #     Thus, you can connect only one process to each end. If you want more
    #     direct control over IO closing behavior, pass the IO object (i.e. the
    #     element of the pipe array) directly.
    #
    #  *  **Combine with another child stream:** You can redirect one child
    #     output stream to another, to combine them. To merge the child's error
    #     stream into its output stream, use `err: [:child, :out]`.
    #
    #  *  **Read from a string:** You can pass a string to the input stream by
    #     setting `[:string, "the string"]`. This works only for `:in`.
    #
    #  *  **Capture output stream:** You can capture a stream and make it
    #     available on the {Toys::Utils::Exec::Result} object, using the
    #     setting `:capture`. This works only for the `:out` and `:err`
    #     streams.
    #
    #  *  **Use the controller:** You can hook a stream to the controller using
    #     the setting `:controller`. You can then manipulate the stream via the
    #     controller. If you pass a block to {Toys::Utils::Exec#exec}, it
    #     yields the {Toys::Utils::Exec::Controller}, giving you access to
    #     streams.
    #
    #  *  **Make copies of an output stream:** You can "tee," or duplicate the
    #     `:out` or `:err` stream and redirect those copies to various
    #     destinations. To specify a tee, use the setting `[:tee, ...]` where
    #     the additional array elements include two or more of the following.
    #     See the corresponding documentation above for more detail.
    #      *  `:inherit` to direct to the parent process's stream.
    #      *  `:capture` to capture the stream and store it in the result.
    #      *  `:controller` to direct the stream to the controller.
    #      *  `[:file, "/path/to/file"]` to write to a file.
    #      *  An `IO` or `StringIO` object.
    #      *  An array of two `IO` objects representing a pipe
    #
    #     Additionally, the last element of the array can be a hash of options.
    #     Supported options include:
    #      *  `:buffer_size` The size of the memory buffer for each element of
    #         the tee. Larger buffers may allow higher throughput. The default
    #         is 65536.
    #
    # ### Result handling
    #
    # A subprocess result is represented by a {Toys::Utils::Exec::Result}
    # object, which includes the exit code, the content of any captured output
    # streams, and any exeption raised when attempting to run the process.
    # When you run a process in the foreground, the method will return a result
    # object. When you run a process in the background, you can obtain the
    # result from the controller once the process completes.
    #
    # The following example demonstrates running a process in the foreground
    # and getting the exit code:
    #
    #     result = exec_service.exec(["git", "init"])
    #     puts "exit code: #{result.exit_code}"
    #
    # The following example demonstrates starting a process in the background,
    # waiting for it to complete, and getting its exit code:
    #
    #     controller = exec_service.exec(["git", "init"], background: true)
    #     result = controller.result(timeout: 1.0)
    #     if result
    #       puts "exit code: #{result.exit_code}"
    #     else
    #       puts "timed out"
    #     end
    #
    # You can also provide a callback that is executed once a process
    # completes. For example:
    #
    #     my_callback = proc do |result|
    #       puts "exit code: #{result.exit_code}"
    #     end
    #     exec_service.exec(["git", "init"], result_callback: my_callback)
    #
    # ### Configuration options
    #
    # A variety of options can be used to control subprocesses. These can be
    # provided to any method that starts a subprocess. Youc an also set
    # defaults by calling {Toys::Utils::Exec#configure_defaults}.
    #
    # Options that affect the behavior of subprocesses:
    #
    #  *  `:env` (Hash) Environment variables to pass to the subprocess.
    #     Keys represent variable names and should be strings. Values should be
    #     either strings or `nil`, which unsets the variable.
    #
    #  *  `:background` (Boolean) Runs the process in the background if `true`.
    #
    #  *  `:result_callback` (Proc) Called and passed the result object when
    #     the subprocess exits.
    #
    # Options for connecting input and output streams. See the section above on
    # stream handling for info on the values that can be passed.
    #
    #  *  `:in` Connects the input stream of the subprocess. See the section on
    #     stream handling.
    #
    #  *  `:out` Connects the standard output stream of the subprocess. See the
    #     section on stream handling.
    #
    #  *  `:err` Connects the standard error stream of the subprocess. See the
    #     section on stream handling.
    #
    # Options related to logging and reporting:
    #
    #  *  `:logger` (Logger) Logger to use for logging the actual command. If
    #     not present, the command is not logged.
    #
    #  *  `:log_level` (Integer,false) Level for logging the actual command.
    #     Defaults to Logger::INFO if not present. You can also pass `false` to
    #     disable logging of the command.
    #
    #  *  `:log_cmd` (String) The string logged for the actual command.
    #     Defaults to the `inspect` representation of the command.
    #
    #  *  `:name` (Object) An optional object that can be used to identify this
    #     subprocess. It is available in the controller and result objects.
    #
    # In addition, the following options recognized by
    # [`Process#spawn`](https://ruby-doc.org/core/Process.html#method-c-spawn)
    # are supported.
    #
    #  *  `:chdir` (String) Set the working directory for the command.
    #
    #  *  `:close_others` (Boolean) Whether to close non-redirected
    #     non-standard file descriptors.
    #
    #  *  `:new_pgroup` (Boolean) Create new process group (Windows only).
    #
    #  *  `:pgroup` (Integer,true,nil) The process group setting.
    #
    #  *  `:umask` (Integer) Umask setting for the new process.
    #
    #  *  `:unsetenv_others` (Boolean) Clear environment variables except those
    #     explicitly set.
    #
    # Any other option key will result in an `ArgumentError`.
    #
    class Exec
      ##
      # Create an exec service.
      #
      # @param block [Proc] A block that is called if a key is not found. It is
      #     passed the unknown key, and expected to return a default value
      #     (which can be nil).
      # @param opts [keywords] Initial default options. See {Toys::Utils::Exec}
      #     for a description of the options.
      #
      def initialize(**opts, &block)
        @default_opts = Opts.new(&block).add(opts)
      end

      ##
      # Set default options. See {Toys::Utils::Exec} for a description of the
      # options.
      #
      # @param opts [keywords] New default options to set
      # @return [self]
      #
      def configure_defaults(**opts)
        @default_opts.add(opts)
        self
      end

      ##
      # Execute a command. The command can be given as a single string to pass
      # to a shell, or an array of strings indicating a posix command.
      #
      # If the process is not set to run in the background, and a block is
      # provided, a {Toys::Utils::Exec::Controller} will be yielded to it.
      #
      # @param cmd [String,Array<String>] The command to execute.
      # @param opts [keywords] The command options. See the section on
      #     configuration options in the {Toys::Utils::Exec} class docs.
      # @yieldparam controller [Toys::Utils::Exec::Controller] A controller
      #     for the subprocess streams.
      #
      # @return [Toys::Utils::Exec::Controller] The subprocess controller, if
      #     the process is running in the background.
      # @return [Toys::Utils::Exec::Result] The result, if the process ran in
      #     the foreground.
      #
      def exec(cmd, **opts, &block)
        exec_opts = Opts.new(@default_opts).add(opts)
        spawn_cmd =
          if cmd.is_a?(::Array)
            if cmd.size > 1
              binary = canonical_binary_spec(cmd.first, exec_opts)
              [binary] + cmd[1..-1].map(&:to_s)
            else
              [canonical_binary_spec(Array(cmd.first), exec_opts)]
            end
          else
            [cmd.to_s]
          end
        executor = Executor.new(exec_opts, spawn_cmd, block)
        executor.execute
      end

      ##
      # Spawn a ruby process and pass the given arguments to it.
      #
      # If the process is not set to run in the background, and a block is
      # provided, a {Toys::Utils::Exec::Controller} will be yielded to it.
      #
      # @param args [String,Array<String>] The arguments to ruby.
      # @param opts [keywords] The command options. See the section on
      #     configuration options in the {Toys::Utils::Exec} class docs.
      # @yieldparam controller [Toys::Utils::Exec::Controller] A controller
      #     for the subprocess streams.
      #
      # @return [Toys::Utils::Exec::Controller] The subprocess controller, if
      #     the process is running in the background.
      # @return [Toys::Utils::Exec::Result] The result, if the process ran in
      #     the foreground.
      #
      def exec_ruby(args, **opts, &block)
        cmd = args.is_a?(::Array) ? [::RbConfig.ruby] + args : "#{::RbConfig.ruby} #{args}"
        log_cmd = "exec ruby: #{args.inspect}"
        opts = {argv0: "ruby", log_cmd: log_cmd}.merge(opts)
        exec(cmd, **opts, &block)
      end
      alias ruby exec_ruby

      ##
      # Execute a proc in a fork.
      #
      # If the process is not set to run in the background, and a block is
      # provided, a {Toys::Utils::Exec::Controller} will be yielded to it.
      #
      # @param func [Proc] The proc to call.
      # @param opts [keywords] The command options. See the section on
      #     configuration options in the {Toys::Utils::Exec} class docs.
      # @yieldparam controller [Toys::Utils::Exec::Controller] A controller
      #     for the subprocess streams.
      #
      # @return [Toys::Utils::Exec::Controller] The subprocess controller, if
      #     the process is running in the background.
      # @return [Toys::Utils::Exec::Result] The result, if the process ran in
      #     the foreground.
      #
      def exec_proc(func, **opts, &block)
        exec_opts = Opts.new(@default_opts).add(opts)
        executor = Executor.new(exec_opts, func, block)
        executor.execute
      end

      ##
      # Execute a command. The command can be given as a single string to pass
      # to a shell, or an array of strings indicating a posix command.
      #
      # Captures standard out and returns it as a string.
      # Cannot be run in the background.
      #
      # If a block is provided, a {Toys::Utils::Exec::Controller} will be
      # yielded to it.
      #
      # @param cmd [String,Array<String>] The command to execute.
      # @param opts [keywords] The command options. See the section on
      #     configuration options in the {Toys::Utils::Exec} class docs.
      # @yieldparam controller [Toys::Utils::Exec::Controller] A controller
      #     for the subprocess streams.
      #
      # @return [String] What was written to standard out.
      #
      def capture(cmd, **opts, &block)
        opts = opts.merge(out: :capture, background: false)
        exec(cmd, **opts, &block).captured_out
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
      # @param opts [keywords] The command options. See the section on
      #     configuration options in the {Toys::Utils::Exec} class docs.
      # @yieldparam controller [Toys::Utils::Exec::Controller] A controller
      #     for the subprocess streams.
      #
      # @return [String] What was written to standard out.
      #
      def capture_ruby(args, **opts, &block)
        opts = opts.merge(out: :capture, background: false)
        ruby(args, **opts, &block).captured_out
      end

      ##
      # Execute a proc in a fork.
      #
      # Captures standard out and returns it as a string.
      # Cannot be run in the background.
      #
      # If a block is provided, a {Toys::Utils::Exec::Controller} will be
      # yielded to it.
      #
      # @param func [Proc] The proc to call.
      # @param opts [keywords] The command options. See the section on
      #     configuration options in the {Toys::Utils::Exec} class docs.
      # @yieldparam controller [Toys::Utils::Exec::Controller] A controller
      #     for the subprocess streams.
      #
      # @return [String] What was written to standard out.
      #
      def capture_proc(func, **opts, &block)
        opts = opts.merge(out: :capture, background: false)
        exec_proc(func, **opts, &block).captured_out
      end

      ##
      # Execute the given string in a shell. Returns the exit code.
      # Cannot be run in the background.
      #
      # If a block is provided, a {Toys::Utils::Exec::Controller} will be
      # yielded to it.
      #
      # @param cmd [String] The shell command to execute.
      # @param opts [keywords] The command options. See the section on
      #     configuration options in the {Toys::Utils::Exec} class docs.
      # @yieldparam controller [Toys::Utils::Exec::Controller] A controller
      #     for the subprocess streams.
      #
      # @return [Integer] The exit code
      #
      def sh(cmd, **opts, &block)
        opts = opts.merge(background: false)
        exec(cmd, **opts, &block).exit_code || -1
      end

      ##
      # An object that controls a subprocess. This object is returned from an
      # execution running in the background, or is yielded to a control block
      # for an execution running in the foreground.
      # You can use this object to interact with the subcommand's streams,
      # send signals to the process, and get its result.
      #
      class Controller
        ##
        # The subcommand's name.
        # @return [Object]
        #
        attr_reader :name

        ##
        # The subcommand's standard input stream (which can be written to).
        #
        # @return [IO] if the command was configured with `in: :controller`
        # @return [nil] if the command was not configured with
        #     `in: :controller`
        #
        attr_reader :in

        ##
        # The subcommand's standard output stream (which can be read from).
        #
        # @return [IO] if the command was configured with `out: :controller`
        # @return [nil] if the command was not configured with
        #     `out: :controller`
        #
        attr_reader :out

        ##
        # The subcommand's standard error stream (which can be read from).
        #
        # @return [IO] if the command was configured with `err: :controller`
        # @return [nil] if the command was not configured with
        #     `err: :controller`
        #
        attr_reader :err

        ##
        # The process ID.
        #
        # Exactly one of {#exception} and {#pid} will be non-nil.
        #
        # @return [Integer] if the process start was successful
        # @return [nil] if the process could not be started.
        #
        attr_reader :pid

        ##
        # The exception raised when the process failed to start.
        #
        # Exactly one of {#exception} and {#pid} will be non-nil.
        #
        # @return [Exception] if the process failed to start.
        # @return [nil] if the process start was successful.
        #
        attr_reader :exception

        ##
        # Captures the remaining data in the given stream.
        # After calling this, do not read directly from the stream.
        #
        # @param which [:out,:err] Which stream to capture
        # @return [self]
        #
        def capture(which)
          stream = stream_for(which)
          @join_threads << ::Thread.new do
            begin
              data = stream.read
              @mutex.synchronize do
                @captures[which] = data
              end
            ensure
              stream.close
            end
          end
          self
        end

        ##
        # Captures the remaining data in the standard output stream.
        # After calling this, do not read directly from the stream.
        #
        # @return [self]
        #
        def capture_out
          capture(:out)
        end

        ##
        # Captures the remaining data in the standard error stream.
        # After calling this, do not read directly from the stream.
        #
        # @return [self]
        #
        def capture_err
          capture(:err)
        end

        ##
        # Redirects the remainder of the given stream.
        #
        # You can specify the stream as an IO or IO-like object, or as a file
        # specified by its path. If specifying a file, you can optionally
        # provide the mode and permissions for the call to `File#open`. You can
        # also specify the value `:null` to indicate the null file.
        #
        # After calling this, do not interact directly with the stream.
        #
        # @param which [:in,:out,:err] Which stream to redirect
        # @param io [IO,StringIO,String,:null] Where to redirect the stream
        # @param io_args [Object...] The mode and permissions for opening the
        #     file, if redirecting to/from a file.
        # @return [self]
        #
        def redirect(which, io, *io_args)
          io = ::File::NULL if io == :null
          if io.is_a?(::String)
            io_args = which == :in ? ["r"] : ["w"] if io_args.empty?
            io = ::File.open(io, *io_args)
          end
          stream = stream_for(which, allow_in: true)
          @join_threads << ::Thread.new do
            begin
              if which == :in
                ::IO.copy_stream(io, stream)
              else
                ::IO.copy_stream(stream, io)
              end
            ensure
              stream.close
              io.close
            end
          end
          self
        end

        ##
        # Redirects the remainder of the standard input stream.
        #
        # You can specify the stream as an IO or IO-like object, or as a file
        # specified by its path. If specifying a file, you can optionally
        # provide the mode and permissions for the call to `File#open`. You can
        # also specify the value `:null` to indicate the null file.
        #
        # After calling this, do not interact directly with the stream.
        #
        # @param io [IO,StringIO,String,:null] Where to redirect the stream
        # @param io_args [Object...] The mode and permissions for opening the
        #     file, if redirecting from a file.
        # @return [self]
        #
        def redirect_in(io, *io_args)
          redirect(:in, io, *io_args)
        end

        ##
        # Redirects the remainder of the standard output stream.
        #
        # You can specify the stream as an IO or IO-like object, or as a file
        # specified by its path. If specifying a file, you can optionally
        # provide the mode and permissions for the call to `File#open`. You can
        # also specify the value `:null` to indicate the null file.
        #
        # After calling this, do not interact directly with the stream.
        #
        # @param io [IO,StringIO,String,:null] Where to redirect the stream
        # @param io_args [Object...] The mode and permissions for opening the
        #     file, if redirecting to a file.
        # @return [self]
        #
        def redirect_out(io, *io_args)
          redirect(:out, io, *io_args)
        end

        ##
        # Redirects the remainder of the standard error stream.
        #
        # You can specify the stream as an IO or IO-like object, or as a file
        # specified by its path. If specifying a file, you can optionally
        # provide the mode and permissions for the call to `File#open`.
        #
        # After calling this, do not interact directly with the stream.
        #
        # @param io [IO,StringIO,String] Where to redirect the stream
        # @param io_args [Object...] The mode and permissions for opening the
        #     file, if redirecting to a file.
        # @return [self]
        #
        def redirect_err(io, *io_args)
          redirect(:err, io, *io_args)
        end

        ##
        # Send the given signal to the process. The signal can be specified
        # by name or number.
        #
        # @param sig [Integer,String] The signal to send.
        # @return [self]
        #
        def kill(sig)
          ::Process.kill(sig, pid) if pid
          self
        end
        alias signal kill

        ##
        # Determine whether the subcommand is still executing
        #
        # @return [Boolean]
        #
        def executing?
          @wait_thread&.status ? true : false
        end

        ##
        # Wait for the subcommand to complete, and return a result object.
        #
        # Closes the control streams if present. The stdin stream is always
        # closed, even if the call times out. The stdout and stderr streams are
        # closed only after the command terminates.
        #
        # @param timeout [Numeric,nil] The timeout in seconds, or `nil` to
        #     wait indefinitely.
        # @return [Toys::Utils::Exec::Result] The result object
        # @return [nil] if a timeout occurred.
        #
        def result(timeout: nil)
          close_streams(:in)
          return nil if @wait_thread && !@wait_thread.join(timeout)
          @result ||= begin
            close_streams(:out)
            @join_threads.each(&:join)
            Result.new(name, @captures[:out], @captures[:err], @wait_thread&.value, @exception)
                  .tap { |result| @result_callback&.call(result) }
          end
        end

        ##
        # @private
        #
        def initialize(name, controller_streams, captures, pid, join_threads,
                       result_callback, mutex)
          @name = name
          @in = controller_streams[:in]
          @out = controller_streams[:out]
          @err = controller_streams[:err]
          @captures = captures
          @pid = @exception = @wait_thread = nil
          case pid
          when ::Integer
            @pid = pid
            @wait_thread = ::Process.detach(pid)
          when ::Exception
            @exception = pid
          end
          @join_threads = join_threads
          @result_callback = result_callback
          @mutex = mutex
          @result = nil
        end

        ##
        # Close the controller's streams.
        #
        # @private
        #
        def close_streams(which)
          @in.close if which != :out && @in && !@in.closed?
          @out.close if which != :in && @out && !@out.closed?
          @err.close if which != :in && @err && !@err.closed?
          self
        end

        private

        def stream_for(which, allow_in: false)
          stream = nil
          case which
          when :out
            stream = @out
            @out = nil
          when :err
            stream = @err
            @err = nil
          when :in
            if allow_in
              stream = @in
              @in = nil
            end
          else
            raise ::ArgumentError, "Unknown stream #{which}"
          end
          raise ::ArgumentError, "Stream #{which} not available" unless stream
          stream
        end
      end

      ##
      # The result returned from a subcommand execution. This includes the
      # identifying name of the execution (if any), the result status of the
      # execution, and any captured stream output.
      #
      # Possible result statuses are:
      #
      #  *  The process failed to start. {Result#failed?} will return true, and
      #     {Result#exception} will return an exception describing the failure
      #     (often an errno).
      #  *  The process executed and exited with a normal exit code. Either
      #     {Result#success?} or {Result#error?} will return true, and
      #     {Result.exit_code} will return the numeric exit code.
      #  *  The process executed but was terminated by an uncaught signal.
      #     {Result#signaled?} will return true, and {Result#signal_code} will
      #     return the numeric signal code.
      #
      class Result
        ##
        # The subcommand's name.
        #
        # @return [Object]
        #
        attr_reader :name

        ##
        # The captured output string.
        #
        # @return [String] The string captured from stdout.
        # @return [nil] if the command was not configured to capture stdout.
        #
        attr_reader :captured_out

        ##
        # The captured error string.
        #
        # @return [String] The string captured from stderr.
        # @return [nil] if the command was not configured to capture stderr.
        #
        attr_reader :captured_err

        ##
        # The Ruby process status object, providing various information about
        # the ending state of the process.
        #
        # Exactly one of {#exception} and {#status} will be non-nil.
        #
        # @return [Process::Status] The status, if the process was successfully
        #     spanwed and terminated.
        # @return [nil] if the process could not be started.
        #
        attr_reader :status

        ##
        # The exception raised if a process couldn't be started.
        #
        # Exactly one of {#exception} and {#status} will be non-nil.
        # Exactly one of {#exception}, {#exit_code}, or {#signal_code} will be
        # non-nil.
        #
        # @return [Exception] The exception raised from process start.
        # @return [nil] if the process started successfully.
        #
        attr_reader :exception

        ##
        # The numeric status code for a process that exited normally,
        #
        # Exactly one of {#exception}, {#exit_code}, or {#signal_code} will be
        # non-nil.
        #
        # @return [Integer] the numeric status code, if the process started
        #     successfully and exited normally.
        # @return [nil] if the process did not start successfully, or was
        #     terminated by an uncaught signal.
        #
        def exit_code
          status&.exitstatus
        end

        ##
        # The numeric signal code that caused process termination.
        #
        # Exactly one of {#exception}, {#exit_code}, or {#signal_code} will be
        # non-nil.
        #
        # @return [Integer] The signal that caused the process to terminate.
        # @return [nil] if the process did not start successfully, or executed
        #     and exited with a normal exit code.
        #
        def signal_code
          status&.termsig
        end
        alias term_signal signal_code

        ##
        # Returns true if the subprocess failed to start, or false if the
        # process was able to execute.
        #
        # @return [Boolean]
        #
        def failed?
          status.nil?
        end

        ##
        # Returns true if the subprocess terminated due to an unhandled signal,
        # or false if the process failed to start or exited normally.
        #
        # @return [Boolean]
        #
        def signaled?
          !signal_code.nil?
        end

        ##
        # Returns true if the subprocess terminated with a zero status, or
        # false if the process failed to start, terminated due to a signal, or
        # returned a nonzero status.
        #
        # @return [Boolean]
        #
        def success?
          code = exit_code
          !code.nil? && code.zero?
        end

        ##
        # Returns true if the subprocess terminated with a nonzero status, or
        # false if the process failed to start, terminated due to a signal, or
        # returned a zero status.
        #
        # @return [Boolean]
        #
        def error?
          code = exit_code
          !code.nil? && !code.zero?
        end

        ##
        # @private
        #
        def initialize(name, out, err, status, exception)
          @name = name
          @captured_out = out
          @captured_err = err
          @status = status
          @exception = exception
        end
      end

      private

      ##
      # An internal helper class storing the configuration of a subprocess invocation
      #
      # @private
      #
      class Opts
        ##
        # Option keys that belong to exec configuration
        #
        # @private
        #
        CONFIG_KEYS = [
          :argv0,
          :background,
          :cli,
          :env,
          :err,
          :in,
          :logger,
          :log_cmd,
          :log_level,
          :name,
          :out,
          :result_callback,
        ].freeze

        ##
        # Option keys that belong to spawn configuration
        #
        # @private
        #
        SPAWN_KEYS = [
          :chdir,
          :close_others,
          :new_pgroup,
          :pgroup,
          :umask,
          :unsetenv_others,
        ].freeze

        ##
        # @private
        #
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

        ##
        # @private
        #
        def add(config)
          config.each do |k, v|
            if CONFIG_KEYS.include?(k)
              @config_opts[k] = v
            elsif SPAWN_KEYS.include?(k) || k.to_s.start_with?("rlimit_")
              @spawn_opts[k] = v
            else
              raise ::ArgumentError, "Unknown key: #{k.inspect}"
            end
          end
          self
        end

        ##
        # @private
        #
        def delete(*keys)
          keys.each do |k|
            if CONFIG_KEYS.include?(k)
              @config_opts.delete(k)
            elsif SPAWN_KEYS.include?(k) || k.to_s.start_with?("rlimit_")
              @spawn_opts.delete(k)
            else
              raise ::ArgumentError, "Unknown key: #{k.inspect}"
            end
          end
          self
        end

        ##
        # @private
        #
        attr_reader :config_opts

        ##
        # @private
        #
        attr_reader :spawn_opts
      end

      ##
      # An object that manages the execution of a subcommand
      #
      # @private
      #
      class Executor
        ##
        # @private
        #
        def initialize(exec_opts, spawn_cmd, block)
          @fork_func = spawn_cmd.respond_to?(:call) ? spawn_cmd : nil
          @spawn_cmd = spawn_cmd.respond_to?(:call) ? nil : spawn_cmd
          @config_opts = exec_opts.config_opts
          @spawn_opts = exec_opts.spawn_opts
          @captures = {}
          @controller_streams = {}
          @join_threads = []
          @child_streams = []
          @parent_streams = []
          @block = block
          @default_stream = @config_opts[:background] ? :null : :inherit
          @mutex = ::Mutex.new
        end

        ##
        # @private
        #
        def execute
          setup_in_stream
          setup_out_stream(:out)
          setup_out_stream(:err)
          log_command
          controller = start_with_controller
          return controller if @config_opts[:background]
          begin
            @block&.call(controller)
            controller.result
          ensure
            controller.close_streams(:both)
          end
        end

        private

        def log_command
          logger = @config_opts[:logger]
          if logger && @config_opts[:log_level] != false
            cmd_str = @config_opts[:log_cmd] || default_log_str
            logger.add(@config_opts[:log_level] || ::Logger::INFO, cmd_str) if cmd_str
          end
        end

        def default_log_str
          if @fork_func
            "exec proc: #{@fork_func.inspect}"
          elsif @spawn_cmd
            if @spawn_cmd.size == 1 && @spawn_cmd.first.is_a?(::String)
              "exec sh: #{@spawn_cmd.first.inspect}"
            else
              cmd_binary = @spawn_cmd.first
              cmd_binary = cmd_binary.first if cmd_binary.is_a?(::Array)
              "exec: #{([cmd_binary] + @spawn_cmd[1..-1]).inspect}"
            end
          end
        end

        def start_with_controller
          pid =
            begin
              @fork_func ? start_fork : start_process
            rescue ::StandardError => e
              e
            end
          @child_streams.each(&:close)
          Controller.new(@config_opts[:name], @controller_streams, @captures, pid,
                         @join_threads, @config_opts[:result_callback], @mutex)
        end

        def start_process
          args = []
          args << @config_opts[:env] if @config_opts[:env]
          args.concat(@spawn_cmd)
          ::Process.spawn(*args, @spawn_opts)
        end

        def start_fork
          pid = ::Process.fork
          return pid unless pid.nil?
          exit_code = -1
          begin
            setup_env_within_fork
            setup_streams_within_fork
            exit_code = run_fork_func
          rescue ::SystemExit => e
            exit_code = e.status
          rescue ::Exception => e # rubocop:disable Lint/RescueException
            warn(([e.inspect] + e.backtrace).join("\n"))
          ensure
            ::Kernel.exit!(exit_code)
          end
        end

        def run_fork_func
          catch(:result) do
            if @spawn_opts[:chdir]
              ::Dir.chdir(@spawn_opts[:chdir]) { @fork_func.call(@config_opts) }
            else
              @fork_func.call(@config_opts)
            end
            0
          end
        end

        def setup_env_within_fork
          if @config_opts[:unsetenv_others]
            ::ENV.each_key do |k|
              ::ENV.delete(k) unless @config_opts.key?(k)
            end
          end
          (@config_opts[:env] || {}).each { |k, v| ::ENV[k.to_s] = v.to_s }
        end

        def setup_streams_within_fork
          @parent_streams.each(&:close)
          setup_in_stream_within_fork(@spawn_opts[:in], $stdin)
          setup_out_stream_within_fork(@spawn_opts[:out], $stdout)
          setup_out_stream_within_fork(@spawn_opts[:err], $stderr)
        end

        def setup_in_stream_within_fork(stream, stdstream)
          in_stream =
            case stream
            when ::Integer
              ::IO.open(stream)
            when ::Array
              ::File.open(*stream)
            when ::String
              ::File.open(stream, "r")
            when :close
              :close
            else
              stream if stream.respond_to?(:read)
            end
          if in_stream == :close
            stdstream.close
          elsif in_stream
            stdstream.reopen(in_stream)
          end
        end

        def setup_out_stream_within_fork(stream, stdstream)
          out_stream =
            case stream
            when ::Integer
              ::IO.open(stream)
            when ::Array
              interpret_out_array_within_fork(stream)
            when ::String
              ::File.open(stream, "w")
            when :close
              :close
            else
              stream if stream.respond_to?(:write)
            end
          if out_stream == :close
            stdstream.close
          elsif out_stream
            stdstream.reopen(out_stream)
            stdstream.sync = true
          end
        end

        def interpret_out_array_within_fork(stream)
          if stream.first == :child
            case stream[1]
            when :err
              $stderr
            when :out
              $stdout
            end
          else
            ::File.open(*stream)
          end
        end

        def setup_in_stream
          setting = @config_opts[:in] || @default_stream
          return unless setting
          case setting
          when ::Symbol
            setup_in_stream_of_type(setting, [])
          when ::Integer
            setup_in_stream_of_type(:parent, [setting])
          when ::String
            setup_in_stream_of_type(:file, [setting])
          when ::IO, ::StringIO
            interpret_in_io(setting)
          when ::Array
            interpret_in_array(setting)
          else
            raise "Unknown value for in: #{setting.inspect}"
          end
        end

        def interpret_in_io(setting)
          if setting.fileno.is_a?(::Integer)
            setup_in_stream_of_type(:parent, [setting.fileno])
          else
            setup_in_stream_of_type(:copy_io, [setting])
          end
        end

        def interpret_in_array(setting)
          if setting.first.is_a?(::Symbol)
            setup_in_stream_of_type(setting.first, setting[1..-1])
          elsif setting.first.is_a?(::String)
            setup_in_stream_of_type(:file, setting)
          elsif setting.size == 2 && setting.first.is_a?(::IO) && setting.last.is_a?(::IO)
            interpret_in_pipe(*setting)
          else
            raise "Unknown value for in: #{setting.inspect}"
          end
        end

        def interpret_in_pipe(reader, writer)
          @spawn_opts[:in] = reader
          @child_streams << reader
          @parent_streams << writer
        end

        def setup_in_stream_of_type(type, args)
          case type
          when :controller
            @controller_streams[:in] = make_in_pipe
          when :null
            make_null_stream(:in, "r")
          when :inherit
            @spawn_opts[:in] = :in
          when :close
            @spawn_opts[:in] = type
          when :parent
            @spawn_opts[:in] = args.first
          when :child
            @spawn_opts[:in] = [:child, args.first]
          when :string
            write_string_thread(args.first.to_s)
          when :copy_io
            copy_to_in_thread(args.first)
          when :file
            interpret_in_file(args)
          else
            raise "Unknown type for in: #{type.inspect}"
          end
        end

        def interpret_in_file(args)
          raise "Expected only file name for in" unless args.size == 1 && args.first.is_a?(::String)
          @spawn_opts[:in] = args + [::File::RDONLY]
        end

        def setup_out_stream(key)
          setting = @config_opts[key] || @default_stream
          case setting
          when ::Symbol
            setup_out_stream_of_type(key, setting, [])
          when ::Integer
            setup_out_stream_of_type(key, :parent, [setting])
          when ::String
            setup_out_stream_of_type(key, :file, [setting])
          when ::IO, ::StringIO
            interpret_out_io(key, setting)
          when ::Array
            interpret_out_array(key, setting)
          else
            raise "Unknown value for #{key}: #{setting.inspect}"
          end
        end

        def interpret_out_io(key, setting)
          if setting.fileno.is_a?(::Integer)
            setup_out_stream_of_type(key, :parent, [setting.fileno])
          else
            setup_out_stream_of_type(key, :copy_io, [setting])
          end
        end

        def interpret_out_array(key, setting)
          if setting.first.is_a?(::Symbol)
            setup_out_stream_of_type(key, setting.first, setting[1..-1])
          elsif setting.first.is_a?(::String)
            setup_out_stream_of_type(key, :file, setting)
          elsif setting.size == 2 && setting.first.is_a?(::IO) && setting.last.is_a?(::IO)
            interpret_out_pipe(key, *setting)
          else
            raise "Unknown value for #{key}: #{setting.inspect}"
          end
        end

        def interpret_out_pipe(key, reader, writer)
          @spawn_opts[key] = writer
          @child_streams << writer
          @parent_streams << reader
        end

        def setup_out_stream_of_type(key, type, args)
          case type
          when :controller
            @controller_streams[key] = make_out_pipe(key)
          when :null
            make_null_stream(key, "w")
          when :inherit
            @spawn_opts[key] = key
          when :close, :out, :err
            @spawn_opts[key] = type
          when :parent
            @spawn_opts[key] = args.first
          when :child
            @spawn_opts[key] = [:child, args.first]
          when :capture
            capture_stream_thread(key)
          when :copy_io
            copy_from_out_thread(key, args.first)
          when :file
            interpret_out_file(key, args)
          when :tee
            interpret_out_tee(key, args)
          else
            raise "Unknown type for #{key}: #{type.inspect}"
          end
        end

        def interpret_out_file(key, args)
          raise "Expected file name for #{key}" if args.empty? || !args.first.is_a?(::String)
          raise "Too many file arguments for #{key}" if args.size > 3
          @spawn_opts[key] = args.size == 1 ? args.first : args
        end

        def interpret_out_tee(key, args)
          opts = args.last.is_a?(::Hash) ? args.pop : {}
          reader = make_out_pipe(key)
          sinks = interpret_out_tee_arguments(key, args)
          tee_runner(key, reader, sinks, opts[:buffer_size] || 65_536)
        end

        def interpret_out_tee_arguments(key, args)
          args.map do |arg|
            case arg
            when :inherit
              [key == :err ? $stderr : $stdout, nil]
            when :capture
              [::StringIO.new, :capture]
            when :controller
              tee_sink_for_controller(key)
            when ::IO, ::StringIO
              [arg, nil]
            when ::String
              [::File.open(arg, "w"), :close]
            when ::Array
              tee_sink_for_array(key, arg)
            else
              raise "Unknown value for #{key} tee argument: #{arg.inspect}"
            end
          end
        end

        def tee_sink_for_controller(key)
          @controller_streams[key], writer = ::IO.pipe
          writer.sync = true
          [writer, :close]
        end

        def tee_sink_for_array(key, arg)
          if arg.size == 2 &&
             arg.last.is_a?(::IO) &&
             (arg.first == :autoclose || arg.first.is_a?(::IO))
            [arg.last, :close]
          else
            arg = arg[1..-1] if arg.first == :file
            if arg.empty? || !arg.first.is_a?(::String)
              raise "Expected file name for #{key} tee argument"
            end
            raise "Too many file arguments for #{key} tee argument" if arg.size > 3
            arg += ["w"] if arg.size == 1
            [::File.open(*arg), :close]
          end
        end

        def tee_runner(key, reader, sinks, buffer_size)
          @join_threads << ::Thread.new do
            sinks.map! { |io, on_done| [io, ::String.new, :write_nonblock, on_done] }
            until sinks.empty?
              tee_wait_for_streams(reader, sinks)
              reader = tee_read_stream(reader, sinks, buffer_size)
              tee_write_streams(sinks, key, reader.nil?)
            end
          end
        end

        def tee_wait_for_streams(reader, sinks)
          read_select = reader && [reader]
          write_select = []
          sinks.each do |io, buffer, _write_method, _on_done|
            write_select << io unless buffer.empty?
          end
          ::IO.select(read_select, write_select)
        end

        def tee_read_stream(reader, sinks, buffer_size)
          return nil if reader.nil?
          max = tee_amount_to_read(sinks, buffer_size)
          return reader unless max.positive?
          begin
            data = reader.read_nonblock(max)
            unless data.empty?
              sinks.each { |_io, buffer, _write_method, _on_done| buffer << data }
            end
            reader
          rescue ::IO::WaitReadable
            reader
          rescue ::StandardError
            reader.close rescue nil # rubocop:disable Style/RescueModifier
            nil
          end
        end

        def tee_write_streams(sinks, key, read_complete)
          sinks.delete_if do |sink|
            io, buffer, write_method, on_done = sink
            done, write_method = tee_write_one_stream(io, buffer, write_method, read_complete)
            sink[2] = write_method
            if done
              case on_done
              when :close
                io.close rescue nil # rubocop:disable Style/RescueModifier
              when :capture
                @mutex.synchronize do
                  @captures[key] = io.string
                end
              end
            end
            done
          end
        end

        def tee_write_one_stream(io, buffer, write_method, read_complete)
          return [read_complete, write_method] if buffer.empty?
          begin
            bytes = io.send(write_method, buffer)
            buffer.slice!(0, bytes)
            [false, write_method]
          rescue ::IO::WaitWritable, ::Errno::EINTR
            [false, write_method]
          rescue ::Errno::EBADF, ::NoMethodError
            raise if write_method == :write
            [false, :write]
          rescue ::StandardError
            [true, write_method]
          end
        end

        def tee_amount_to_read(sink_info, buffer_size)
          maxbuff = 0
          sink_info.each do |_sink, buffer, _meth|
            maxbuff = buffer.size if buffer.size > maxbuff
          end
          buffer_size - maxbuff
        end

        def make_null_stream(key, mode)
          f = ::File.open(::File::NULL, mode)
          @spawn_opts[key] = f
          @child_streams << f
        end

        def make_in_pipe
          r, w = ::IO.pipe
          @spawn_opts[:in] = r
          @child_streams << r
          @parent_streams << w
          w.sync = true
          w
        end

        def make_out_pipe(key)
          r, w = ::IO.pipe
          @spawn_opts[key] = w
          @child_streams << w
          @parent_streams << r
          r
        end

        def write_string_thread(string)
          stream = make_in_pipe
          @join_threads << ::Thread.new do
            begin
              stream.write string
            ensure
              stream.close
            end
          end
        end

        def copy_to_in_thread(io)
          stream = make_in_pipe
          @join_threads << ::Thread.new do
            begin
              ::IO.copy_stream(io, stream)
            ensure
              stream.close
              io.close
            end
          end
        end

        def copy_from_out_thread(key, io)
          stream = make_out_pipe(key)
          @join_threads << ::Thread.new do
            begin
              ::IO.copy_stream(stream, io)
            ensure
              stream.close
              io.close
            end
          end
        end

        def capture_stream_thread(key)
          stream = make_out_pipe(key)
          @join_threads << ::Thread.new do
            begin
              data = stream.read
              @mutex.synchronize do
                @captures[key] = data
              end
            ensure
              stream.close
            end
          end
        end
      end

      def canonical_binary_spec(cmd, exec_opts)
        config_argv0 = exec_opts.config_opts[:argv0]
        return cmd.to_s if !config_argv0 && !cmd.is_a?(::Array)
        cmd = Array(cmd)
        actual_cmd = cmd.first
        argv0 = cmd[1] || config_argv0 || actual_cmd
        [actual_cmd.to_s, argv0.to_s]
      end
    end
  end
end
