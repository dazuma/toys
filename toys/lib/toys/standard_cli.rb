# frozen_string_literal: true

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
    # Standard toys preload file name
    # @return [String]
    #
    PRELOAD_FILE_NAME = ".preload.rb"

    ##
    # Name of standard toys binary
    # @return [String]
    #
    BINARY_NAME = "toys"

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
      "Toys is your personal command line tool. You can add to the list of commands below by" \
      " writing scripts in Ruby using a simple DSL, and Toys will organize and document them" \
      " and make them available globally or scoped to specific directories that you choose." \
      " For detailed information, see https://www.rubydoc.info/gems/toys"

    ##
    # Short description for the verion flag
    # @return [String]
    #
    DEFAULT_VERSION_FLAG_DESC = "Show the version of Toys."

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
          recursive_flags: true,
          search_flags: true,
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
      paths = ::ENV["TOYS_PATH"].to_s.split(::File::PATH_SEPARATOR)
      if paths.empty?
        paths << ::ENV["HOME"] if ::ENV["HOME"]
        paths << "/etc" if ::File.directory?("/etc") && ::File.readable?("/etc")
      end
      paths.map { |path| ::File.realpath(::File.expand_path(path)) }
    end

    ##
    # Returns a ModuleLookup for the default templates.
    #
    # @return [Toys::Utils::ModuleLookup]
    #
    def self.default_template_lookup
      Utils::ModuleLookup.new.add_path("toys/templates")
    end
  end
end
