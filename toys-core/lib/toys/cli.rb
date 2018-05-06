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
    # Create a CLI
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
    #     by default for all tools loaded by this CLI.
    # @param [Logger,nil] logger The logger to use. If not provided, a default
    #     logger that writes to `STDERR` is used.
    # @param [Integer,nil] base_level The logger level that should correspond
    #     to zero verbosity. If not provided, will default to the current level
    #     of the logger.
    #
    def initialize(
      binary_name: nil,
      config_dir_name: nil,
      config_file_name: nil,
      index_file_name: nil,
      preload_file_name: nil,
      middleware_stack: nil,
      logger: nil,
      base_level: nil
    )
      @logger = logger || self.class.default_logger
      @base_level = base_level || @logger.level
      @middleware_stack = middleware_stack || self.class.default_middleware_stack
      @binary_name = binary_name || ::File.basename($PROGRAM_NAME)
      @config_dir_name = config_dir_name
      @config_file_name = config_file_name
      @index_file_name = index_file_name
      @preload_file_name = preload_file_name
      @loader = Loader.new(
        index_file_name: index_file_name,
        preload_file_name: preload_file_name,
        middleware_stack: middleware_stack
      )
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
      @loader.execute(self, args.flatten, verbosity: verbosity)
    end

    ##
    # Make a clone with the same settings but no paths in the loader.
    #
    # @return [Toys::CLI]
    #
    def empty_clone
      CLI.new(binary_name: @binary_name,
              config_dir_name: @config_dir_name,
              config_file_name: @config_file_name,
              index_file_name: @index_file_name,
              preload_file_name: @preload_file_name,
              middleware_stack: @middleware_stack,
              logger: @logger,
              base_level: @base_level)
    end

    class << self
      ##
      # Returns a default set of middleware that may be used as a starting
      # point for a typical CLI. This set includes:
      #
      # *  {Toys::Middleware::HandleUsageErrors}
      # *  {Toys::Middleware::ShowUsage} adding the `--help` switch and
      #    providing default behavior for groups
      # *  {Toys::Middleware::AddVerbositySwitches} adding the `--verbose` and
      #    `--quiet` switches for managing the logger level
      #
      # @return [Array]
      #
      def default_middleware_stack
        [
          :handle_usage_errors,
          :show_usage,
          :add_verbosity_switches
        ]
      end

      ##
      # Returns a default logger that logs to `STDERR`.
      #
      # @return [Logger]
      #
      def default_logger
        logger = ::Logger.new(::STDERR)
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
          timestr = time.strftime("%Y-%m-%d %H:%M:%S")
          format("[%s %5s]  %s\n", timestr, severity, msg_str)
        end
        logger.level = ::Logger::WARN
        logger
      end
    end
  end
end
