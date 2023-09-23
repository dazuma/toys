# frozen_string_literal: true

module Toys
  module StandardMixins
    ##
    # The `:exec` mixin provides set of helper methods for executing processes
    # and subcommands. It provides shortcuts for common cases such as invoking
    # a Ruby script in a subprocess or capturing output in a string. It also
    # provides an interface for controlling a spawned process's streams.
    #
    # You can make these methods available to your tool by including the
    # following directive in your tool configuration:
    #
    #     include :exec
    #
    # This is a frontend for {Toys::Utils::Exec}. More information is
    # available in that class's documentation.
    #
    # ### Mixin overview
    #
    # The mixin provides a number of methods for spawning processes. The most
    # basic are {#exec} and {#exec_proc}. The {#exec} method spawns an
    # operating system process specified by an executable and a set of
    # arguments. The {#exec_proc} method takes a `Proc` and forks a Ruby
    # process. Both of these can be heavily configured with stream handling,
    # result handling, and numerous other options described below. The mixin
    # also provides convenience methods for common cases such as spawning a
    # Ruby process, spawning a shell script, or capturing output.
    #
    # The mixin also stores default configuration that it applies to processes
    # it spawns. You can change these defaults by calling {#configure_exec}.
    #
    # Underlying the mixin is a service object of type {Toys::Utils::Exec}.
    # Normally you would use the mixin methods to access this functionality,
    # but you can also retrieve the service object itself by calling
    # {Toys::Context#get} with the key {Toys::StandardMixins::Exec::KEY}.
    #
    # ### Controlling processes
    #
    # A process can be started in the *foreground* or the *background*. If you
    # start a foreground process, it will "take over" your standard input and
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
    #     exec(["git", "init"], out: :controller) do |controller|
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
    #     controller = exec(["git", "init"], background: true)
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
    #     controller. If you pass a block to {Toys::StandardMixins::Exec#exec},
    #     it yields the {Toys::Utils::Exec::Controller}, giving you access to
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
    #     result = exec(["git", "init"])
    #     puts "exit code: #{result.exit_code}"
    #
    # The following example demonstrates starting a process in the background,
    # waiting for it to complete, and getting its exit code:
    #
    #     controller = exec(["git", "init"], background: true)
    #     result = controller.result(timeout: 1.0)
    #     if result
    #       puts "exit code: #{result.exit_code}"
    #     else
    #       puts "timed out"
    #     end
    #
    # You can also provide a callback that is executed once a process
    # completes. This callback can be specified as a method name or a `Proc`
    # object, and will be passed the result object. For example:
    #
    #     def run
    #       exec(["git", "init"], result_callback: :handle_result)
    #     end
    #     def handle_result(result)
    #       puts "exit code: #{result.exit_code}"
    #     end
    #
    # Finally, you can force your tool to exit if a subprocess fails, similar
    # to setting the `set -e` option in bash, by setting the
    # `:exit_on_nonzero_status` option. This is often set as a default
    # configuration for all subprocesses run in a tool, by passing it as an
    # argument to the `include` directive:
    #
    #     include :exec, exit_on_nonzero_status: true
    #
    # ### Configuration Options
    #
    # A variety of options can be used to control subprocesses. These can be
    # provided to any method that starts a subprocess. You can also set
    # defaults by passing them as keyword arguments when you `include` the
    # mixin.
    #
    # Options that affect the behavior of subprocesses:
    #
    #  *  `:env` (Hash) Environment variables to pass to the subprocess.
    #     Keys represent variable names and should be strings. Values should be
    #     either strings or `nil`, which unsets the variable.
    #
    #  *  `:background` (Boolean) Runs the process in the background if `true`.
    #
    # Options related to handling results
    #
    #  *  `:result_callback` (Proc,Symbol) A procedure that is called, and
    #     passed the result object, when the subprocess exits. You can provide
    #     a `Proc` object, or the name of a method as a `Symbol`.
    #
    #  *  `:exit_on_nonzero_status` (Boolean) If set to true, a nonzero exit
    #     code will cause the tool to exit immediately with that same code.
    #
    #  *  `:e` (Boolean) A short name for `:exit_on_nonzero_status`.
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
    module Exec
      include Mixin

      ##
      # Context key for the executor object.
      # @return [Object]
      #
      KEY = ::Object.new.freeze

      ##
      # Set default configuration options.
      #
      # See the {Toys::StandardMixins::Exec} module documentation for a
      # description of the options.
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
      # Execute a command. The command can be given as a single string to pass
      # to a shell, or an array of strings indicating a posix command.
      #
      # If the process is not set to run in the background, and a block is
      # provided, a {Toys::Utils::Exec::Controller} will be yielded to it.
      #
      # ### Examples
      #
      # Run a command without a shell, and print the exit code (0 for success):
      #
      #     result = exec(["git", "init"])
      #     puts "exit code: #{result.exit_code}"
      #
      # Run a shell command:
      #
      #     result = exec("cd mydir && git init")
      #     puts "exit code: #{result.exit_code}"
      #
      # @param cmd [String,Array<String>] The command to execute.
      # @param opts [keywords] The command options. See the section on
      #     Configuration Options in the {Toys::StandardMixins::Exec} module
      #     documentation.
      # @yieldparam controller [Toys::Utils::Exec::Controller] A controller for
      #     the subprocess. See the section on Controlling Processes in the
      #     {Toys::StandardMixins::Exec} module documentation.
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
      # ### Example
      #
      # Execute a small script with warnings
      #
      #     exec_ruby(["-w", "-e", "(1..10).each { |i| puts i }"])
      #
      # @param args [String,Array<String>] The arguments to ruby.
      # @param opts [keywords] The command options. See the section on
      #     Configuration Options in the {Toys::StandardMixins::Exec} module
      #     documentation.
      # @yieldparam controller [Toys::Utils::Exec::Controller] A controller for
      #     the subprocess. See the section on Controlling Processes in the
      #     {Toys::StandardMixins::Exec} module documentation.
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
      # ### Example
      #
      # Run a proc in a forked process.
      #
      #     code = proc do
      #       puts "Spawned process ID is #{Process.pid}"
      #     end
      #     puts "Main process ID is #{Process.pid}"
      #     exec_proc(code)
      #
      # @param func [Proc] The proc to call.
      # @param opts [keywords] The command options. See the section on
      #     Configuration Options in the {Toys::StandardMixins::Exec} module
      #     documentation.
      # @yieldparam controller [Toys::Utils::Exec::Controller] A controller for
      #     the subprocess. See the section on Controlling Processes in the
      #     {Toys::StandardMixins::Exec} module documentation.
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
      # The command can be given as a single string or an array of strings,
      # representing the tool to run and the arguments to pass.
      #
      # If the process is not set to run in the background, and a block is
      # provided, a {Toys::Utils::Exec::Controller} will be yielded to it.
      #
      # Beware that some Ruby environments (e.g. JRuby, and Ruby on Windows)
      # do not support this method because they do not support fork.
      #
      # ### Example
      #
      # Run the "system update" tool and pass it an argument.
      #
      #     exec_tool(["system", "update", "--verbose"])
      #
      # @param cmd [String,Array<String>] The tool to execute.
      # @param opts [keywords] The command options. See the section on
      #     Configuration Options in the {Toys::StandardMixins::Exec} module
      #     documentation.
      # @yieldparam controller [Toys::Utils::Exec::Controller] A controller for
      #     the subprocess. See the section on Controlling Processes in the
      #     {Toys::StandardMixins::Exec} module documentation.
      #
      # @return [Toys::Utils::Exec::Controller] The subprocess controller, if
      #     the process is running in the background.
      # @return [Toys::Utils::Exec::Result] The result, if the process ran in
      #     the foreground.
      #
      def exec_tool(cmd, **opts, &block)
        func = Exec._make_tool_caller(cmd)
        opts = Exec._setup_exec_opts(opts, self)
        opts = {log_cmd: "exec tool: #{cmd.inspect}"}.merge(opts)
        self[KEY].exec_proc(func, **opts, &block)
      end

      ##
      # Execute a tool in a separately spawned process.
      #
      # The command can be given as a single string or an array of strings,
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
      # ### Example
      #
      # Run the "system update" tool and pass it an argument.
      #
      #     exec_separate_tool(["system", "update", "--verbose"])
      #
      # @param cmd [String,Array<String>] The tool to execute.
      # @param opts [keywords] The command options. See the section on
      #     Configuration Options in the {Toys::StandardMixins::Exec} module
      #     documentation.
      # @yieldparam controller [Toys::Utils::Exec::Controller] A controller for
      #     the subprocess. See the section on Controlling Processes in the
      #     {Toys::StandardMixins::Exec} module documentation.
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
      # Execute a command. The command can be given as a single string to pass
      # to a shell, or an array of strings indicating a posix command.
      #
      # Captures standard out and returns it as a string.
      # Cannot be run in the background.
      #
      # If a block is provided, a {Toys::Utils::Exec::Controller} will be
      # yielded to it.
      #
      # ### Example
      #
      # Capture the output of an echo command
      #
      #     str = capture(["echo", "hello"])
      #     assert_equal("hello\n", str)
      #
      # @param cmd [String,Array<String>] The command to execute.
      # @param opts [keywords] The command options. See the section on
      #     Configuration Options in the {Toys::StandardMixins::Exec} module
      #     documentation.
      # @yieldparam controller [Toys::Utils::Exec::Controller] A controller for
      #     the subprocess. See the section on Controlling Processes in the
      #     {Toys::StandardMixins::Exec} module documentation.
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
      # ### Example
      #
      # Capture the output of a ruby script.
      #
      #     str = capture_ruby("-e", "(1..3).each { |i| puts i }")
      #     assert_equal "1\n2\n3\n", str
      #
      # @param args [String,Array<String>] The arguments to ruby.
      # @param opts [keywords] The command options. See the section on
      #     Configuration Options in the {Toys::StandardMixins::Exec} module
      #     documentation.
      # @yieldparam controller [Toys::Utils::Exec::Controller] A controller for
      #     the subprocess. See the section on Controlling Processes in the
      #     {Toys::StandardMixins::Exec} module documentation.
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
      # ### Example
      #
      # Run a proc in a forked process and capture its output:
      #
      #     code = proc do
      #       puts Process.pid
      #     end
      #     forked_pid = capture_proc(code).chomp
      #     puts "I forked PID #{forked_pid}"
      #
      # @param func [Proc] The proc to call.
      # @param opts [keywords] The command options. See the section on
      #     Configuration Options in the {Toys::StandardMixins::Exec} module
      #     documentation.
      # @yieldparam controller [Toys::Utils::Exec::Controller] A controller for
      #     the subprocess. See the section on Controlling Processes in the
      #     {Toys::StandardMixins::Exec} module documentation.
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
      # The command can be given as a single string or an array of strings,
      # representing the tool to run and the arguments to pass.
      #
      # If a block is provided, a {Toys::Utils::Exec::Controller} will be
      # yielded to it.
      #
      # Beware that some Ruby environments (e.g. JRuby, and Ruby on Windows)
      # do not support this method because they do not support fork.
      #
      # ### Example
      #
      # Run the "system version" tool and capture its output.
      #
      #     str = capture_tool(["system", "version"]).chomp
      #     puts "Version was #{str}"
      #
      # @param cmd [String,Array<String>] The tool to execute.
      # @param opts [keywords] The command options. See the section on
      #     Configuration Options in the {Toys::StandardMixins::Exec} module
      #     documentation.
      # @yieldparam controller [Toys::Utils::Exec::Controller] A controller for
      #     the subprocess. See the section on Controlling Processes in the
      #     {Toys::StandardMixins::Exec} module documentation.
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
      # The command can be given as a single string or an array of strings,
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
      # ### Example
      #
      # Run the "system version" tool and capture its output.
      #
      #     str = capture_separate_tool(["system", "version"]).chomp
      #     puts "Version was #{str}"
      #
      # @param cmd [String,Array<String>] The tool to execute.
      # @param opts [keywords] The command options. See the section on
      #     Configuration Options in the {Toys::StandardMixins::Exec} module
      #     documentation.
      # @yieldparam controller [Toys::Utils::Exec::Controller] A controller for
      #     the subprocess. See the section on Controlling Processes in the
      #     {Toys::StandardMixins::Exec} module documentation.
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
      # ### Example
      #
      # Run a shell script
      #
      #     exit_code = sh("cd mydir && git init")
      #     puts exit_code == 0 ? "Success!" : "Failed!"
      #
      # @param cmd [String] The shell command to execute.
      # @param opts [keywords] The command options. See the section on
      #     Configuration Options in the {Toys::StandardMixins::Exec} module
      #     documentation.
      # @yieldparam controller [Toys::Utils::Exec::Controller] A controller for
      #     the subprocess. See the section on Controlling Processes in the
      #     {Toys::StandardMixins::Exec} module documentation.
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

      ##
      # Returns an array of standard verbosity flags needed to replicate the
      # current verbosity level. This is useful when you want to spawn tools
      # with the same verbosity level as the current tool.
      #
      # @param short [Boolean] Whether to emit short rather than long flags.
      #     Default is false.
      # @return [Array<String>]
      #
      def verbosity_flags(short: false)
        verbosity = self[Context::Key::VERBOSITY]
        if verbosity.positive?
          if short
            flag = "v" * verbosity
            ["-#{flag}"]
          else
            ::Array.new(verbosity, "--verbose")
          end
        elsif verbosity.negative?
          if short
            flag = "q" * -verbosity
            ["-#{flag}"]
          else
            ::Array.new(-verbosity, "--quiet")
          end
        else
          []
        end
      end

      ##
      # @private
      #
      def self._make_tool_caller(cmd)
        cmd = ::Shellwords.split(cmd) if cmd.is_a?(::String)
        proc { |config| ::Kernel.exit(config[:cli].run(*cmd)) }
      end

      ##
      # @private
      #
      def self._setup_exec_opts(opts, context)
        count = 0
        result_callback = nil
        if opts.key?(:result_callback)
          result_callback = _interpret_result_callback(opts[:result_callback], context)
          count += 1
        end
        [:exit_on_nonzero_status, :e].each do |sym|
          if opts.key?(sym)
            result_callback = _interpret_e(opts[sym], context)
            count += 1
            opts = opts.reject { |k, _v| k == sym }
          end
        end
        if count > 1
          raise ::ArgumentError,
                "You can provide at most one of: result_callback, exit_on_nonzero_status, e"
        end
        opts = opts.merge(result_callback: result_callback) if count == 1
        opts
      end

      ##
      # @private
      #
      def self._interpret_e(value, context)
        return nil unless value
        proc do |result|
          if result.failed?
            context.exit(127)
          elsif result.signaled?
            context.exit(result.signal_code + 128)
          elsif result.error?
            context.exit(result.exit_code)
          end
        end
      end

      ##
      # @private
      #
      def self._interpret_result_callback(value, context)
        if value.is_a?(::Symbol)
          context.method(value)
        elsif value.respond_to?(:call)
          proc { |r| context.instance_eval { value.call(r, context) } }
        elsif value.nil?
          nil
        else
          raise ::ArgumentError, "Bad value for result_callback"
        end
      end

      ##
      # @private
      #
      def self._setup_clean_process(cmd)
        raise ::ArgumentError, "Toys process is unknown" unless ::Toys.executable_path
        cmd = ::Shellwords.split(cmd) if cmd.is_a?(::String)
        cmd = [::RbConfig.ruby, "--disable=gems", ::Toys.executable_path] + cmd
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
    end
  end
end
