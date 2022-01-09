# frozen_string_literal: true

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
    # Runs the tool corresponding to the given command line, provided as an
    # array of arguments, and returns a {Toys::Exec::Result}.
    #
    # By default, a single CLI is shared among the tests in each test class or
    # _describe_ block. Thus, tools are loaded only once, and the loader is
    # shared across the tests. If you need to isolate loading for a test,
    # create a separate CLI and pass it in using the `:cli` keyword argument.
    #
    # All other keyword arguments are the same as those defined by the
    # `Toys::Utils::Exec` class. If a block is given, a
    # `Toys::Utils::Exec::Controller` is yielded to it. For more info, see the
    # documentation for `Toys::Utils::Exec#exec`.
    #
    # This method uses "fork" to isolate the run of the tool. On an environment
    # without "fork" support, such as JRuby or Ruby on Windows, consider
    # {#exec_separate_tool}.
    #
    # @param cmd [String,Array<String>] The command to execute.
    # @param fallback_to_separate [boolean] If true, fall back to
    #     {exec_separate_tool} if the environment doesn't support fork.
    # @param opts [keywords] The command options.
    # @yieldparam controller [Toys::Utils::Exec::Controller] A controller
    #     for the subprocess streams.
    #
    # @return [Toys::Utils::Exec::Controller] The subprocess controller, if
    #     the process is running in the background.
    # @return [Toys::Utils::Exec::Result] The result, if the process ran in
    #     the foreground.
    #
    def exec_tool(cmd, fallback_to_separate: false, **opts, &block)
      if fallback_to_separate && !::Toys::Compat.allow_fork?
        return exec_separate_tool(cmd, **opts, &block)
      end
      cli = opts.delete(:cli) || toys_cli
      cmd = ::Shellwords.split(cmd) if cmd.is_a?(::String)
      cli.loader.lookup(cmd)
      tool_caller = proc { ::Kernel.exit(cli.run(*cmd)) }
      self.class.toys_exec.exec_proc(tool_caller, **opts, &block)
    end

    ##
    # Runs the tool corresponding to the given command line, provided as an
    # array of arguments, in a separately spawned process, and returns a
    # {Toys::Exec::Result}.
    #
    # Unlike {#exec_tool}, this method does not use the shared CLI, but instead
    # spawns a completely new Toys process for each run. It is thus slower than
    # {#exec_tool}, but compatible with environments without "fork" support,
    # such as JRuby or Ruby on Windows.
    #
    # Supported keyword arguments are the same as those defined by the
    # `Toys::Utils::Exec` class. If a block is given, a
    # `Toys::Utils::Exec::Controller` is yielded to it. For more info, see the
    # documentation for `Toys::Utils::Exec#exec`.
    #
    # @param cmd [String,Array<String>] The command to execute.
    # @param opts [keywords] The command options.
    # @yieldparam controller [Toys::Utils::Exec::Controller] A controller
    #     for the subprocess streams.
    #
    # @return [Toys::Utils::Exec::Controller] The subprocess controller, if
    #     the process is running in the background.
    # @return [Toys::Utils::Exec::Result] The result, if the process ran in
    #     the foreground.
    #
    def exec_separate_tool(cmd, **opts, &block)
      cmd = ::Shellwords.split(cmd) if cmd.is_a?(::String)
      cmd = [::RbConfig.ruby, "--disable=gems", ::Toys.executable_path] + cmd
      self.class.toys_exec.exec(cmd, **opts, &block)
    end

    ##
    # Runs the tool corresponding to the given command line, and returns the
    # data written to `STDOUT`. This is equivalent to calling {#exec_tool}
    # with the keyword arguments `out: :capture, background: false`, and
    # calling `#captured_out` on the result.
    #
    # This method uses "fork" to isolate the run of the tool. On an environment
    # without "fork" support, such as JRuby or Ruby on Windows, consider
    # {#capture_separate_tool}.
    #
    # @param cmd [String,Array<String>] The command to execute.
    # @param stream [:out,:err,:both] The stream to capture. Default is `:out`.
    # @param fallback_to_separate [boolean] If true, fall back to
    #     {capture_separate_tool} if the environment doesn't support fork.
    # @param opts [keywords] The command options.
    # @yieldparam controller [Toys::Utils::Exec::Controller] A controller
    #     for the subprocess streams.
    #
    # @return [Toys::Utils::Exec::Controller] The subprocess controller, if
    #     the process is running in the background.
    # @return [Toys::Utils::Exec::Result] The result, if the process ran in
    #     the foreground.
    #
    def capture_tool(cmd, fallback_to_separate: false, stream: :out, **opts, &block)
      opts = opts.merge(background: false)
      opts = opts.merge(out: :capture) if [:out, :both].include?(stream)
      opts = opts.merge(err: :capture) if [:err, :both].include?(stream)
      result = exec_tool(cmd, fallback_to_separate: fallback_to_separate, **opts, &block)
      outputs = []
      outputs << result.captured_out if [:out, :both].include?(stream)
      outputs << result.captured_err if [:err, :both].include?(stream)
      outputs.join
    end

    ##
    # Runs the tool corresponding to the given command line, and returns the
    # data written to `STDOUT`. This is equivalent to calling
    # {#exec_separate_tool} with the keyword arguments
    # `out: :capture, background: false`, and calling `#captured_out` on the
    # result.
    #
    # Unlike {#capture_tool}, this method does not use the shared CLI, but
    # instead spawns a completely new Toys process for each run. It is thus
    # slower than {#capture_tool}, but compatible with environments without
    # "fork" support, such as JRuby or Ruby on Windows.
    #
    # @param cmd [String,Array<String>] The command to execute.
    # @param stream [:out,:err,:both] The stream to capture. Default is `:out`.
    # @param opts [keywords] The command options.
    # @yieldparam controller [Toys::Utils::Exec::Controller] A controller
    #     for the subprocess streams.
    #
    # @return [Toys::Utils::Exec::Controller] The subprocess controller, if
    #     the process is running in the background.
    # @return [Toys::Utils::Exec::Result] The result, if the process ran in
    #     the foreground.
    #
    def capture_separate_tool(cmd, stream: :out, **opts, &block)
      opts = opts.merge(background: false)
      opts = opts.merge(out: :capture) if [:out, :both].include?(stream)
      opts = opts.merge(err: :capture) if [:err, :both].include?(stream)
      result = exec_separate_tool(cmd, **opts, &block)
      outputs = []
      outputs << result.captured_out if [:out, :both].include?(stream)
      outputs << result.captured_err if [:err, :both].include?(stream)
      outputs.join
    end

    ##
    # Runs the tool corresponding to the given command line, managing streams
    # using a controller. This is equivalent to calling {#exec_tool} with the
    # keyword arguments:
    #
    #     out: :controller,
    #     err: :controller,
    #     in: :controller,
    #     background: block.nil?
    #
    # If a block is given, the command is run in the foreground, the
    # controller is passed to the block during the run, and a result object is
    # returned. If no block is given, the command is run in the background, and
    # the controller object is returned.
    #
    # This method uses "fork" to isolate the run of the tool. On an environment
    # without "fork" support, such as JRuby or Ruby on Windows, consider
    # {#control_separate_tool}.
    #
    # @param cmd [String,Array<String>] The command to execute.
    # @param fallback_to_separate [boolean] If true, fall back to
    #     {capture_separate_tool} if the environment doesn't support fork.
    # @param opts [keywords] The command options.
    # @yieldparam controller [Toys::Utils::Exec::Controller] A controller
    #     for the subprocess streams.
    #
    # @return [Toys::Utils::Exec::Controller] The subprocess controller, if
    #     the process is running in the background.
    # @return [Toys::Utils::Exec::Result] The result, if the process ran in
    #     the foreground.
    #
    def control_tool(cmd, fallback_to_separate: false, **opts, &block)
      opts = opts.merge(out: :controller, err: :controller, in: :controller, background: block.nil?)
      exec_tool(cmd, fallback_to_separate: fallback_to_separate, **opts, &block)
    end

    ##
    # Runs the tool corresponding to the given command line, managing streams
    # using a controller. This is equivalent to calling {#exec_separate_tool}
    # with the keyword arguments:
    #
    #     out: :controller,
    #     err: :controller,
    #     in: :controller,
    #     background: block.nil?
    #
    # If a block is given, the command is run in the foreground, the
    # controller is passed to the block during the run, and a result object is
    # returned. If no block is given, the command is run in the background, and
    # the controller object is returned.
    #
    # Unlike {#control_tool}, this method does not use the shared CLI, but
    # instead spawns a completely new Toys process for each run. It is thus
    # slower than {#control_tool}, but compatible with environments without
    # "fork" support, such as JRuby or Ruby on Windows.
    #
    # @param cmd [String,Array<String>] The command to execute.
    # @param opts [keywords] The command options.
    # @yieldparam controller [Toys::Utils::Exec::Controller] A controller
    #     for the subprocess streams.
    #
    # @return [Toys::Utils::Exec::Controller] The subprocess controller, if
    #     the process is running in the background.
    # @return [Toys::Utils::Exec::Result] The result, if the process ran in
    #     the foreground.
    #
    def control_separate_tool(cmd, **opts, &block)
      opts = opts.merge(out: :controller, err: :controller, in: :controller, background: block.nil?)
      exec_separate_tool(cmd, **opts, &block)
    end

    @toys_mutex = ::Mutex.new

    # @private
    def self.included(klass)
      klass.extend(ClassMethods)
    end

    # @private
    def self.toys_mutex
      @toys_mutex
    end

    # @private
    module ClassMethods
      # @private
      def toys_cli
        Testing.toys_mutex.synchronize do
          @toys_cli ||= StandardCLI.new
        end
      end

      # @private
      def toys_exec
        Testing.toys_mutex.synchronize do
          require "toys/utils/exec"
          @toys_exec ||= Utils::Exec.new
        end
      end
    end
  end
end
