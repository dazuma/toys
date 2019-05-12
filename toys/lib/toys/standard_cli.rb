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

module Toys
  ##
  # Helpers that configure the toys-core CLI with the behavior for the
  # standard Toys binary.
  #
  module StandardCLI
    ##
    # Path to standard built-in tools
    # @return [String]
    #
    BUILTINS_PATH = ::File.join(::File.dirname(::File.dirname(__dir__)), "builtins").freeze

    ##
    # Standard toys configuration directory name
    # @return [String]
    #
    CONFIG_DIR_NAME = ".toys"

    ##
    # Standard toys configuration file name
    # @return [String]
    #
    CONFIG_FILE_NAME = ".toys.rb"

    ##
    # Standard index file name in a toys configuration
    # @return [String]
    #
    INDEX_FILE_NAME = ".toys.rb"

    ##
    # Standard preload directory name in a toys configuration
    # @return [String]
    #
    PRELOAD_DIRECTORY_NAME = ".preload"

    ##
    # Standard preload file name in a toys configuration
    # @return [String]
    #
    PRELOAD_FILE_NAME = ".preload.rb"

    ##
    # Standard data directory name in a toys configuration
    # @return [String]
    #
    DATA_DIRECTORY_NAME = ".data"

    ##
    # Name of standard toys binary
    # @return [String]
    #
    BINARY_NAME = "toys"

    ##
    # Delimiter characters recognized
    # @return [String]
    #
    EXTRA_DELIMITERS = ":."

    ##
    # Short description for the standard root tool
    # @return [String]
    #
    DEFAULT_ROOT_DESC = "Your personal command line tool"

    ##
    # Help text for the standard root tool
    # @return [String]
    #
    DEFAULT_ROOT_LONG_DESC =
      "Toys is your personal command line tool. You can write commands using a simple Ruby DSL," \
      " and Toys will automatically organize them, parse arguments, and provide documentation." \
      " Tools can be global or scoped to specific directories. You can also use Toys instead of" \
      " Rake to provide build and maintenance scripts for your projects." \
      " For detailed information, see https://www.rubydoc.info/gems/toys"

    ##
    # Short description for the verion flag
    # @return [String]
    #
    DEFAULT_VERSION_FLAG_DESC = "Show the version of Toys."

    ##
    # Name of the toys path environment variable
    # @return [String]
    #
    TOYS_PATH_ENV = "TOYS_PATH"

    ##
    # Create a standard CLI, configured with the appropriate paths and
    # middleware.
    #
    # @param [String,nil] cur_dir Starting search directory for configs.
    #     Defaults to the current working directory.
    # @return [Toys::CLI]
    #
    def self.create(cur_dir: nil)
      cli = CLI.new(
        binary_name: BINARY_NAME,
        config_dir_name: CONFIG_DIR_NAME,
        config_file_name: CONFIG_FILE_NAME,
        index_file_name: INDEX_FILE_NAME,
        preload_file_name: PRELOAD_FILE_NAME,
        preload_directory_name: PRELOAD_DIRECTORY_NAME,
        data_directory_name: DATA_DIRECTORY_NAME,
        extra_delimiters: EXTRA_DELIMITERS,
        middleware_stack: default_middleware_stack,
        template_lookup: default_template_lookup
      )
      add_standard_paths(cli, cur_dir: cur_dir)
      cli
    end

    ##
    # Add paths for a toys standard CLI. Paths added, in order from high to
    # low priority, are:
    #
    # *  Search the current directory and all ancestors for config files and
    #    directories.
    # *  Read the `TOYS_PATH` environment variable and search for config files
    #    and directories in the given paths. If this variable is empty, use
    #    `$HOME:/etc` by default.
    # *  The builtins for the standard toys binary.
    #
    # @param [Toys::CLI] cli Add paths to this CLI
    # @param [String,nil] cur_dir Starting search directory for configs.
    #     Defaults to the current working directory.
    # @param [Array<String>,nil] global_dirs Optional list of global
    #     directories, or `nil` to use the defaults.
    #
    def self.add_standard_paths(cli, cur_dir: nil, global_dirs: nil)
      cur_dir ||= ::Dir.pwd
      global_dirs ||= default_global_dirs
      cli.add_search_path_hierarchy(start: cur_dir, terminate: global_dirs)
      global_dirs.each { |path| cli.add_search_path(path) }
      cli.add_config_path(BUILTINS_PATH)
      cli
    end

    # rubocop:disable Metrics/MethodLength

    ##
    # Returns the middleware for the standard Toys CLI.
    #
    # @return [Array]
    #
    def self.default_middleware_stack
      [
        [
          :set_default_descriptions,
          default_root_desc: DEFAULT_ROOT_DESC,
          default_root_long_desc: DEFAULT_ROOT_LONG_DESC
        ],
        [
          :show_help,
          help_flags: true,
          usage_flags: true,
          list_flags: true,
          recursive_flags: true,
          search_flags: true,
          show_all_subtools_flags: true,
          default_recursive: true,
          allow_root_args: true,
          show_source_path: true,
          use_less: true
        ],
        [
          :show_root_version,
          version_string: ::Toys::VERSION,
          version_flag_desc: DEFAULT_VERSION_FLAG_DESC
        ],
        [
          :handle_usage_errors
        ],
        [
          :show_help,
          fallback_execution: true,
          recursive_flags: true,
          search_flags: true,
          default_recursive: true,
          show_source_path: true,
          use_less: true
        ],
        [
          :add_verbosity_flags
        ]
      ]
    end

    # rubocop:enable Metrics/MethodLength

    ##
    # Returns the default set of global config directories.
    #
    # @return [Array<String>]
    #
    def self.default_global_dirs
      paths = ::ENV[TOYS_PATH_ENV].to_s.split(::File::PATH_SEPARATOR)
      paths = [::Dir.home, "/etc"] if paths.empty?
      paths
        .compact
        .uniq
        .select { |path| ::File.directory?(path) && ::File.readable?(path) }
        .map { |path| ::File.realpath(::File.expand_path(path)) }
    end

    ##
    # Returns a ModuleLookup for the default templates.
    #
    # @return [Toys::ModuleLookup]
    #
    def self.default_template_lookup
      ModuleLookup.new.add_path("toys/templates")
    end
  end
end
