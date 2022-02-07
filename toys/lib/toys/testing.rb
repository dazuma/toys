# frozen_string_literal: true

require "shellwords"

module Toys
  ##
  # Helpers for writing tool tests.
  #
  # EXPERIMENTAL: Interfaces are subject to change.
  #
  module Testing
    ##
    # Returns the Toys CLI for this test class. By default, a single CLI and
    # Loader are shared by all tests in a given class (or _describe_ block).
    #
    # @return [Toys::CLI]
    #
    def toys_cli
      self.class.toys_cli
    end

    ##
    # Prepares the tool corresponding to the given command line, but instead of
    # running it, yields the execution context to the given block. This can be
    # used to test individual methods in a tool.
    #
    # By default, a single CLI is shared among the tests in each test class or
    # _describe_ block. Thus, tools are loaded only once, and the loader is
    # shared across the tests. If you need to isolate loading for a test,
    # create a separate CLI and pass it in using the `:cli` keyword argument.
    #
    # Note: this method runs the given block in-process. This means you can
    # test assertions within the block, but any input or output performed by
    # the tool's methods that you call, will manifest during your test. If this
    # is a problem, you might consider redirecting the standard streams when
    # calling this method, for example by using
    # [capture_subprocess_io](https://docs.seattlerb.org/minitest/Minitest/Assertions.html#method-i-capture_subprocess_io).
    #
    # @param cmd [String,Array<String>] The command to execute.
    # @yieldparam tool [Toys::Context] The tool context.
    # @return [Object] The value returned from the block.
    #
    # @example
    #   # Given the following tool:
    #
    #   tool "hello" do
    #     flag :shout
    #     def run
    #       puts message
    #     end
    #     def message
    #       shout ? "HELLO" : "hello"
    #     end
    #   end
    #
    #   # You can test the `message` method as follows:
    #
    #   class MyTest < Minitest::Test
    #     include Toys::Testing
    #     def test_message_without_shout
    #       toys_load_tool(["hello"]) do |tool|
    #         assert_equal("hello", tool.message)
    #       end
    #     end
    #     def test_message_with_shout
    #       toys_load_tool(["hello", "--shout"]) do |tool|
    #         assert_equal("HELLO", tool.message)
    #       end
    #     end
    #   end
    #
    def toys_load_tool(cmd, cli: nil, &block)
      cli ||= toys_cli
      cmd = ::Shellwords.split(cmd) if cmd.is_a?(::String)
      cli.load_tool(*cmd, &block)
    end

    ##
    # Runs the tool corresponding to the given command line, in-process, and
    # returns the result code.
    #
    # By default, a single CLI is shared among the tests in each test class or
    # _describe_ block. Thus, tools are loaded only once, and the loader is
    # shared across the tests. If you need to isolate loading for a test,
    # create a separate CLI and pass it in using the `:cli` keyword argument.
    #
    # Note: This method runs the tool in-process. This is often faster than
    # running it in a separate process with {#toys_exec_tool}, but it also
    # means any input or output performed by the tool, will manifest during
    # your test. If this is a problem, you might consider redirecting the
    # standard streams when calling this method, for example by using
    # [capture_subprocess_io](https://docs.seattlerb.org/minitest/Minitest/Assertions.html#method-i-capture_subprocess_io).
    #
    # @param cmd [String,Array<String>] The command to execute.
    # @return [Integer] The integer result code (i.e. 0 for success).
    #
    def toys_run_tool(cmd, cli: nil)
      cli ||= toys_cli
      cmd = ::Shellwords.split(cmd) if cmd.is_a?(::String)
      cli.run(*cmd)
    end

    ##
    # Runs the tool corresponding to the given command line, in a separate
    # forked process, and returns a {Toys::Exec::Result}. You can either
    # provide a block to control the process, or simply let it run and capture
    # its output.
    #
    # By default, a single CLI is shared among the tests in each test class or
    # _describe_ block. Thus, tools are loaded only once, and the loader is
    # shared across the tests. If you need to isolate loading for a test,
    # create a separate CLI and pass it in using the `:cli` keyword argument.
    #
    # All other keyword arguments are the same as those defined by the
    # {Toys::Utils::Exec} class. If a block is given, all streams are directed
    # to a {Toys::Utils::Exec::Controller} which is yielded to the block. If no
    # block is given, the output and error streams are captured and the input
    # stream is closed.
    #
    # This method uses "fork" to isolate the run of the tool. It will not work
    # on environments such as JRuby or Ruby on Windows that do not support
    # process forking.
    #
    # @param cmd [String,Array<String>] The command to execute.
    # @param opts [keywords] The command options.
    # @yieldparam controller [Toys::Utils::Exec::Controller] A controller
    #     for the subprocess streams.
    # @return [Toys::Utils::Exec::Result] The process result.
    #
    # @example
    #   # Given the following tool:
    #
    #   tool "hello" do
    #     flag :shout
    #     def run
    #       puts message
    #     end
    #     def message
    #       shout ? "HELLO" : "hello"
    #     end
    #   end
    #
    #   # You can test the tool's output as follows:
    #
    #   class MyTest < Minitest::Test
    #     include Toys::Testing
    #     def test_output_without_shout
    #       result = toys_exec_tool(["hello"])
    #       assert_equal("hello hello\n", result.captured_out)
    #     end
    #     def test_with_shout
    #       result = toys_exec_tool(["hello", "--shout"])
    #       assert_equal("HELLO HELLO\n", result.captured_out)
    #     end
    #   end
    #
    def toys_exec_tool(cmd, cli: nil, **opts, &block)
      cli ||= toys_cli
      cmd = ::Shellwords.split(cmd) if cmd.is_a?(::String)
      opts =
        if block
          {
            out: :controller,
            err: :controller,
            in: :controller,
          }.merge(opts)
        else
          {
            out: :capture,
            err: :capture,
            in: :close,
          }.merge(opts)
        end
      cli.loader.lookup(cmd)
      tool_caller = proc { ::Kernel.exit(cli.run(*cmd)) }
      self.class.toys_exec.exec_proc(tool_caller, **opts, &block)
    end
    alias exec_tool toys_exec_tool

    @toys_mutex = ::Mutex.new

    ##
    # @private
    #
    def self.included(klass)
      klass.extend(ClassMethods)
    end

    ##
    # @private
    #
    def self.toys_mutex
      @toys_mutex
    end

    ##
    # @private
    #
    def self.toys_custom_paths(paths = :read)
      @toys_custom_paths = paths unless paths == :read
      @toys_custom_paths
    end

    ##
    # @private
    #
    def self.toys_include_builtins(value = :read)
      @toys_include_builtins = value unless value == :read
      @toys_include_builtins
    end

    @toys_custom_paths = nil
    @toys_include_builtins = true

    ##
    # Class methods added to a test class or describe block when
    # {Toys::Testing} is included. Generally, these are methods that configure
    # the load path for the CLI in scope for the block.
    #
    module ClassMethods
      ##
      # Configure the Toys CLI to load tools from the given paths, and ignore
      # the current directory and global paths.
      #
      # @param paths [String,Array<String>] The paths to load from.
      #
      def toys_custom_paths(paths = :read)
        @toys_custom_paths = paths unless paths == :read
        return @toys_custom_paths if defined?(@toys_custom_paths)
        begin
          super
        rescue ::NoMethodError
          Testing.toys_custom_paths
        end
      end

      ##
      # Configure the Toys CLI to include or exclude builtins. Normally
      # builtins are included unless false is passed to this method.
      #
      # @param value [boolean] Whether to include builtins.
      #
      def toys_include_builtins(value = :read)
        @toys_include_builtins = value unless value == :read
        return @toys_include_builtins if defined?(@toys_include_builtins)
        begin
          super
        rescue ::NoMethodError
          Testing.toys_include_builtins
        end
      end

      ##
      # @private
      #
      def toys_cli
        Testing.toys_mutex.synchronize do
          @toys_cli ||= StandardCLI.new(custom_paths: toys_custom_paths,
                                        include_builtins: toys_include_builtins)
        end
      end

      ##
      # @private
      #
      def toys_exec
        Testing.toys_mutex.synchronize do
          require "toys/utils/exec"
          @toys_exec ||= Utils::Exec.new
        end
      end
    end
  end
end
