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

require "toys/middleware/show_version"

module Toys
  ##
  # The standard Toys CLI.
  #
  # This class configures the toys-core CLI with the standard behavior.
  #
  class StandardCLI < CLI
    ##
    # Path to standard built-in tools
    # @return [String]
    #
    BUILTINS_PATH = ::File.join(::File.dirname(::File.dirname(__dir__)), "builtins").freeze

    ##
    # Standard toys configuration directory name
    # @return [String]
    #
    CONFIG_DIR_NAME = ".toys".freeze

    ##
    # Standard toys configuration file name
    # @return [String]
    #
    CONFIG_FILE_NAME = ".toys.rb".freeze

    ##
    # Standard index file name in a toys configuration
    # @return [String]
    #
    INDEX_FILE_NAME = ".toys.rb".freeze

    ##
    # Standard toys preload file name
    # @return [String]
    #
    PRELOAD_FILE_NAME = ".preload.rb".freeze

    ##
    # Name of standard toys binary
    # @return [String]
    #
    BINARY_NAME = "toys".freeze

    ##
    # Help text for the standard root tool
    # @return [String]
    #
    DEFAULT_ROOT_DESC =
      "Toys is your personal command line tool. You can add to the list of" \
      " commands below by writing scripts in Ruby using a simple DSL, and" \
      " toys will organize and document them, and make them available" \
      " globally or scoped to specific directories that you choose." \
      " For detailed information, see https://www.rubydoc.info/gems/toys".freeze

    ##
    # Create a standard CLI
    #
    def initialize
      super(
        binary_name: BINARY_NAME,
        config_dir_name: CONFIG_DIR_NAME,
        config_file_name: CONFIG_FILE_NAME,
        index_file_name: INDEX_FILE_NAME,
        preload_file_name: PRELOAD_FILE_NAME
      )
      add_search_path_hierarchy
      add_standard_search_paths
      add_config_path(BUILTINS_PATH)
    end

    ##
    # Returns a the middleware for the standard Toys CLI.
    #
    # @return [Array]
    #
    def self.default_middleware_stack
      version_displayer = Middleware::ShowVersion.root_version_displayer(::Toys::VERSION)
      [
        [:set_default_descriptions, default_root_desc: DEFAULT_ROOT_DESC],
        [:handle_usage_errors],
        [:show_version, version_displayer: version_displayer],
        [:show_usage, help_switches: true, fallback_execution: true],
        [:add_verbosity_switches]
      ]
    end
  end
end
