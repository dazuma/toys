# frozen_string_literal: true

# This file is vendored from the exec_service gem.
# Do not edit directly; run `toys vendor-util exec` to regenerate.

module Toys
  module Utils
    ##
    # A service that executes subprocesses.
    #
    # This service provides a convenient interface for controlling spawned
    # processes and their streams. It also provides shortcuts for common cases
    # such as invoking Ruby in a subprocess or capturing output in a string.
    #
    # ### The exec service
    #
    # The main entrypoint class is this one, {Toys::Utils::Exec}. It is a "service"
    # object that provides functionality, primarily methods that spawn processes.
    # Create it like any object:
    #
    #     require "toys/utils/exec"
    #     exec_service = Toys::Utils::Exec.new
    #
    # There are two "primitive" functions: {#exec} and {#exec_proc}. The {#exec}
    # method spawns an operating system process specified by an executable and
    # a set of arguments. The {#exec_proc} method takes a `Proc` and forks a
    # Ruby process. Both of these can be heavily configured with stream
    # handling, result handling, and numerous other options described below.
    # The class also provides convenience methods for common cases such as
    # spawning a Ruby process, spawning a shell script, or capturing output.
    #
    # The exec service class also stores default configuration that it applies
    # to processes it spawns. You can set these defaults when constructing the
    # service class, or at any time by calling {#configure_defaults}.
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
    #     is the default if the subprocess is run in the foreground.
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
    #     the IO data through to the child process. Note that the IO object
    #     will _not_ be closed on completion.
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
    #     streams. See the section below on controlling processes.
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
    # ### Controlling processes
    #
    # A process can be started in the *foreground* or the *background*. If you
    # start a foreground process, it will inherit your standard input and
    # output streams by default, and it will keep control until it completes.
    # If you start a background process, its streams will be redirected to null
    # by default, and control will be returned to you immediately.
    #
    # While a process is running, you can control it using a
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
    # At the end of the block, if the controller is handling the process's
    # input stream, that stream will automatically be closed. The following
    # example programmatically sends data to the `wc` unix program, and
    # captures its output. Because the controller is handling the input stream,
    # it automatically closes the stream at the end of the block, which causes
    # `wc` to end.
    #
    #     result = exec_service.exec(["wc"],
    #                                in: :controller,
    #                                out: :capture) do |controller|
    #       controller.in.puts "Hello, world!"
    #     end
    #     puts "Results: #{result.captured_out}"
    #
    # Otherwise, depending on the process's behavior, it may continue to run
    # after the end of the block. Control will not be returned to the caller
    # until the process actually terminates. Conversely, it is also possible
    # the process could terminate by itself while the block is still executing.
    # You can call controller methods to obtain the process's actual current
    # state.
    #
    # When running a process in the background, the controller is returned
    # immediately from the method that starts the process. In the following
    # example, git init is kicked off in the background and the output is
    # thrown away to /dev/null.
    #
    #     controller = exec_service.exec(["git", "init"], background: true)
    #
    # In this mode, use the returned controller to query the process's state
    # and interact with it. Streams directed to the controller are not
    # automatically closed, so you will need to do so yourself. Following is an
    # example of running `wc` in the background:
    #
    #     controller = exec_service.exec(["wc"], background: true,
    #                                    in: :controller, out: :controller)
    #     controller.in.puts "Hello, world!"
    #     controller.in.close # Do this explicitly to cause wc to finish
    #     puts "Results: #{controller.out.read}" # Read the entire stream
    #
    # ### Result handling
    #
    # A subprocess result is represented by a {Toys::Utils::Exec::Result}
    # object, which includes the exit code, the content of any captured output
    # streams, and any exception raised when attempting to run the process.
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
    # In foreground mode, the callback is executed in the calling thread, after
    # the process terminates (and after any controller block has completed) but
    # before control is returned to the caller. In background mode, the
    # callback is executed asynchronously in a separate thread after the
    # process terminates.
    #
    # ### Configuration options
    #
    # A variety of options can be used to control subprocesses. These can be
    # provided to any method that starts a subprocess. You can also set
    # defaults by calling {Toys::Utils::Exec#configure_defaults}.
    #
    # Options that affect the behavior of subprocesses:
    #
    #  *  `:env` (Hash) Environment variables to pass to the subprocess.
    #     Keys represent variable names and should be strings. Values should be
    #     either strings or `nil`, which unsets the variable.
    #
    #  *  `:background` (boolean) Runs the process in the background if `true`.
    #
    #  *  `:result_callback` (Proc) Called and passed the result object when
    #     the subprocess exits. If the process was run in the background, this
    #     callback is executed in a separate thread. If the process was run in
    #     the foreground, this callback is executed in the calling thread.
    #
    #  *  `:unbundle` (boolean) Disables any existing bundle when running the
    #     subprocess. Has no effect if Bundler isn't active at the call point.
    #     Cannot be used when executing in a fork, e.g. via {#exec_proc}.
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
    #  *  `:close_others` (boolean) Whether to close non-redirected
    #     non-standard file descriptors.
    #
    #  *  `:new_pgroup` (boolean) Create new process group (Windows only).
    #
    #  *  `:pgroup` (Integer,true,nil) The process group setting.
    #
    #  *  `:umask` (Integer) Umask setting for the new process.
    #
    #  *  `:unsetenv_others` (boolean) Clear environment variables except those
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
        require "logger"
        require "rbconfig"
        require "stringio"
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
              [binary] + cmd[1..].map(&:to_s)
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
        raise ::ArgumentError, "Given proc is not callable" unless func.respond_to?(:call)
        exec_opts = Opts.new(@default_opts).add(opts)
        raise ::ArgumentError, "Cannot use :unbundle option with exec_proc" if exec_opts.config_opts[:unbundle]
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
      # Execute the given string in a shell. Returns an effective exit code
      # that is always an integer. Cannot be run in the background.
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
      # @return [Integer] An effective exit code. See
      #     {Toys::Utils::Exec::Result#effective_code}.
      #
      def sh(cmd, **opts, &block)
        opts = opts.merge(background: false)
        exec(cmd, **opts, &block).effective_code
      end

      private

      def canonical_binary_spec(cmd, exec_opts)
        config_argv0 = exec_opts.config_opts[:argv0]
        return cmd.to_s if !config_argv0 && !cmd.is_a?(::Array)
        cmd = Array(cmd)
        actual_cmd = cmd.first
        argv0 = cmd[1] || config_argv0 || actual_cmd
        [actual_cmd.to_s, argv0.to_s]
      end
    end

    class Exec
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
        #
        # @return [self] if the stream was captured
        # @return [nil] if the stream was not captured because the process has
        #     completed or did not start successfully
        #
        def capture(which)
          @streams_mutex.synchronize do
            return nil unless @streams_open
            stream = stream_for(which, allow_in: false)
            @join_threads << ::Thread.new do
              data = stream.read
              @captures_mutex.synchronize do
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
        # If the stream is redirected to an IO-like object, it is _not_ closed
        # when the process is completed. (If it is redirected to a file
        # specified by path, the file is closed on completion.)
        #
        # After calling this, do not interact directly with the stream.
        #
        # @param which [:in,:out,:err] Which stream to redirect
        # @param io [IO,StringIO,String,:null] Where to redirect the stream
        # @param io_args [Object...] The mode and permissions for opening the
        #     file, if redirecting to/from a file.
        #
        # @return [self] if the stream was redirected
        # @return [nil] if the stream was not redirected because the process
        #     has completed or did not start successfully
        #
        def redirect(which, io, *io_args)
          @streams_mutex.synchronize do
            return nil unless @streams_open
            io = ::File::NULL if io == :null
            close_afterward = false
            if io.is_a?(::String)
              io_args = which == :in ? ["r"] : ["w"] if io_args.empty?
              io = ::File.open(io, *io_args)
              close_afterward = true
            end
            stream = stream_for(which, allow_in: true)
            @join_threads << ::Thread.new do
              if which == :in
                ::IO.copy_stream(io, stream)
              else
                ::IO.copy_stream(stream, io)
              end
            ensure
              stream.close
              io.close if close_afterward
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
        #
        # @return [self] if the stream was redirected
        # @return [nil] if the stream was not redirected because the process
        #     has completed or did not start successfully
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
        #
        # @return [self] if the stream was redirected
        # @return [nil] if the stream was not redirected because the process
        #     has completed or did not start successfully
        #
        def redirect_out(io, *io_args)
          redirect(:out, io, *io_args)
        end

        ##
        # Redirects the remainder of the standard error stream.
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
        #
        # @return [self] if the stream was redirected
        # @return [nil] if the stream was not redirected because the process
        #     has completed or did not start successfully
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
        # @return [boolean]
        #
        def executing?
          @completion_thread&.status ? true : false
        end

        ##
        # Wait for the subcommand to complete, and return a result object.
        #
        # @param timeout [Numeric,nil] The timeout in seconds, or `nil` to
        #     wait indefinitely.
        # @return [Toys::Utils::Exec::Result] The result object
        # @return [nil] if a timeout occurred.
        #
        def result(timeout: nil)
          return nil if @completion_thread && !@completion_thread.join(timeout)
          # @completion_thread sets @result, so the final value is guaranteed
          # to be stable once the thread has joined above.
          @result
        end

        ##
        # @private
        #
        def initialize(name:, controller_streams:, captures:, pid_or_exception:,
                       join_threads:, background_callback:, captures_mutex:)
          @name = name
          @in = controller_streams[:in]
          @out = controller_streams[:out]
          @err = controller_streams[:err]
          @captures = captures
          @join_threads = join_threads
          @background_callback = background_callback
          @captures_mutex = captures_mutex
          @streams_open = false
          @streams_mutex = ::Mutex.new
          @pid = @exception = @completion_thread = @result = nil
          case pid_or_exception
          when ::Integer
            @pid = pid_or_exception
            @streams_open = true
            @completion_thread = ::Thread.new do
              _pid, status = ::Process.wait2(@pid)
              cleanup(status)
            end
          when ::Exception
            @exception = pid_or_exception
            cleanup(nil)
          end
        end

        ##
        # Close the controller's input stream, if any.
        #
        # @private
        #
        def close_in_stream
          @streams_mutex.synchronize do
            @in&.close
          end
          self
        end

        ##
        # Close the controller's output streams, if any.
        #
        # @private
        #
        def close_out_streams
          @streams_mutex.synchronize do
            @out&.close
            @err&.close
          end
          self
        end

        private

        ##
        # Cleanup after the child process ends.
        # Blocks any further captures/redirects, joins all stream processing
        # threads, and sets the result. Also kicks off the callback if run in
        # the background.
        #
        def cleanup(status)
          @streams_mutex.synchronize do
            @streams_open = false
          end
          @join_threads.each(&:join)
          @result = Result.new(@name, @captures[:out], @captures[:err], status, @exception)
          if @background_callback
            ::Thread.new do
              @background_callback.call(@result)
            end
          end
        end

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
    end

    class Exec
      ##
      # An object that manages the execution of a subcommand
      #
      # @private
      #
      class Executor
        ##
        # Build an executor for a single subprocess invocation. Captures the
        # caller-resolved options, the command (either an argv array for
        # `Process.spawn` or a callable for `Process.fork`), and the optional
        # controller block. Initializes the bookkeeping state used during
        # {#execute} (capture map, controller stream map, helper threads, child
        # vs parent stream tracking, default stream behavior).
        #
        # @private
        #
        # @param exec_opts [Toys::Utils::Exec::Opts] Resolved per-call options.
        # @param spawn_cmd [Array<String>,Proc] Either the argv to spawn, or a
        #     callable to invoke in a fork.
        # @param block [Proc,nil] The optional controller block (only used in
        #     foreground mode).
        #
        def initialize(exec_opts, spawn_cmd, block)
          @fork_func = spawn_cmd.respond_to?(:call) ? spawn_cmd : nil
          if @fork_func && !::Process.respond_to?(:fork)
            raise ::NotImplementedError,
                  "Executing a proc is not available because fork is not supported on the current Ruby platform"
          end
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
          @captures_mutex = ::Mutex.new
        end

        ##
        # Run the subprocess. Sets up all three standard streams, logs the
        # command, spawns/forks, and wraps the result in a {Controller}. In
        # background mode returns the controller immediately; in foreground mode
        # yields the controller to the user block (closing its `:in` stream
        # afterward), waits for completion, fires `:result_callback`, closes the
        # controller's output streams, and returns the {Result}.
        #
        # @private
        #
        # @return [Toys::Utils::Exec::Controller] if running in the background.
        # @return [Toys::Utils::Exec::Result] if running in the foreground.
        #
        def execute
          setup_in_stream
          setup_out_stream(:out)
          setup_out_stream(:err)
          log_command
          controller = start_with_controller
          return controller if @config_opts[:background]
          begin
            begin
              @block&.call(controller)
            ensure
              controller.close_in_stream
            end
            result = controller.result
            @config_opts[:result_callback]&.call(result)
          ensure
            controller.close_out_streams
          end
          result
        end

        private

        ##
        # Emit the command line to the configured `:logger` at `:log_level`
        # (default `Logger::INFO`). No-op if no logger is set or `:log_level` is
        # `false`. Uses `:log_cmd` if provided, otherwise falls back to
        # {#default_log_str}.
        #
        # @return [void]
        #
        def log_command
          logger = @config_opts[:logger]
          if logger && @config_opts[:log_level] != false
            cmd_str = @config_opts[:log_cmd] || default_log_str
            logger.add(@config_opts[:log_level] || ::Logger::INFO, cmd_str) if cmd_str
          end
        end

        ##
        # Build the default human-readable log string for this invocation,
        # depending on whether this is a fork-of-proc, a shell string, or an argv.
        # Strips the argv0 override (the second element of `[bin, argv0]`) when
        # rendering an argv form so the log shows the actual binary.
        #
        # @return [String,nil] Log string, or nil if there is nothing to log.
        #
        def default_log_str
          if @fork_func
            "exec proc: #{@fork_func.inspect}"
          elsif @spawn_cmd
            if @spawn_cmd.size == 1 && @spawn_cmd.first.is_a?(::String)
              "exec sh: #{@spawn_cmd.first.inspect}"
            else
              cmd_binary = @spawn_cmd.first
              cmd_binary = cmd_binary.first if cmd_binary.is_a?(::Array)
              "exec: #{([cmd_binary] + @spawn_cmd[1..]).inspect}"
            end
          end
        end

        ##
        # Start the subprocess (via {#start_process} or {#start_fork}), close the
        # parent's references to the child-side IO ends so the child can detect
        # EOF properly, and construct a {Controller} wrapping the resulting pid
        # (or the spawn exception). Background mode forwards the result callback
        # to the controller for async firing.
        #
        # @return [Toys::Utils::Exec::Controller]
        #
        def start_with_controller
          pid_or_exception =
            begin
              @fork_func ? start_fork : start_process
            rescue ::StandardError => e
              e
            end
          @child_streams.each(&:close)
          background_callback = @config_opts[:result_callback] if @config_opts[:background]
          Controller.new(name: @config_opts[:name],
                         controller_streams: @controller_streams,
                         captures: @captures,
                         pid_or_exception: pid_or_exception,
                         join_threads: @join_threads,
                         background_callback: background_callback,
                         captures_mutex: @captures_mutex)
        end

        ##
        # Spawn the OS process. Prepends the env hash if any was configured, and
        # wraps the call in `Bundler.with_unbundled_env` when `:unbundle` is set
        # and Bundler is loaded.
        #
        # @return [Integer] The pid of the spawned process.
        #
        def start_process
          args = []
          args << @config_opts[:env] if @config_opts[:env]
          args.concat(@spawn_cmd)
          if @config_opts[:unbundle] && defined?(::Bundler) && ::Bundler.respond_to?(:with_unbundled_env)
            ::Bundler.with_unbundled_env do
              ::Process.spawn(*args, @spawn_opts)
            end
          else
            ::Process.spawn(*args, @spawn_opts)
          end
        end

        ##
        # Fork a child process for {#run_fork_func}. In the parent, returns the
        # child pid. In the child, applies env/stream setup, invokes the user
        # proc, and exits via `Kernel.exit!` (skipping at_exit handlers) with the
        # proc's return value, a `SystemExit` status, or -1 on uncaught
        # exceptions.
        #
        # @return [Integer] The child pid (in the parent process). Does not
        #     return in the child.
        #
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

        ##
        # Invoke the user proc inside the fork, honoring `:chdir` if given.
        # Wrapped in `catch(:result)` so the proc may `throw :result, code` to
        # short-circuit; otherwise the proc's return value is discarded and 0 is
        # used.
        #
        # @return [Integer] The exit code to use for the forked child.
        #
        def run_fork_func
          catch(:result) do
            if @spawn_opts[:chdir]
              ::Dir.chdir(@spawn_opts[:chdir]) { @fork_func.call }
            else
              @fork_func.call
            end
            0
          end
        end

        ##
        # Apply the configured `:env` hash inside the fork. If
        # `:unsetenv_others` is set, first delete every existing variable not
        # named in the configured env. Nil values delete; everything else is
        # coerced to string.
        #
        # @return [void]
        #
        def setup_env_within_fork
          env = @config_opts[:env] || {}
          if @spawn_opts[:unsetenv_others]
            ::ENV.each_key do |k|
              ::ENV.delete(k) unless env.key?(k)
            end
          end
          env.each do |k, v|
            if v.nil?
              ::ENV.delete(k.to_s)
            else
              ::ENV[k.to_s] = v.to_s
            end
          end
        end

        ##
        # In-fork stream setup. Closes parent-side IO ends (the child no longer
        # needs them) and reopens `$stdin`/`$stdout`/`$stderr` per the resolved
        # spawn-options translation that {#setup_in_stream} / {#setup_out_stream}
        # produced on the parent side.
        #
        # @return [void]
        #
        def setup_streams_within_fork
          @parent_streams.each(&:close)
          setup_in_stream_within_fork(@spawn_opts[:in], $stdin)
          setup_out_stream_within_fork(@spawn_opts[:out], $stdout)
          setup_out_stream_within_fork(@spawn_opts[:err], $stderr)
        end

        ##
        # Reopen stdin in the fork according to the parent-resolved spawn-opt
        # value (which may be an fd Integer, a `[path, mode]` array, a path
        # String, `:close`, or a readable IO). Anything else is ignored.
        #
        # @param stream [Object] The parent-resolved spawn-opt value.
        # @param stdstream [IO] The standard stream to reopen (typically
        #     `$stdin`).
        # @return [void]
        #
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

        ##
        # Reopen stdout/stderr in the fork. Mirrors {#setup_in_stream_within_fork}
        # for output: fd Integer, `[path, mode, perms]` array (delegated to
        # {#interpret_out_array_within_fork}), path String, `:close`, or a
        # writable IO. Sets `sync = true` on the reopened stream.
        #
        # @param stream [Object] The parent-resolved spawn-opt value.
        # @param stdstream [IO] The standard stream to reopen (typically
        #     `$stdout` or `$stderr`).
        # @return [void]
        #
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

        ##
        # Decode an array-shaped output spawn-opt inside the fork. Specifically
        # handles `[:child, :out]` / `[:child, :err]` (alias another std stream
        # in this child) and falls through to `File.open(*stream)` for file
        # specifications.
        #
        # @param stream [Array] The array spawn-opt value.
        # @return [IO] The IO to reopen with.
        #
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

        ##
        # Top-level dispatch for the configured `:in` setting. Translates user
        # syntax (Symbol / Integer / String / IO / StringIO / Array) into a call
        # to {#setup_in_stream_of_type} or one of the array/IO interpreters.
        # Defaults to `:inherit` (foreground) or `:null` (background).
        #
        # @return [void]
        #
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

        ##
        # Decide how to plug an IO/StringIO `:in` value into the child: real
        # OS-backed IOs are passed by fd, others are pumped through a copy
        # thread (so e.g. StringIO works).
        #
        # @param setting [IO,StringIO] The IO supplied as the `:in` setting.
        # @return [void]
        #
        def interpret_in_io(setting)
          if setting.fileno.is_a?(::Integer)
            setup_in_stream_of_type(:parent, [setting.fileno])
          else
            setup_in_stream_of_type(:copy_io, [setting])
          end
        end

        ##
        # Decode an array-shaped `:in` setting. Handles `[:type, *args]`,
        # `["path", mode?, perms?]` (file), and `[reader_io, writer_io]` (a
        # pre-built `IO.pipe`).
        #
        # @param setting [Array] The array setting value.
        # @return [void]
        #
        def interpret_in_array(setting)
          if setting.first.is_a?(::Symbol)
            setup_in_stream_of_type(setting.first, setting[1..])
          elsif setting.first.is_a?(::String)
            setup_in_stream_of_type(:file, setting)
          elsif setting.size == 2 && setting.first.is_a?(::IO) && setting.last.is_a?(::IO)
            interpret_in_pipe(*setting)
          else
            raise "Unknown value for in: #{setting.inspect}"
          end
        end

        ##
        # Wire an explicit user-provided pipe (reader, writer pair) into stdin:
        # the reader becomes the child's stdin and is closed in the parent on
        # spawn; the writer is closed in the parent before forking.
        #
        # @param reader [IO] The read end (handed to the child).
        # @param writer [IO] The write end (closed in the parent).
        # @return [void]
        #
        def interpret_in_pipe(reader, writer)
          @spawn_opts[:in] = reader
          @child_streams << reader
          @parent_streams << writer
        end

        ##
        # Apply a stdin setup of the given symbolic type. The dispatch covers
        # all canonical `:in` modes: controller pipe, null device, inherit-from
        # parent, close, raw fd ("parent"), child-stream alias, literal string
        # input, copy-from-IO thread, and file path.
        #
        # @param type [Symbol] The mode (`:controller`, `:null`, `:inherit`,
        #     `:close`, `:parent`, `:child`, `:string`, `:copy_io`, `:file`).
        # @param args [Array] Mode-specific arguments.
        # @return [void]
        #
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

        ##
        # Validate and apply a `:file`-typed `:in` setup. Forces read-only mode
        # and rejects extra args; only a single path String is accepted (mode
        # and perms are deliberately not user-configurable on stdin).
        #
        # @param args [Array<String>] One-element array containing the path.
        # @return [void]
        #
        def interpret_in_file(args)
          raise "Expected only file name for in" unless args.size == 1 && args.first.is_a?(::String)
          @spawn_opts[:in] = args + [::File::RDONLY]
        end

        ##
        # Top-level dispatch for `:out` or `:err`. Symmetric to
        # {#setup_in_stream} but with the additional `:tee` and `:capture` modes
        # available (and `:string` / `:copy_io` for input not present here).
        #
        # @param key [Symbol] Either `:out` or `:err`.
        # @return [void]
        #
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

        ##
        # Output counterpart to {#interpret_in_io}: real-fd IOs hook directly,
        # everything else gets a copy-from-pipe thread.
        #
        # @param key [Symbol] Either `:out` or `:err`.
        # @param setting [IO,StringIO] The user-supplied IO.
        # @return [void]
        #
        def interpret_out_io(key, setting)
          if setting.fileno.is_a?(::Integer)
            setup_out_stream_of_type(key, :parent, [setting.fileno])
          else
            setup_out_stream_of_type(key, :copy_io, [setting])
          end
        end

        ##
        # Decode an array-shaped `:out`/`:err` setting: `[:type, *args]`,
        # `["path", mode?, perms?]`, or a `[reader, writer]` pipe pair.
        #
        # @param key [Symbol] Either `:out` or `:err`.
        # @param setting [Array] The array setting value.
        # @return [void]
        #
        def interpret_out_array(key, setting)
          if setting.first.is_a?(::Symbol)
            setup_out_stream_of_type(key, setting.first, setting[1..])
          elsif setting.first.is_a?(::String)
            setup_out_stream_of_type(key, :file, setting)
          elsif setting.size == 2 && setting.first.is_a?(::IO) && setting.last.is_a?(::IO)
            interpret_out_pipe(key, *setting)
          else
            raise "Unknown value for #{key}: #{setting.inspect}"
          end
        end

        ##
        # Output counterpart to {#interpret_in_pipe}. The writer becomes the
        # child's output stream; the reader is preserved in the parent for the
        # caller to use, and is closed there at execution-end cleanup.
        #
        # @param key [Symbol] Either `:out` or `:err`.
        # @param reader [IO] The read end (kept in parent).
        # @param writer [IO] The write end (handed to the child).
        # @return [void]
        #
        def interpret_out_pipe(key, reader, writer)
          @spawn_opts[key] = writer
          @child_streams << writer
          @parent_streams << reader
        end

        ##
        # Apply an `:out` or `:err` setup of the given symbolic type. Covers
        # controller pipe, null, inherit, close/swap-with-other-stream, raw fd,
        # child-alias, capture-to-string, copy-to-IO thread, file, and tee.
        #
        # @param key [Symbol] Either `:out` or `:err`.
        # @param type [Symbol] The mode.
        # @param args [Array] Mode-specific arguments.
        # @return [void]
        #
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

        ##
        # Validate and apply a `:file`-typed `:out`/`:err` setup. Accepts one to
        # three args (`path`, optional `mode`, optional `perms`); collapses the
        # single-path case to a bare String spawn-opt for `Process.spawn`'s
        # canonical form.
        #
        # @param key [Symbol] Either `:out` or `:err`.
        # @param args [Array] `[path, mode?, perms?]`.
        # @return [void]
        #
        def interpret_out_file(key, args)
          raise "Expected file name for #{key}" if args.empty? || !args.first.is_a?(::String)
          raise "Too many file arguments for #{key}" if args.size > 3
          @spawn_opts[key] = args.size == 1 ? args.first : args
        end

        ##
        # Apply a `:tee` setup. Pulls an optional trailing options Hash off the
        # arg list, builds a pipe (the child writes here, the tee thread reads
        # from it), interprets each remaining arg into a `[sink_io, on_done]`
        # pair via {#interpret_out_tee_arguments}, and starts the fan-out
        # thread.
        #
        # @param key [Symbol] Either `:out` or `:err`.
        # @param args [Array] Sink specs followed by an optional options Hash.
        # @return [void]
        #
        def interpret_out_tee(key, args)
          opts = args.last.is_a?(::Hash) ? args.pop : {}
          reader = make_out_pipe(key)
          sinks = interpret_out_tee_arguments(key, args)
          tee_runner(key, reader, sinks, opts[:buffer_size] || 65_536)
        end

        ##
        # Resolve each tee-arg into a `[sink_io, on_done]` pair, where
        # `on_done` is one of `nil` (leave open), `:close` (close the IO when
        # this sink finishes), or `:capture` (snapshot the StringIO into the
        # captures hash).
        #
        # @param key [Symbol] Either `:out` or `:err`.
        # @param args [Array] The sink specs to interpret.
        # @return [Array<Array>] One `[io, on_done]` pair per sink.
        #
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

        ##
        # Build a tee sink for the `:controller` case: an internal pipe whose
        # read end is exposed via the controller, and whose write end is closed
        # by the tee thread when the sink completes.
        #
        # @param key [Symbol] Either `:out` or `:err`.
        # @return [Array] `[writer_io, :close]`.
        #
        def tee_sink_for_controller(key)
          @controller_streams[key], writer = ::IO.pipe
          writer.sync = true
          [writer, :close]
        end

        ##
        # Build a tee sink from an Array spec. Two recognized shapes:
        #   * `[:autoclose, io]` or `[some_io, io]` — use `io` and close it at
        #     end. (The first form is a bit historical; both branches simply
        #     take `arg.last` as the sink and mark it for close.)
        #   * `[path, mode?, perms?]` (optionally prefixed with `:file`) —
        #     opened as a file with default mode `"w"`.
        #
        # @param key [Symbol] Either `:out` or `:err`.
        # @param arg [Array] The array sink spec.
        # @return [Array] `[io, :close]`.
        #
        def tee_sink_for_array(key, arg)
          if arg.size == 2 &&
             arg.last.is_a?(::IO) &&
             (arg.first == :autoclose || arg.first.is_a?(::IO))
            [arg.last, :close]
          else
            arg = arg[1..] if arg.first == :file
            if arg.empty? || !arg.first.is_a?(::String)
              raise "Expected file name for #{key} tee argument"
            end
            raise "Too many file arguments for #{key} tee argument" if arg.size > 3
            arg += ["w"] if arg.size == 1
            [::File.open(*arg), :close]
          end
        end

        ##
        # Spawn the fan-out thread that drives the tee. Each sink is tracked as
        # `[io, buffer, write_method, on_done]`. The loop alternates an
        # `IO.select` wait, a non-blocking read from the source pipe into every
        # sink's buffer, and a non-blocking write from each sink's buffer into
        # its IO. Sinks drop out of the list when they finish (EOF reached and
        # buffer drained, or the sink errored). The thread is registered with
        # `@join_threads` so {Controller#cleanup} waits on it before producing
        # the {Result}.
        #
        # @param key [Symbol] Either `:out` or `:err`.
        # @param reader [IO] The pipe read end attached to the child's output.
        # @param sinks [Array<Array>] `[io, on_done]` pairs from
        #     {#interpret_out_tee_arguments}.
        # @param buffer_size [Integer] Per-sink memory buffer cap.
        # @return [Thread]
        #
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

        ##
        # Block until either the reader has data or some sink has buffered
        # bytes ready to flush, using `IO.select`.
        #
        # @param reader [IO,nil] The source pipe; nil once EOF was reached.
        # @param sinks [Array<Array>] Per-sink state tuples.
        # @return [void]
        #
        def tee_wait_for_streams(reader, sinks)
          read_select = reader && [reader]
          write_select = []
          sinks.each do |io, buffer, _write_method, _on_done|
            write_select << io unless buffer.empty?
          end
          ::IO.select(read_select, write_select)
        end

        ##
        # Read up to the available headroom (`buffer_size` minus the largest
        # in-flight buffer, see {#tee_amount_to_read}) from the source pipe and
        # append the data into every sink's buffer. Returns `nil` to signal EOF
        # (or any unexpected error) so the caller can flag read-complete; on
        # `WaitReadable` simply returns the reader to retry next iteration.
        #
        # @param reader [IO,nil] The source pipe, or nil if EOF already
        #     reached.
        # @param sinks [Array<Array>] Per-sink state tuples.
        # @param buffer_size [Integer] Per-sink buffer cap.
        # @return [IO,nil] The reader to use next iteration, or nil at EOF.
        #
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

        ##
        # Drive each sink one step: write whatever it can, mutating the
        # write-method in the tuple if a fallback is needed (see
        # {#tee_write_one_stream}). Drop sinks that have finished, running
        # their `on_done` action (close the io, or capture its String into the
        # captures hash).
        #
        # @param sinks [Array<Array>] Per-sink state tuples (mutated in-place).
        # @param key [Symbol] Either `:out` or `:err`.
        # @param read_complete [Boolean] True once the source pipe hit EOF.
        # @return [void]
        #
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
                @captures_mutex.synchronize do
                  @captures[key] = io.string
                end
              end
            end
            done
          end
        end

        ##
        # Attempt one nonblocking write from a sink's buffer. If the sink
        # doesn't support `write_nonblock` (some StringIOs / pseudo-IOs), fall
        # back permanently to plain `write`. Treats `WaitWritable`/`EINTR` as
        # "try again later". Returns `[done, write_method]`: `done` is true
        # when the sink should be removed (buffer empty and source EOF, or
        # unrecoverable error).
        #
        # @param io [IO,StringIO] The sink IO.
        # @param buffer [String] Pending bytes (mutated in-place).
        # @param write_method [Symbol] `:write_nonblock` or `:write`.
        # @param read_complete [Boolean] True if the source pipe is done.
        # @return [Array] `[done, write_method]`.
        #
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

        ##
        # Compute how many bytes the next read may pull, so that no sink's
        # buffer exceeds `buffer_size`. Returns the headroom against the
        # currently-fullest buffer (which may be zero or negative — the caller
        # treats non-positive values as "skip the read this round").
        #
        # @param sink_info [Array<Array>] Per-sink state tuples.
        # @param buffer_size [Integer] Per-sink buffer cap.
        # @return [Integer] Bytes to read this iteration.
        #
        def tee_amount_to_read(sink_info, buffer_size)
          maxbuff = 0
          sink_info.each do |_sink, buffer, _meth|
            maxbuff = buffer.size if buffer.size > maxbuff
          end
          buffer_size - maxbuff
        end

        ##
        # Open `File::NULL` in the given mode and wire it to the named
        # spawn-opt key. Tracked as a child stream so it gets closed in the
        # parent after spawn.
        #
        # @param key [Symbol] One of `:in`, `:out`, `:err`.
        # @param mode [String] File open mode (`"r"` for `:in`, `"w"` for the
        #     others).
        # @return [void]
        #
        def make_null_stream(key, mode)
          f = ::File.open(::File::NULL, mode)
          @spawn_opts[key] = f
          @child_streams << f
        end

        ##
        # Build a stdin pipe: the read end goes to the child (and is closed in
        # the parent post-spawn), the write end is exposed to the parent (and
        # is closed there during execution-end cleanup). The writer is set to
        # `sync = true` so caller writes don't buffer indefinitely.
        #
        # @return [IO] The write end (parent-side).
        #
        def make_in_pipe
          r, w = ::IO.pipe
          @spawn_opts[:in] = r
          @child_streams << r
          @parent_streams << w
          w.sync = true
          w
        end

        ##
        # Build an output pipe for `:out` or `:err`: write end goes to the
        # child, read end is exposed parent-side.
        #
        # @param key [Symbol] Either `:out` or `:err`.
        # @return [IO] The read end (parent-side).
        #
        def make_out_pipe(key)
          r, w = ::IO.pipe
          @spawn_opts[key] = w
          @child_streams << w
          @parent_streams << r
          r
        end

        ##
        # Spawn a helper thread that pumps a literal String into the child's
        # stdin and then closes the pipe (so the child sees EOF). Registered
        # with `@join_threads`.
        #
        # @param string [String] The bytes to send.
        # @return [Thread]
        #
        def write_string_thread(string)
          stream = make_in_pipe
          @join_threads << ::Thread.new do
            stream.write string
          ensure
            stream.close
          end
        end

        ##
        # Spawn a helper thread that copies from a user-supplied readable
        # object (typically a non-fd-backed IO like StringIO) into the child's
        # stdin pipe, closing the pipe at end. Registered with `@join_threads`.
        #
        # @param io [IO,StringIO] The source.
        # @return [Thread]
        #
        def copy_to_in_thread(io)
          stream = make_in_pipe
          @join_threads << ::Thread.new do
            ::IO.copy_stream(io, stream)
          ensure
            stream.close
          end
        end

        ##
        # Spawn a helper thread that copies from the child's `:out`/`:err`
        # pipe into a user-supplied writable object (typically a non-fd-backed
        # IO like StringIO), closing the pipe at end. Registered with
        # `@join_threads`.
        #
        # @param key [Symbol] Either `:out` or `:err`.
        # @param io [IO,StringIO] The destination.
        # @return [Thread]
        #
        def copy_from_out_thread(key, io)
          stream = make_out_pipe(key)
          @join_threads << ::Thread.new do
            ::IO.copy_stream(stream, io)
          ensure
            stream.close
          end
        end

        ##
        # Spawn a helper thread that drains the child's `:out`/`:err` pipe
        # entirely into a String and stores it in `@captures` (under the mutex
        # shared with the controller). Registered with `@join_threads`.
        #
        # @param key [Symbol] Either `:out` or `:err`.
        # @return [Thread]
        #
        def capture_stream_thread(key)
          stream = make_out_pipe(key)
          @join_threads << ::Thread.new do
            data = stream.read
            @captures_mutex.synchronize do
              @captures[key] = data
            end
          ensure
            stream.close
          end
        end
      end
    end

    class Exec
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
          :env,
          :err,
          :in,
          :logger,
          :log_cmd,
          :log_level,
          :name,
          :out,
          :result_callback,
          :unbundle,
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
    end

    class Exec
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
        #     spawned and terminated.
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
        # @return [boolean]
        #
        def failed?
          status.nil?
        end

        ##
        # Returns true if the subprocess terminated due to an unhandled signal,
        # or false if the process failed to start or exited normally.
        #
        # @return [boolean]
        #
        def signaled?
          !signal_code.nil?
        end

        ##
        # Returns true if the subprocess terminated with a zero status, or
        # false if the process failed to start, terminated due to a signal, or
        # returned a nonzero status.
        #
        # @return [boolean]
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
        # @return [boolean]
        #
        def error?
          code = exit_code
          !code.nil? && !code.zero?
        end

        ##
        # Returns an "effective" exit code, which is always an integer if the
        # process has terminated for any reason. In general, this code will be:
        #
        # * The same as {#exit_code} if the process terminated normally with an
        #   exit code,
        # * The convention of `128+signalnum` if the process terminated due to
        #   a signal,
        # * The convention of 126 if the process could not start due to lack of
        #   execution permissions,
        # * The convention of 127 if the process could not start because the
        #   command was not recognized or could not be found, or
        # * An undefined value between 1 and 255 for other failures.
        #
        # Note that the normal exit code and signal number cases are stable,
        # but any other cases are subject to change on future releases.
        #
        # @return [Integer]
        #
        def effective_code
          code = exit_code
          return code unless code.nil?
          code = signal_code
          return code + 128 unless code.nil?
          case exception
          when ::Errno::ENOENT
            127
          else
            # This is the intended result for ENOEXEC/EACCES.
            # For now, any other error (e.g. EBADARCH on MacOS) will also map
            # to this result. We can change this in the future since the
            # documentation explicitly allows it.
            126
          end
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
          freeze
        end
      end
    end

    class Exec
      ##
      # Version of the exec_service gem
      # @return [String]
      #
      VERSION = "0.1.0"
    end
  end
end
