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
  ##
  # A Toys-based CLI.
  #
  # Use this class to implement a CLI using Toys.
  #
  class CLI
    ##
    # Create a CLI.
    #
    # @param [String,nil] binary_name The binary name displayed in help text.
    #     Optional. Defaults to the ruby program name.
    # @param [String,nil] config_dir_name A directory with this name that
    #     appears in the loader path, is treated as a configuration directory
    #     whose contents are loaded into the toys configuration. Optional.
    #     If not provided, toplevel configuration directories are disabled.
    #     The default toys CLI sets this to `".toys"`.
    # @param [String,nil] config_file_name A file with this name that appears
    #     in the loader path, is treated as a toplevel configuration file
    #     whose contents are loaded into the toys configuration. Optional.
    #     If not provided, toplevel configuration files are disabled.
    #     The default toys CLI sets this to `".toys.rb"`.
    # @param [String,nil] index_file_name A file with this name that appears
    #     in any configuration directory (not just a toplevel directory) is
    #     loaded first as a standalone configuration file. If not provided,
    #     standalone configuration files are disabled.
    #     The default toys CLI sets this to `".toys.rb"`.
    # @param [String,nil] preload_file_name A file with this name that appears
    #     in any configuration directory (not just a toplevel directory) is
    #     loaded before any configuration files. It is not treated as a
    #     configuration file in that the configuration DSL is not honored. You
    #     may use such a file to define auxiliary Ruby modules and classes that
    #     used by the tools defined in that directory.
    # @param [Array] middleware_stack An array of middleware that will be used
    #     by default for all tools loaded by this CLI. If not provided, uses
    #     {Toys::CLI.default_middleware_stack}.
    # @param [Toys::Utils::ModuleLookup] helper_lookup A lookup for well-known
    #     helper modules. If not provided, uses
    #     {Toys::CLI.default_helper_lookup}.
    # @param [Toys::Utils::ModuleLookup] middleware_lookup A lookup for
    #     well-known middleware classes. If not provided, uses
    #     {Toys::CLI.default_middleware_lookup}.
    # @param [Toys::Utils::ModuleLookup] template_lookup A lookup for
    #     well-known template classes. If not provided, uses
    #     {Toys::CLI.default_template_lookup}.
    # @param [Logger,nil] logger The logger to use. If not provided, a default
    #     logger that writes to `STDERR` is used.
    # @param [Integer,nil] base_level The logger level that should correspond
    #     to zero verbosity. If not provided, will default to the current level
    #     of the logger.
    # @param [Proc,nil] error_handler A proc that is called when an error is
    #     caught. The proc should take a {Toys::ContextualError} argument and
    #     report the error. It should return an exit code (normally nonzero).
    #     Default is a {Toys::CLI::DefaultErrorHandler} writing to the logger.
    #
    def initialize(
      binary_name: nil, middleware_stack: nil,
      config_dir_name: nil, config_file_name: nil,
      index_file_name: nil, preload_file_name: nil,
      helper_lookup: nil, middleware_lookup: nil, template_lookup: nil,
      logger: nil, base_level: nil, error_handler: nil
    )
      @logger = logger || self.class.default_logger
      @base_level = base_level || @logger.level
      @middleware_stack = middleware_stack || self.class.default_middleware_stack
      @binary_name = binary_name || ::File.basename($PROGRAM_NAME)
      @config_dir_name = config_dir_name
      @config_file_name = config_file_name
      @index_file_name = index_file_name
      @preload_file_name = preload_file_name
      @helper_lookup = helper_lookup || self.class.default_helper_lookup
      @middleware_lookup = middleware_lookup || self.class.default_middleware_lookup
      @template_lookup = template_lookup || self.class.default_template_lookup
      @loader = Loader.new(
        index_file_name: index_file_name, preload_file_name: preload_file_name,
        helper_lookup: @helper_lookup, template_lookup: @template_lookup,
        middleware_lookup: @middleware_lookup, middleware_stack: @middleware_stack
      )
      @error_handler = error_handler || DefaultErrorHandler.new
    end

    ##
    # Return the current loader for this CLI
    # @return [Toys::Loader]
    #
    attr_reader :loader

    ##
    # Return the effective binary name used for usage text in this CLI
    # @return [String]
    #
    attr_reader :binary_name

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
    # Add a configuration file or directory to the loader.
    #
    # If a CLI has a default tool set, it might use this to point to the
    # directory that defines those tools. For example, the default Toys CLI
    # uses this to load the builtin tools from the "builtins" directory.
    #
    # @param [String] path A path to add.
    # @param [Boolean] high_priority Add the config at the head of the priority
    #     list rather than the tail.
    #
    def add_config_path(path, high_priority: false)
      @loader.add_path(path, high_priority: high_priority)
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
    # @param [String] search_path A path to search for configs.
    # @param [Boolean] high_priority Add the configs at the head of the
    #     priority list rather than the tail.
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
    # @param [String] start The first directory to add. Defaults to the current
    #     working directory.
    # @param [String] base The last directory to add. Defaults to `"/"`.
    # @param [Boolean] high_priority Add the configs at the head of the
    #     priority list rather than the tail.
    #
    def add_search_path_hierarchy(start: nil, base: "/", high_priority: false)
      path = start || ::Dir.pwd
      paths = []
      loop do
        paths << path
        break if path == base
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
    #
    # @param [String...] args Command line arguments specifying which tool to
    #     run and what arguments to pass to it. You may pass either a single
    #     array of strings, or a series of string arguments.
    # @param [Integer] verbosity Initial verbosity. Default is 0.
    #
    # @return [Integer] The resulting status code
    #
    def run(*args, verbosity: 0)
      tool_definition, remaining = ContextualError.capture("Error finding tool definition") do
        @loader.lookup(args.flatten)
      end
      ContextualError.capture_path(
        "Error during tool execution!", tool_definition.source_path,
        tool_name: tool_definition.full_name, tool_args: remaining
      ) do
        Runner.new(self, tool_definition).run(remaining, verbosity: verbosity)
      end
    rescue ContextualError => e
      @error_handler.call(e)
    end

    ##
    # Make a clone with the same settings but no paths in the loader.
    # This is sometimes useful for running sub-tools.
    #
    # @return [Toys::CLI]
    # @yieldparam cli [Toys::CLI] If you pass a block, the new CLI is yielded
    #     to it so you can add paths and make other modifications.
    #
    def child
      cli = CLI.new(binary_name: @binary_name,
                    config_dir_name: @config_dir_name,
                    config_file_name: @config_file_name,
                    index_file_name: @index_file_name,
                    preload_file_name: @preload_file_name,
                    middleware_stack: @middleware_stack,
                    helper_lookup: @helper_lookup,
                    middleware_lookup: @middleware_lookup,
                    template_lookup: @template_lookup,
                    logger: @logger,
                    base_level: @base_level,
                    error_handler: @error_handler)
      yield cli if block_given?
      cli
    end

    ##
    # A basic error handler that prints out captured errors to a stream or
    # a logger.
    #
    class DefaultErrorHandler
      ##
      # Create an error handler.
      #
      # @param [IO] output Where to write errors. Default is `$stderr`.
      #
      def initialize(output = $stderr)
        @terminal = Utils::Terminal.new(output: output)
      end

      ##
      # The error handler routine. Prints out the error message and backtrace.
      #
      # @param [Exception] error The error that occurred.
      #
      def call(error)
        @terminal.puts(cause_string(error.cause))
        @terminal.puts(context_string(error), :bold)
        -1
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
          "    #{error.cause.class}: #{error.cause.message}"
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
      # @return [Array]
      #
      def default_middleware_stack
        [
          [:set_default_descriptions],
          [:show_help, help_flags: true],
          [:handle_usage_errors],
          [:show_help, fallback_execution: true],
          [:add_verbosity_flags]
        ]
      end

      ##
      # Returns a default ModuleLookup for helpers that points at the
      # StandardHelpers module.
      #
      # @return [Toys::Utils::ModuleLookup]
      #
      def default_helper_lookup
        Utils::ModuleLookup.new.add_path("toys/standard_helpers")
      end

      ##
      # Returns a default ModuleLookup for middleware that points at the
      # StandardMiddleware module.
      #
      # @return [Toys::Utils::ModuleLookup]
      #
      def default_middleware_lookup
        Utils::ModuleLookup.new.add_path("toys/standard_middleware")
      end

      ##
      # Returns a default empty ModuleLookup for templates.
      #
      # @return [Toys::Utils::ModuleLookup]
      #
      def default_template_lookup
        Utils::ModuleLookup.new
      end

      ##
      # Returns a default logger that logs to `$stderr`.
      #
      # @param [IO] stream Stream to write to. Defaults to `$stderr`.
      # @return [Logger]
      #
      def default_logger(stream = $stderr)
        logger = ::Logger.new(stream)
        terminal = Utils::Terminal.new(output: stream)
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
        header = format("[%s %5s]", timestr, severity)
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
