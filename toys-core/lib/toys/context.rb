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
  # This class manages the object context in effect during the execution of a
  # tool. The context is a hash of key-value pairs.
  #
  # Flags and arguments defined by your tool normally report their values in
  # the context, using keys that are strings or symbols.
  #
  # Keys that are neither strings nor symbols are by convention used for other
  # context information, including:
  #
  # *   Common information such as the {Toys::ToolDefinition} object being
  #     executed, the arguments originally passed to it, or the usage error
  #     string. These well-known keys can be accessed via constants in the
  #     {Toys::Context::Key} module.
  # *   Common settings such as the verbosity level, and whether to exit
  #     immediately if a subprocess exits with a nonzero result. These keys are
  #     also present as {Toys::Context::Key} constants.
  # *   Private information used internally by middleware and mixins.
  #
  # This class provides convenience accessors for common keys and settings, and
  # you can retrieve argument-set keys using the {#options} hash.
  #
  class Context
    ##
    # Well-known context keys.
    #
    module Key
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
      # Context key for the `Toys::ToolDefinition` object being executed.
      # @return [Object]
      #
      TOOL_DEFINITION = ::Object.new.freeze

      ##
      # Context key for the `Toys::SourceInfo` describing the
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
      @__data[Key::CLI] = cli
      @__data[Key::LOADER] = cli.loader
      @__data[Key::BINARY_NAME] = cli.binary_name
      @__data[Key::LOGGER] = cli.logger
    end

    ##
    # Return the currently running CLI.
    # @return [Toys::CLI]
    #
    def cli
      @__data[Key::CLI]
    end

    ##
    # Return the current verbosity setting as an integer.
    # @return [Integer]
    #
    def verbosity
      @__data[Key::VERBOSITY]
    end

    ##
    # Return the tool being executed.
    # @return [Toys::ToolDefinition]
    #
    def tool_definition
      @__data[Key::TOOL_DEFINITION]
    end

    ##
    # Return the source of the tool being executed.
    # @return [Toys::SourceInfo]
    #
    def tool_source
      @__data[Key::TOOL_SOURCE]
    end

    ##
    # Return the name of the tool being executed, as an array of strings.
    # @return [Array[String]]
    #
    def tool_name
      @__data[Key::TOOL_NAME]
    end

    ##
    # Return the raw arguments passed to the tool, as an array of strings.
    # This does not include the tool name itself.
    # @return [Array[String]]
    #
    def args
      @__data[Key::ARGS]
    end

    ##
    # Return any usage error detected during argument parsing, or `nil` if
    # no error was detected.
    # @return [String,nil]
    #
    def usage_error
      @__data[Key::USAGE_ERROR]
    end

    ##
    # Return the logger for this execution.
    # @return [Logger]
    #
    def logger
      @__data[Key::LOGGER]
    end

    ##
    # Return the active loader that can be used to get other tools.
    # @return [Toys::Loader]
    #
    def loader
      @__data[Key::LOADER]
    end

    ##
    # Return the name of the binary that was executed.
    # @return [String]
    #
    def binary_name
      @__data[Key::BINARY_NAME]
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
      @__data[Key::TOOL_SOURCE].find_data(path, type: type)
    end

    ##
    # Return the context directory for this tool. Generally, this defaults
    # to the directory containing the toys config directory structure being
    # read, but it may be changed by setting a different context directory
    # for the tool.
    # May return nil if there is no context.
    #
    # @return [String,nil] Context directory
    #
    def context_directory
      @__data[Key::TOOL_DEFINITION].context_directory
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
