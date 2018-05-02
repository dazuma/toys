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
    # Path to default builtins
    # @return [String]
    #
    BUILTINS_PATH = ::File.join(__dir__, "builtins").freeze

    ##
    # Default name of toys configuration directory
    # @return [String]
    #
    DEFAULT_DIR_NAME = ".toys".freeze

    ##
    # Default name of toys configuration file
    # @return [String]
    #
    DEFAULT_FILE_NAME = ".toys.rb".freeze

    ##
    # Default name of toys preload file
    # @return [String]
    #
    DEFAULT_PRELOAD_NAME = ".preload.rb".freeze

    ##
    # Default name of toys binary
    # @return [String]
    #
    DEFAULT_BINARY_NAME = "toys".freeze

    ##
    # Default help text for the root tool
    # @return [String]
    #
    DEFAULT_ROOT_DESC =
      "Toys is your personal command line tool. You can add to the list of" \
      " commands below by writing scripts in Ruby using a simple DSL, and" \
      " toys will organize and document them, and make them available" \
      " globally or scoped to specific directories that you choose." \
      " For detailed information, see https://www.rubydoc.info/gems/toys".freeze

    ##
    # Create a CLI
    #
    # @param [String,nil] binary_name The binary name displayed in help text.
    #     Optional. Defaults to the ruby program name.
    # @param [Logger,nil] logger The logger to use. If not provided, a default
    #     logger that writes to `STDERR` is used.
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
    # @param [Array] middleware An array of middleware that will be used by
    #     default for all tools loaded by this CLI.
    # @param [String] root_desc The description of the root tool.
    #
    def initialize(
      binary_name: nil,
      logger: nil,
      config_dir_name: nil,
      config_file_name: nil,
      index_file_name: nil,
      preload_file_name: nil,
      middleware: [],
      root_desc: nil
    )
      logger ||= self.class.default_logger
      @loader = Loader.new(
        config_dir_name: config_dir_name,
        config_file_name: config_file_name,
        index_file_name: index_file_name,
        preload_file_name: preload_file_name,
        middleware: middleware,
        root_desc: root_desc
      )
      @context_base = Context::Base.new(@loader, binary_name, logger)
    end

    ##
    # Add one or more configuration files/directories to the loader.
    #
    # If a CLI has a default tool set, it might use this to point to the
    # directory that defines those tools. For example, the default Toys CLI
    # uses this to load the builtin tools from the `builtins` directory.
    #
    # @param [String,Array<String>] paths One or more paths to add.
    #
    def add_config_paths(paths)
      @loader.add_config_paths(paths)
      self
    end

    ##
    # Add one or more path directories to the loader. These directories are
    # searched for config directories and config files. Typically a CLI may
    # include the current directory, or the user's home directory, `/etc` or
    # other configuration-centric directories here.
    #
    # @param [String,Array<String>] paths One or more paths to add.
    #
    def add_paths(paths)
      @loader.add_paths(paths)
      self
    end

    ##
    # Add the given path and all ancestor directories to the loader as paths.
    # You may optionally provide a stopping point using the `base` argument,
    # which, if present, will be the _last_ directory added.
    #
    # @param [String] path The first directory to add
    # @param [String] base The last directory to add. Defaults to `"/"`.
    #
    def add_path_hierarchy(path = nil, base = "/")
      path ||= ::Dir.pwd
      paths = []
      loop do
        paths << path
        break if !base || path == base
        next_path = ::File.dirname(path)
        break if next_path == path
        path = next_path
      end
      @loader.add_paths(paths)
      self
    end

    ##
    # Add a standard set of paths. This includes the contents of the
    # `TOYS_PATH` environment variable if present, the current user's home
    # directory, and any system configuration directories such as `/etc`.
    #
    def add_standard_paths
      toys_path = ::ENV["TOYS_PATH"].to_s.split(::File::PATH_SEPARATOR)
      if toys_path.empty?
        toys_path << ::ENV["HOME"] if ::ENV["HOME"]
        toys_path << "/etc" if ::File.directory?("/etc") && ::File.readable?("/etc")
      end
      @loader.add_paths(toys_path)
      self
    end

    ##
    # Run the CLI with the given command line arguments.
    #
    def run(*args)
      exit(@context_base.run(args.flatten, verbosity: 0))
    end

    class << self
      ##
      # Configure and create the standard Toys CLI.
      #
      # @return [Toys::CLI]
      #
      def create_standard
        cli = new(
          binary_name: DEFAULT_BINARY_NAME,
          config_dir_name: DEFAULT_DIR_NAME,
          config_file_name: DEFAULT_FILE_NAME,
          index_file_name: DEFAULT_FILE_NAME,
          preload_file_name: DEFAULT_PRELOAD_NAME,
          middleware: default_middleware_stack,
          root_desc: DEFAULT_ROOT_DESC
        )
        cli.add_path_hierarchy
        cli.add_standard_paths
        cli.add_config_paths(BUILTINS_PATH)
        cli
      end

      ##
      # Returns a default set of middleware used by the standard Toys CLI.
      # This middleware handles usage errors, provides a behavior for groups
      # that displays the group command list, provides a `--help` option for
      # showing individual tool documentation, and provides `--verbose` and
      # `--quiet` switches for setting the verbosity, which in turn controls
      # the logger level.
      #
      # @return [Array]
      #
      def default_middleware_stack
        [
          Middleware.lookup(:show_usage_errors).new,
          Middleware.lookup(:group_default).new,
          Middleware.lookup(:show_tool_help).new,
          Middleware.lookup(:set_verbosity).new
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
