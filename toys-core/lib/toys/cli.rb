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
  # This is the class to instantiate to create a Toys-based command line
  # executable. For example:
  #
  #     #!/usr/bin/env ruby
  #     require "toys-core"
  #     cli = Toys::CLI.new
  #     cli.add_config_block do
  #       def run
  #         puts "Hello, world!"
  #       end
  #     end
  #     exit(cli.run(*ARGV))
  #
  # The currently running CLI is also available at runtime, and can be used by
  # tools that want to invoke other tools. For example:
  #
  #     # My .toys.rb
  #     tool "foo" do
  #       def run
  #         puts "in foo"
  #       end
  #     end
  #     tool "bar" do
  #       def run
  #         puts "in bar"
  #         cli.run "foo"
  #       end
  #     end
  #
  class CLI
    ##
    # Create a CLI.
    #
    # Most configuration parameters (besides tool definitions and tool lookup
    # paths) are set as options passed to the constructor. These options fall
    # roughly into four categories:
    #
    #  *  Options affecting output behavior:
    #      *  `logger`: The logger
    #      *  `base_level`: The default log level
    #      *  `error_handler`: Callback for handling exceptions
    #      *  `executable_name`: The name of the executable
    #  *  Options affecting tool specification
    #      *  `extra_delimibers`: Tool name delimiters besides space
    #      *  `completion`: Tab completion handler
    #  *  Options affecting tool definition
    #      *  `middleware_stack`: The middleware applied to all tools
    #      *  `mixin_lookup`: Where to find well-known mixins
    #      *  `middleware_lookup`: Where to find well-known middleware
    #      *  `template_lookup`: Where to find well-known templates
    #  *  Options affecting tool files and directories
    #      *  `config_dir_name`: Directory name containing tool files
    #      *  `config_file_name`: File name for tools
    #      *  `index_file_name`: Name of index files in tool directories
    #      *  `preload_file_name`: Name of preload files in tool directories
    #      *  `preload_dir_name`: Name of preload directories in tool directories
    #      *  `data_dir_name`: Name of data directories in tool directories
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
    # @param executable_name [String] The executable name displayed in help
    #     text. Optional. Defaults to the ruby program name.
    #
    # @param extra_delimiters [String] A string containing characters that can
    #     function as delimiters in a tool name. Defaults to empty. Allowed
    #     characters are period, colon, and slash.
    # @param completion [Toys::Completion::Base] A specifier for shell tab
    #     completion for the CLI as a whole.
    #     Optional. If not provided, defaults to an instance of
    #     {Toys::CLI::DefaultCompletion}, which delegates completion to the
    #     relevant tool.
    #
    # @param middleware_stack [Array<Toys::Middleware::Spec>] An array of
    #     middleware that will be used by default for all tools.
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
    # @param preload_dir_name [String] A directory with this name that appears
    #     in any configuration directory is searched for Ruby files, which are
    #     preloaded using `require` before any tools in that configuration
    #     directory are defined. Files in a preload directory include normal
    #     Ruby code, rather than Toys DSL definitions. Files in a preload
    #     directory are loaded after any standalone preload file.
    #     Optional. If not provided, preload directories are disabled.
    #     Note: the standard toys executable sets this to `".preload"`.
    # @param data_dir_name [String] A directory with this name that appears in
    #     any configuration directory is added to the data directory search
    #     path for any tool file in that directory.
    #     Optional. If not provided, data directories are disabled.
    #     Note: the standard toys executable sets this to `".data"`.
    #
    def initialize(
      executable_name: nil, middleware_stack: nil, extra_delimiters: "",
      config_dir_name: nil, config_file_name: nil, index_file_name: nil,
      preload_file_name: nil, preload_dir_name: nil, data_dir_name: nil,
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
      @preload_dir_name = preload_dir_name
      @data_dir_name = data_dir_name
      @loader = Loader.new(
        index_file_name: @index_file_name, extra_delimiters: @extra_delimiters,
        preload_dir_name: @preload_dir_name, preload_file_name: @preload_file_name,
        data_dir_name: @data_dir_name,
        mixin_lookup: @mixin_lookup, template_lookup: @template_lookup,
        middleware_lookup: @middleware_lookup, middleware_stack: @middleware_stack
      )
    end

    ##
    # Make a clone with the same settings but no no config blocks and no paths
    # in the loader. This is sometimes useful for calling another tool that has
    # to be loaded from a different configuration.
    #
    # @param opts [keywords] Any configuration arguments that should be
    #     modified from the original. See {#initialize} for a list of
    #     recognized keywords.
    # @return [Toys::CLI]
    # @yieldparam cli [Toys::CLI] If you pass a block, the new CLI is yielded
    #     to it so you can add paths and make other modifications.
    #
    def child(**opts)
      args = {
        executable_name: @executable_name,
        config_dir_name: @config_dir_name,
        config_file_name: @config_file_name,
        index_file_name: @index_file_name,
        preload_dir_name: @preload_dir_name,
        preload_file_name: @preload_file_name,
        data_dir_name: @data_dir_name,
        middleware_stack: @middleware_stack,
        extra_delimiters: @extra_delimiters,
        mixin_lookup: @mixin_lookup,
        middleware_lookup: @middleware_lookup,
        template_lookup: @template_lookup,
        logger: @logger,
        base_level: @base_level,
        error_handler: @error_handler,
        completion: @completion,
      }.merge(opts)
      cli = CLI.new(**args)
      yield cli if block_given?
      cli
    end

    ##
    # The current loader for this CLI.
    # @return [Toys::Loader]
    #
    attr_reader :loader

    ##
    # The effective executable name used for usage text in this CLI.
    # @return [String]
    #
    attr_reader :executable_name

    ##
    # The string of tool name delimiter characters (besides space).
    # @return [String]
    #
    attr_reader :extra_delimiters

    ##
    # The logger used by this CLI.
    # @return [Logger]
    #
    attr_reader :logger

    ##
    # The initial logger level in this CLI, used as the level for verbosity 0.
    # @return [Integer]
    #
    attr_reader :base_level

    ##
    # The overall completion strategy for this CLI.
    # @return [Toys::Completion::Base,Proc]
    #
    attr_reader :completion

    ##
    # Add a specific configuration file or directory to the loader.
    #
    # This is generally used to load a static or "built-in" set of tools,
    # either for a standalone command line executable based on Toys, or to
    # provide a "default" set of tools for a dynamic executable. For example,
    # the main Toys executable uses this to load the builtin tools from its
    # "builtins" directory.
    #
    # @param path [String] A path to add. May reference a single Toys file or
    #     a Toys directory.
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
    # This is used to create tools "inline", and is useful for simple command
    # line executables based on Toys.
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
    # Checks the given directory path. If it contains a config file and/or
    # config directory, those are added to the loader.
    #
    # The main Toys executable uses this method to load tools from directories
    # in the `TOYS_PATH`.
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
    # Walk up the directory hierarchy from the given start location, and add to
    # the loader any config files and directories found.
    #
    # The main Toys executable uses this method to load tools from the current
    # directory and its ancestors.
    #
    # @param start [String] The first directory to add. Defaults to the current
    #     working directory.
    # @param terminate [Array<String>] Optional list of directories that should
    #     terminate the search. If the walk up the directory tree encounters
    #     one of these directories, the search is halted without checking the
    #     terminating directory.
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
    # @return [Integer] The resulting process status code (i.e. 0 for success).
    #
    def run(*args, verbosity: 0, delegated_from: nil)
      tool, remaining = ContextualError.capture("Error finding tool definition") do
        @loader.lookup(args.flatten)
      end
      ContextualError.capture_path(
        "Error during tool execution!", tool.source_info&.source_path,
        tool_name: tool.full_name, tool_args: remaining
      ) do
        default_data = {
          Context::Key::VERBOSITY => verbosity,
          Context::Key::DELEGATED_FROM => delegated_from,
        }
        run_tool(tool, remaining, default_data)
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
    # @param default_data [Hash] Initial tool context data.
    # @return [Integer] The resulting status code
    #
    def run_tool(tool, args, default_data)
      arg_parser = ArgParser.new(self, tool,
                                 default_data: default_data,
                                 require_exact_flag_match: tool.exact_flag_match_required?)
      arg_parser.parse(args).finish
      context = tool.tool_class.new(arg_parser.data)
      tool.run_initializers(context)

      cur_logger = logger
      original_level = cur_logger.level
      cur_logger.level = base_level - context[Context::Key::VERBOSITY]
      begin
        execute_tool_in_context(context, tool)
      ensure
        cur_logger.level = original_level
      end
    end

    def execute_tool_in_context(context, tool)
      executor = proc do
        begin
          if !context[Context::Key::USAGE_ERRORS].empty?
            handle_usage_errors(context, tool)
          elsif !tool.runnable?
            raise NotRunnableError, "No implementation for tool #{tool.display_name.inspect}"
          else
            context.run
          end
        rescue ::Interrupt => e
          raise e unless tool.handles_interrupts?
          handle_interrupt(context, tool.interrupt_handler, e)
        end
      end
      tool.built_middleware.reverse_each do |middleware|
        executor = make_executor(middleware, context, executor)
      end
      catch(:result) do
        executor.call
        0
      end
    end

    def handle_usage_errors(context, tool)
      usage_errors = context[Context::Key::USAGE_ERRORS]
      handler = tool.usage_error_handler
      raise ArgParsingError, usage_errors if handler.nil?
      handler = context.method(handler).to_proc if handler.is_a?(::Symbol)
      if handler.arity.zero?
        context.instance_exec(&handler)
      else
        context.instance_exec(usage_errors, &handler)
      end
    end

    def handle_interrupt(context, handler, exception)
      handler = context.method(handler).to_proc if handler.is_a?(::Symbol)
      if handler.arity.zero?
        context.instance_exec(&handler)
      else
        context.instance_exec(exception, &handler)
      end
    rescue ::Interrupt => e
      raise e if e.equal?(exception)
      handle_interrupt(context, handler, e)
    end

    def make_executor(middleware, context, next_executor)
      if middleware.respond_to?(:run)
        proc { middleware.run(context, &next_executor) }
      else
        next_executor
      end
    end

    ##
    # A basic error handler that prints out captured errors to a stream or
    # a logger.
    #
    class DefaultErrorHandler
      ##
      # Create an error handler.
      #
      # @param output [IO,nil] Where to write errors. Default is `$stderr`.
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
        cause = error
        case error
        when ContextualError
          cause = error.cause
          @terminal.puts(cause_string(cause))
          @terminal.puts(context_string(error), :bold)
        when ::Interrupt
          @terminal.puts
          @terminal.puts("INTERRUPTED", :bold)
        else
          @terminal.puts(cause_string(error))
        end
        exit_code_for(cause)
      end

      private

      def exit_code_for(error)
        case error
        when ArgParsingError
          2
        when NotRunnableError
          126
        when ::Interrupt
          130
        else
          1
        end
      end

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
      #    defaults for description fields.
      # *  {Toys::StandardMiddleware::ShowHelp} adding the `--help` flag and
      #    providing default behavior for namespaces.
      # *  {Toys::StandardMiddleware::HandleUsageErrors}
      # *  {Toys::StandardMiddleware::AddVerbosityFlags} adding the `--verbose`
      #    and `--quiet` flags for managing the logger level.
      #
      # @return [Array<Toys::Middleware::Spec>]
      #
      def default_middleware_stack
        [
          Middleware.spec(:set_default_descriptions),
          Middleware.spec(:show_help, help_flags: true, fallback_execution: true),
          Middleware.spec(:handle_usage_errors),
          Middleware.spec(:add_verbosity_flags),
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
