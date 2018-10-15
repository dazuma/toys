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
  # This class manages the object context in effect during the execution of a
  # tool. The context is a hash of key-value pairs.
  #
  # Flags and arguments defined by your tool normally report their values in
  # the context, using keys that are strings or symbols.
  #
  # Keys that are neither strings nor symbols are by convention used for other
  # context information, including:
  #
  # *   Common information such as the {Toys::Definition::Tool} object being
  #     executed, the arguments originally passed to it, or the usage error
  #     string. These well-known keys can be accessed via constants in the
  #     {Toys::Tool::Keys} module.
  # *   Common settings such as the verbosity level, and whether to exit
  #     immediately if a subprocess exits with a nonzero result. These keys are
  #     also present as {Toys::Context} constants.
  # *   Private information used internally by middleware and mixins.
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
      # Context key for the `Toys::Definition::SourceInfo` describing the
      # source of this tool.
      # @return [Object]
      #
      TOOL_SOURCE = ::Object.new.freeze

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
    end

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
      @__data = data
      @__data[Keys::CLI] = cli
      @__data[Keys::LOADER] = cli.loader
      @__data[Keys::BINARY_NAME] = cli.binary_name
      @__data[Keys::LOGGER] = cli.logger
    end

    ##
    # Return the currently running CLI.
    # @return [Toys::CLI]
    #
    def cli
      @__data[Keys::CLI]
    end

    ##
    # Return the current verbosity setting as an integer.
    # @return [Integer]
    #
    def verbosity
      @__data[Keys::VERBOSITY]
    end

    ##
    # Return the tool being executed.
    # @return [Toys::Definition::Tool]
    #
    def tool_definition
      @__data[Keys::TOOL_DEFINITION]
    end

    ##
    # Return the source of the tool being executed.
    # @return [Toys::Definition::SourceInfo]
    #
    def tool_source
      @__data[Keys::TOOL_SOURCE]
    end

    ##
    # Return the name of the tool being executed, as an array of strings.
    # @return [Array[String]]
    #
    def tool_name
      @__data[Keys::TOOL_NAME]
    end

    ##
    # Return the raw arguments passed to the tool, as an array of strings.
    # This does not include the tool name itself.
    # @return [Array[String]]
    #
    def args
      @__data[Keys::ARGS]
    end

    ##
    # Return any usage error detected during argument parsing, or `nil` if
    # no error was detected.
    # @return [String,nil]
    #
    def usage_error
      @__data[Keys::USAGE_ERROR]
    end

    ##
    # Return the logger for this execution.
    # @return [Logger]
    #
    def logger
      @__data[Keys::LOGGER]
    end

    ##
    # Return the active loader that can be used to get other tools.
    # @return [Toys::Loader]
    #
    def loader
      @__data[Keys::LOADER]
    end

    ##
    # Return the name of the binary that was executed.
    # @return [String]
    #
    def binary_name
      @__data[Keys::BINARY_NAME]
    end

    ##
    # Return an option or other piece of data by key.
    #
    # @param [Symbol] key
    # @return [Object]
    #
    def [](key)
      @__data[key]
    end
    alias get []

    ##
    # Set an option or other piece of context data by key.
    #
    # @param [Symbol] key
    # @param [Object] value
    #
    def []=(key, value)
      @__data[key] = value
    end

    ##
    # Set an option or other piece of context data by key.
    #
    # @param [Symbol] key
    # @param [Object] value
    #
    def set(key, value = nil)
      if key.is_a?(::Hash)
        @__data.merge!(key)
      else
        @__data[key] = value
      end
      self
    end

    ##
    # Returns the subset of the context that uses string or symbol keys. By
    # convention, this includes keys that are set by tool flags and arguments,
    # but does not include well-known context values such as verbosity or
    # private context values used by middleware or mixins.
    #
    # @return [Hash]
    #
    def options
      @__data.select do |k, _v|
        k.is_a?(::Symbol) || k.is_a?(::String)
      end
    end

    ##
    # Find the given data file or directory in this tool's search path.
    #
    # @param [String] path The path to find
    # @param [nil,:file,:directory] type Type of file system object to find,
    #     or nil to return any type.
    # @return [String,nil] Absolute path of the result, or nil if not found.
    #
    def find_data(path, type: nil)
      @__data[Keys::TOOL_SOURCE].find_data(path, type: type)
    end

    ##
    # Return the context directory containing the definition of this tool.
    # May return nil if there is no context (e.g. the tool is being defined
    # from a block).
    #
    # @return [String,nil] Context directory
    #
    def context_directory
      @__data[Keys::TOOL_SOURCE].context_directory
    end

    ##
    # Exit immediately with the given status code
    #
    # @param [Integer] code The status code, which should be 0 for no error,
    #     or nonzero for an error condition. Default is 0.
    #
    def exit(code = 0)
      throw :result, code
    end

    ##
    # Exit immediately with the given status code
    #
    # @param [Integer] code The status code, which should be 0 for no error,
    #     or nonzero for an error condition. Default is 0.
    #
    def self.exit(code = 0)
      throw :result, code
    end
  end
end
