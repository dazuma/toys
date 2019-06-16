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

require "logger"
require "toys/completion"

module Toys
  ##
  # A Toys-based CLI.
  #
  # This is the entry point for command line execution. It includes the set of
  # tool definitions (and/or information on how to load them from the file
  # system), configuration parameters such as logging and error handling, and a
  # method to call to invoke a command.
  #
  class CLI
    ##
    # Create a CLI.
    #
    # @param logger [Logger] The logger to use.
    #     Optional. If not provided, will use a default logger that writes
    #     formatted output to `STDERR`, as defined by
    #     {Toys::CLI.default_logger}.
    # @param base_level [Integer] The logger level that should correspond
    #     to zero verbosity.
    #     Optional. If not provided, defaults to the current level of the
    #     logger (which is often `Logger::WARN`).
    # @param error_handler [Proc,nil] A proc that is called when an error is
    #     caught. The proc should take a {Toys::ContextualError} argument and
    #     report the error. It should return an exit code (normally nonzero).
    #     Optional. If not provided, defaults to an instance of
    #     {Toys::CLI::DefaultErrorHandler}, which displays an error message to
    #     `STDERR`.
    # @param completion [Toys::Completion::Base] A specifier for shell tab
    #     completion for the CLI as a whole.
    #     Optional. If not provided, defaults to an instance of
    #     {Toys::CLI::DefaultCompletion}, which delegates completion to the
    #     relevant tool.
    #
    # @param middleware_stack [Array] An array of middleware that will be used
    #     by default for all tools loaded by this CLI.
    #     Optional. If not provided, uses a default set of middleware defined
    #     in {Toys::CLI.default_middleware_stack}. To include no middleware,
    #     pass the empty array explicitly.
    # @param mixin_lookup [Toys::ModuleLookup] A lookup for well-known mixin
    #     modules (i.e. with symbol names).
    #     Optional. If not provided, defaults to the set of standard mixins
    #     provided by toys-core, as defined by
    #     {Toys::CLI.default_mixin_lookup}. If you explicitly want no standard
    #     mixins, pass an empty instance of {Toys::ModuleLookup}.
    # @param middleware_lookup [Toys::ModuleLookup] A lookup for well-known
    #     middleware classes.
    #     Optional. If not provided, defaults to the set of standard middleware
    #     classes provided by toys-core, as defined by
    #     {Toys::CLI.default_middleware_lookup}. If you explicitly want no
    #     standard middleware, pass an empty instance of
    #     {Toys::ModuleLookup}.
    # @param template_lookup [Toys::ModuleLookup] A lookup for well-known
    #     template classes.
    #     Optional. If not provided, defaults to the set of standard template
    #     classes provided by toys core, as defined by
    #     {Toys::CLI.default_template_lookup}. If you explicitly want no
    #     standard tenokates, pass an empty instance of {Toys::ModuleLookup}.
    #
    # @param config_dir_name [String] A directory with this name that appears
    #     in the loader path, is treated as a configuration directory whose
    #     contents are loaded into the toys configuration.
    #     Optional. If not provided, toplevel configuration directories are
    #     disabled.
    #     Note: the standard toys executable sets this to `".toys"`.
    # @param config_file_name [String] A file with this name that appears in
    #     the loader path, is treated as a toplevel configuration file whose
    #     contents are loaded into the toys configuration. This does not
    #     include "index" configuration files located within a configuration
    #     directory.
    #     Optional. If not provided, toplevel configuration files are disabled.
    #     Note: the standard toys executable sets this to `".toys.rb"`.
    # @param index_file_name [String] A file with this name that appears in any
    #     configuration directory is loaded first as a standalone configuration
    #     file. This does not include "toplevel" configuration files outside
    #     configuration directories.
    #     Optional. If not provided, index configuration files are disabled.
    #     Note: the standard toys executable sets this to `".toys.rb"`.
    # @param preload_file_name [String] A file with this name that appears
    #     in any configuration directory is preloaded using `require` before
    #     any tools in that configuration directory are defined. A preload file
    #     includes normal Ruby code, rather than Toys DSL definitions. The
    #     preload file is loaded before any files in a preload directory.
    #     Optional. If not provided, preload files are disabled.
    #     Note: the standard toys executable sets this to `".preload.rb"`.
    # @param preload_directory_name [String] A directory with this name that
    #     appears in any configuration directory is searched for Ruby files,
    #     which are preloaded using `require` before any tools in that
    #     configuration directory are defined. Files in a preload directory
    #     include normal Ruby code, rather than Toys DSL definitions. Files in
    #     a preload directory are loaded after any standalone preload file.
    #     Optional. If not provided, preload directories are disabled.
    #     Note: the standard toys executable sets this to `".preload"`.
    # @param data_directory_name [String] A directory with this name that
    #     appears in any configuration directory is added to the data directory
    #     search path for any tool file in that directory.
    #     Optional. If not provided, data directories are disabled.
    #     Note: the standard toys executable sets this to `".data"`.
    #
    # @param executable_name [String] The executable name displayed in help
    #     text. Optional. Defaults to the ruby program name.
    # @param extra_delimiters [String] A string containing characters that can
    #     function as delimiters in a tool name. Defaults to empty. Allowed
    #     characters are period, colon, and slash.
    #
    def initialize(
      executable_name: nil, middleware_stack: nil, extra_delimiters: "",
      config_dir_name: nil, config_file_name: nil, index_file_name: nil,
      preload_file_name: nil, preload_directory_name: nil, data_directory_name: nil,
      mixin_lookup: nil, middleware_lookup: nil, template_lookup: nil,
      logger: nil, base_level: nil, error_handler: nil, completion: nil
    )
      @executable_name = executable_name || ::File.basename($PROGRAM_NAME)
      @middleware_stack = middleware_stack || CLI.default_middleware_stack
      @mixin_lookup = mixin_lookup || CLI.default_mixin_lookup
      @middleware_lookup = middleware_lookup || CLI.default_middleware_lookup
      @template_lookup = template_lookup || CLI.default_template_lookup
      @error_handler = error_handler || DefaultErrorHandler.new
      @completion = completion || DefaultCompletion.new
      @logger = logger || CLI.default_logger
      @base_level = base_level || @logger.level
      @extra_delimiters = extra_delimiters
      @config_dir_name = config_dir_name
      @config_file_name = config_file_name
      @index_file_name = index_file_name
      @preload_file_name = preload_file_name
      @preload_directory_name = preload_directory_name
      @data_directory_name = data_directory_name
      @loader = Loader.new(
        index_file_name: @index_file_name, extra_delimiters: @extra_delimiters,
        preload_directory_name: @preload_directory_name, preload_file_name: @preload_file_name,
        data_directory_name: @data_directory_name,
        mixin_lookup: @mixin_lookup, template_lookup: @template_lookup,
        middleware_lookup: @middleware_lookup, middleware_stack: @middleware_stack
      )
    end

    ##
    # Make a clone with the same settings but no paths in the loader.
    # This is sometimes useful for running sub-tools that have to be loaded
    # from a different configuration.
    #
    # @param _opts [Hash] Unused options that can be used by subclasses.
    # @return [Toys::CLI]
    # @yieldparam cli [Toys::CLI] If you pass a block, the new CLI is yielded
    #     to it so you can add paths and make other modifications.
    #
    def child(_opts = {})
      cli = CLI.new(executable_name: @executable_name,
                    config_dir_name: @config_dir_name,
                    config_file_name: @config_file_name,
                    index_file_name: @index_file_name,
                    preload_directory_name: @preload_directory_name,
                    preload_file_name: @preload_file_name,
                    data_directory_name: @data_directory_name,
                    middleware_stack: @middleware_stack,
                    extra_delimiters: @extra_delimiters,
                    mixin_lookup: @mixin_lookup,
                    middleware_lookup: @middleware_lookup,
                    template_lookup: @template_lookup,
                    logger: @logger,
                    base_level: @base_level,
                    error_handler: @error_handler,
                    completion: @completion)
      yield cli if block_given?
      cli
    end

    ##
    # Return the current loader for this CLI
    # @return [Toys::Loader]
    #
    attr_reader :loader

    ##
    # Return the effective executable name used for usage text in this CLI
    # @return [String]
    #
    attr_reader :executable_name

    ##
    # Return the string of delimiters
    # @return [String]
    #
    attr_reader :extra_delimiters

    ##
    # Return the logger used by this CLI
    # @return [Logger]
    #
    attr_reader :logger

    ##
    # Return the initial logger level in this CLI, used as the level for
    # verbosity 0.
    # @return [Integer]
    #
    attr_reader :base_level

    ##
    # Returns the overall completion strategy for this CLI.
    # @return [Toys::Completion::Base,Proc]
    #
    attr_reader :completion

    ##
    # Add a configuration file or directory to the loader.
    #
    # If a CLI has a default tool set, it might use this to point to the
    # directory that defines those tools. For example, the default Toys CLI
    # uses this to load the builtin tools from the "builtins" directory.
    #
    # @param path [String] A path to add.
    # @param high_priority [Boolean] Add the config at the head of the priority
    #     list rather than the tail.
    # @return [self]
    #
    def add_config_path(path, high_priority: false)
      @loader.add_path(path, high_priority: high_priority)
      self
    end

    ##
    # Add a configuration block to the loader.
    #
    # @param high_priority [Boolean] Add the config at the head of the priority
    #     list rather than the tail.
    # @param name [String] The source name that will be shown in documentation
    #     for tools defined in this block. If omitted, a default unique string
    #     will be generated.
    # @param block [Proc] The block of configuration, executed in the context
    #     of the tool DSL {Toys::DSL::Tool}.
    # @return [self]
    #
    def add_config_block(high_priority: false, name: nil, &block)
      @loader.add_block(high_priority: high_priority, name: name, &block)
      self
    end

    ##
    # Searches the given directory for a well-known config directory and/or
    # config file. If found, these are added to the loader.
    #
    # Typically, a CLI will use this to find toys configs in the current
    # working directory, the user's home directory, or some other well-known
    # general configuration-oriented directory such as "/etc".
    #
    # @param search_path [String] A path to search for configs.
    # @param high_priority [Boolean] Add the configs at the head of the
    #     priority list rather than the tail.
    # @return [self]
    #
    def add_search_path(search_path, high_priority: false)
      paths = []
      if @config_file_name
        file_path = ::File.join(search_path, @config_file_name)
        paths << file_path if !::File.directory?(file_path) && ::File.readable?(file_path)
      end
      if @config_dir_name
        dir_path = ::File.join(search_path, @config_dir_name)
        paths << dir_path if ::File.directory?(dir_path) && ::File.readable?(dir_path)
      end
      @loader.add_path(paths, high_priority: high_priority)
      self
    end

    ##
    # A convenience method that searches the current working directory, and all
    # ancestor directories, for configs to add to the loader.
    #
    # @param start [String] The first directory to add. Defaults to the current
    #     working directory.
    # @param terminate [Array<String>] Optional list of directories that should
    #     terminate the search.
    # @param high_priority [Boolean] Add the configs at the head of the
    #     priority list rather than the tail.
    # @return [self]
    #
    def add_search_path_hierarchy(start: nil, terminate: [], high_priority: false)
      path = start || ::Dir.pwd
      paths = []
      loop do
        break if terminate.include?(path)
        paths << path
        next_path = ::File.dirname(path)
        break if next_path == path
        path = next_path
      end
      paths.reverse! if high_priority
      paths.each do |p|
        add_search_path(p, high_priority: high_priority)
      end
      self
    end

    ##
    # Run the CLI with the given command line arguments.
    # Handles exceptions using the error handler.
    #
    # @param args [String...] Command line arguments specifying which tool to
    #     run and what arguments to pass to it. You may pass either a single
    #     array of strings, or a series of string arguments.
    # @param verbosity [Integer] Initial verbosity. Default is 0.
    #
    # @return [Integer] The resulting status code
    #
    def run(*args, verbosity: 0)
      tool, remaining = ContextualError.capture("Error finding tool definition") do
        @loader.lookup(args.flatten)
      end
      ContextualError.capture_path(
        "Error during tool execution!", tool.source_info&.source_path,
        tool_name: tool.full_name, tool_args: remaining
      ) do
        run_tool(tool, remaining, verbosity: verbosity)
      end
    rescue ContextualError, ::Interrupt => e
      @error_handler.call(e).to_i
    end

    private

    ##
    # Run the given tool with the given arguments.
    # Does not handle exceptions.
    #
    # @param tool [Toys::Tool] The tool to run.
    # @param args [Array<String>] Command line arguments passed to the tool.
    # @param verbosity [Integer] Initial verbosity. Default is 0.
    # @return [Integer] The resulting status code
    #
    def run_tool(tool, args, verbosity: 0)
      arg_parser = ArgParser.new(self, tool, verbosity: verbosity)
      arg_parser.parse(args).finish
      context = tool.tool_class.new(arg_parser.data)
      tool.run_initializers(context)

      cur_logger = logger
      original_level = cur_logger.level
      cur_logger.level = base_level - context[Context::Key::VERBOSITY]
      begin
        perform_execution(tool, cur_logger, context)
      ensure
        cur_logger.level = original_level
      end
    end

    def perform_execution(tool, cur_logger, context)
      executor = proc do
        unless tool.runnable?
          cur_logger.fatal("No implementation for tool #{tool.display_name.inspect}")
          context.exit(-1)
        end
        interruptible = tool.interruptible?
        begin
          context.run
        rescue ::Interrupt => e
          raise e unless interruptible
          handle_interrupt(context, e)
        end
      end
      tool.middleware_stack.reverse_each do |middleware|
        executor = make_executor(middleware, context, executor)
      end
      catch(:result) do
        executor.call
        0
      end
    end

    def handle_interrupt(context, exception)
      if context.method(:interrupt).arity.zero?
        context.interrupt
      else
        context.interrupt(exception)
      end
    rescue ::Interrupt => e
      raise e if e.equal?(exception)
      handle_interrupt(context, e)
    end

    def make_executor(middleware, context, next_executor)
      proc { middleware.run(context, &next_executor) }
    end

    ##
    # A basic error handler that prints out captured errors to a stream or
    # a logger.
    #
    class DefaultErrorHandler
      ##
      # Create an error handler.
      #
      # @param output [IO] Where to write errors. Default is `$stderr`.
      #
      def initialize(output: $stderr)
        require "toys/utils/terminal"
        @terminal = Utils::Terminal.new(output: output)
      end

      ##
      # The error handler routine. Prints out the error message and backtrace,
      # and returns the correct result code.
      #
      # @param error [Exception] The error that occurred.
      # @return [Integer] The result code for the execution.
      #
      def call(error)
        case error
        when ContextualError
          @terminal.puts(cause_string(error.cause))
          @terminal.puts(context_string(error), :bold)
          -1
        when ::Interrupt
          @terminal.puts
          @terminal.puts("INTERRUPTED", :bold)
          130
        else
          @terminal.puts(cause_string(error))
          1
        end
      end

      private

      def cause_string(cause)
        lines = ["#{cause.class}: #{cause.message}"]
        cause.backtrace.each_with_index.reverse_each do |bt, i|
          lines << "    #{(i + 1).to_s.rjust(3)}: #{bt}"
        end
        lines.join("\n")
      end

      def context_string(error)
        lines = [
          error.banner || "Unexpected error!",
          "    #{error.cause.class}: #{error.cause.message}",
        ]
        if error.config_path
          lines << "    in config file: #{error.config_path}:#{error.config_line}"
        end
        if error.tool_name
          lines << "    while executing tool: #{error.tool_name.join(' ').inspect}"
          if error.tool_args
            lines << "    with arguments: #{error.tool_args.inspect}"
          end
        end
        lines.join("\n")
      end
    end

    ##
    # A Completion that implements the default algorithm for a CLI. This
    # algorithm simply determines the tool and uses its completion.
    #
    class DefaultCompletion < Completion::Base
      ##
      # Returns candidates for the current completion.
      #
      # @param context [Toys::Completion::Context] the current completion
      #     context including the string fragment.
      # @return [Array<Toys::Completion::Candidate>] an array of candidates
      #
      def call(context)
        context.tool.completion.call(context)
      end
    end

    class << self
      ##
      # Returns a default set of middleware that may be used as a starting
      # point for a typical CLI. This set includes the following in order:
      #
      # *  {Toys::StandardMiddleware::SetDefaultDescriptions} providing
      #    defaults for description fields
      # *  {Toys::StandardMiddleware::ShowHelp} adding the `--help` flag
      # *  {Toys::StandardMiddleware::HandleUsageErrors}
      # *  {Toys::StandardMiddleware::ShowHelp} providing default behavior for
      #    namespaces
      # *  {Toys::StandardMiddleware::AddVerbosityFlags} adding the `--verbose`
      #    and `--quiet` flags for managing the logger level
      #
      # @return [Array<Toys::Middleware>]
      #
      def default_middleware_stack
        [
          [:set_default_descriptions],
          [:show_help, help_flags: true],
          [:handle_usage_errors],
          [:show_help, fallback_execution: true],
          [:add_verbosity_flags],
        ]
      end

      ##
      # Returns a default ModuleLookup for mixins that points at the
      # StandardMixins module.
      #
      # @return [Toys::ModuleLookup]
      #
      def default_mixin_lookup
        ModuleLookup.new.add_path("toys/standard_mixins")
      end

      ##
      # Returns a default ModuleLookup for middleware that points at the
      # StandardMiddleware module.
      #
      # @return [Toys::ModuleLookup]
      #
      def default_middleware_lookup
        ModuleLookup.new.add_path("toys/standard_middleware")
      end

      ##
      # Returns a default empty ModuleLookup for templates.
      #
      # @return [Toys::ModuleLookup]
      #
      def default_template_lookup
        ModuleLookup.new
      end

      ##
      # Returns a default logger that writes formatted logs to a given stream.
      #
      # @param output [IO] The stream to output to (defaults to `$stderr`)
      # @return [Logger]
      #
      def default_logger(output: nil)
        require "toys/utils/terminal"
        output ||= $stderr
        logger = ::Logger.new(output)
        terminal = Utils::Terminal.new(output: output)
        logger.formatter = proc do |severity, time, _progname, msg|
          msg_str =
            case msg
            when ::String
              msg
            when ::Exception
              "#{msg.message} (#{msg.class})\n" << (msg.backtrace || []).join("\n")
            else
              msg.inspect
            end
          format_log(terminal, time, severity, msg_str)
        end
        logger.level = ::Logger::WARN
        logger
      end

      private

      def format_log(terminal, time, severity, msg)
        timestr = time.strftime("%Y-%m-%d %H:%M:%S")
        header = format("[%<time>s %<sev>5s]", time: timestr, sev: severity)
        styled_header =
          case severity
          when "FATAL"
            terminal.apply_styles(header, :bright_magenta, :bold, :underline)
          when "ERROR"
            terminal.apply_styles(header, :bright_red, :bold)
          when "WARN"
            terminal.apply_styles(header, :bright_yellow)
          when "INFO"
            terminal.apply_styles(header, :bright_cyan)
          when "DEBUG"
            terminal.apply_styles(header, :white)
          else
            header
          end
        "#{styled_header}  #{msg}\n"
      end
    end
  end
end
