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
  # This class manages the object context in effect during the execution of a
  # tool. The context is a hash of key-value pairs.
  #
  # Flags and arguments defined by your tool normally report their values in
  # the context, using keys that are strings or symbols.
  #
  # Keys that are neither strings nor symbols are by convention used for other
  # context information, including:
  # *   Common information such as the {Toys::Definition::Tool} object being
  #     executed, the arguments originally passed to it, or the usage error
  #     string. These well-known keys can be accessed via constants in the
  #     {Toys::Tool} module.
  # *   Common settings such as the verbosity level, and whether to exit
  #     immediately if a subprocess exits with a nonzero result. These keys are
  #     also present as {Toys::Context} constants.
  # *   Private information used internally by middleware and helpers.
  #
  # This class provides convenience accessors for common keys and settings, and
  # you can retrieve argument-set keys using the {#options} hash.
  #
  class Tool
    ##
    # Well-known context keys.
    #
    module Keys
      ##
      # Context key for the currently running CLI.
      # @return [Object]
      #
      CLI = ::Object.new.freeze

      ##
      # Context key for the verbosity value. Verbosity is an integer defaulting
      # to 0, with higher values meaning more verbose and lower meaning quieter.
      # @return [Object]
      #
      VERBOSITY = ::Object.new.freeze

      ##
      # Context key for the `Toys::Definition::Tool` object being executed.
      # @return [Object]
      #
      TOOL_DEFINITION = ::Object.new.freeze

      ##
      # Context key for the full name of the tool being executed. Value is an
      # array of strings.
      # @return [Object]
      #
      TOOL_NAME = ::Object.new.freeze

      ##
      # Context key for the active `Toys::Loader` object.
      # @return [Object]
      #
      LOADER = ::Object.new.freeze

      ##
      # Context key for the active `Logger` object.
      # @return [Object]
      #
      LOGGER = ::Object.new.freeze

      ##
      # Context key for the name of the toys binary. Value is a string.
      # @return [Object]
      #
      BINARY_NAME = ::Object.new.freeze

      ##
      # Context key for the argument list passed to the current tool. Value is
      # an array of strings.
      # @return [Object]
      #
      ARGS = ::Object.new.freeze

      ##
      # Context key for the usage error raised. Value is a string if there was
      # an error, or nil if there was no error.
      # @return [Object]
      #
      USAGE_ERROR = ::Object.new.freeze

      ##
      # Context key for whether nonzero exit codes from subprocesses should cause
      # an immediate exit. Value is a truthy or falsy value.
      # @return [Object]
      #
      EXIT_ON_NONZERO_STATUS = ::Object.new.freeze
    end

    include Keys

    ##
    # Create a Context object. Applications generally will not need to create
    # these objects directly; they are created by the tool when it is preparing
    # for execution.
    # @private
    #
    # @param [Toys::CLI] cli
    # @param [Hash] data
    #
    def initialize(cli, data)
      @_data = data
      @_data[CLI] = cli
      @_data[LOADER] = cli.loader
      @_data[BINARY_NAME] = cli.binary_name
      @_data[LOGGER] = cli.logger
    end

    ##
    # Return the currently running CLI.
    # @return [Toys::CLI]
    #
    def cli
      @_data[CLI]
    end

    ##
    # Return the current verbosity setting as an integer.
    # @return [Integer]
    #
    def verbosity
      @_data[VERBOSITY]
    end

    ##
    # Return the tool being executed.
    # @return [Toys::Definition::Tool]
    #
    def tool_definition
      @_data[TOOL_DEFINITION]
    end

    ##
    # Return the name of the tool being executed, as an array of strings.
    # @return [Array[String]]
    #
    def tool_name
      @_data[TOOL_NAME]
    end

    ##
    # Return the raw arguments passed to the tool, as an array of strings.
    # This does not include the tool name itself.
    # @return [Array[String]]
    #
    def args
      @_data[ARGS]
    end

    ##
    # Return any usage error detected during argument parsing, or `nil` if
    # no error was detected.
    # @return [String,nil]
    #
    def usage_error
      @_data[USAGE_ERROR]
    end

    ##
    # Return the logger for this execution.
    # @return [Logger]
    #
    def logger
      @_data[LOGGER]
    end

    ##
    # Return the active loader that can be used to get other tools.
    # @return [Toys::Loader]
    #
    def loader
      @_data[LOADER]
    end

    ##
    # Return the name of the binary that was executed.
    # @return [String]
    #
    def binary_name
      @_data[BINARY_NAME]
    end

    ##
    # Return an option or other piece of data by key.
    #
    # @param [Symbol] key
    # @return [Object]
    #
    def [](key)
      @_data[key]
    end
    alias get []

    ##
    # Set an option or other piece of context data by key.
    #
    # @param [Symbol] key
    # @param [Object] value
    #
    def []=(key, value)
      @_data[key] = value
    end

    ##
    # Set an option or other piece of context data by key.
    #
    # @param [Symbol] key
    # @param [Object] value
    #
    def set(key, value = nil)
      if key.is_a?(::Hash)
        @_data.merge!(key)
      else
        @_data[key] = value
      end
      self
    end

    ##
    # Returns the subset of the context that uses string or symbol keys. By
    # convention, this includes keys that are set by tool flags and arguments,
    # but does not include well-known context values such as verbosity or
    # private context values used by middleware or helpers.
    #
    # @return [Hash]
    #
    def options
      @_data.select do |k, _v|
        k.is_a?(::Symbol) || k.is_a?(::String)
      end
    end

    ##
    # Execute another tool, given by the provided arguments.
    #
    # @param [String...] args The name of the tool to run along with its
    #     command line arguments and flags.
    # @param [Toys::CLI,nil] cli The CLI to use to execute the tool. If `nil`
    #     (the default), uses the current CLI.
    # @param [Boolean] exit_on_nonzero_status If true, exit immediately if the
    #     run returns a nonzero error code.
    # @return [Integer] The resulting status code
    #
    def run_tool(*args, cli: nil, exit_on_nonzero_status: nil)
      cli ||= @_data[CLI]
      exit_on_nonzero_status = @_data[EXIT_ON_NONZERO_STATUS] if exit_on_nonzero_status.nil?
      code = cli.run(args.flatten, verbosity: @_data[VERBOSITY])
      exit(code) if exit_on_nonzero_status && !code.zero?
      code
    end

    ##
    # Exit immediately with the given status code
    #
    # @param [Integer] code The status code, which should be 0 for no error,
    #     or nonzero for an error condition.
    #
    def exit(code)
      throw :result, code
    end
  end
end
