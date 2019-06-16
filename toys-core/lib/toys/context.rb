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
  # This is the base class for tool execution. It represents `self` when your
  # tool's methods (such as `run`) are called, and it defines the methods that
  # can be called by your tool (such as {#logger} and {#exit}.)
  #
  # This class also manages the "data" available to your tool when it runs.
  # This data is a hash of key-value pairs. This data consists of values set by
  # flags and arguments defined by the tool, along with a few "well-known"
  # values such as the logger and verbosity level.
  #
  # You can obtain a value from the data using the {Toys::Context#get} method.
  # Additionally, convenience methods are provided for many of the well-known
  # keys. For instance, you can call {Toys::Context#verbosity} to obtain the
  # value for the key {Toys::Context::Key::VERBOSITY}. Finally, flags and
  # positional arguments that store their data here will also typically
  # generate convenience methods. For example, an argument with key `:abc` will
  # add a method called `abc` that you can call to get the value.
  #
  # By convention, flags and arguments defined by your tool should use strings
  # or symbols as keys. Any other keys should correspond either to well-known
  # data, or private information used internally by middleware and mixins. The
  # module {Toys::Context::Key} defines a number of well-known keys as
  # constants.
  #
  class Context
    ##
    # Well-known context keys.
    #
    # This module is mixed into the runtime context. This means you can
    # reference any of these constants directly from your run method.
    #
    # ## Example
    #
    #     tool "my-name" do
    #       def run
    #         # EXECUTABLE_NAME is available here.
    #         puts "My name is #{get(EXECUTABLE_NAME)}"
    #       end
    #     end
    #
    module Key
      ##
      # Context key for the argument list passed to the current tool. Value is
      # an array of strings.
      # @return [Object]
      #
      ARGS = ::Object.new.freeze

      ##
      # Context key for the currently running {Toys::CLI}. You can use this
      # object to run other tools from your tool by calling {Toys::CLI#run}.
      # @return [Object]
      #
      CLI = ::Object.new.freeze

      ##
      # Context key for the context directory.
      # @return [Object]
      #
      CONTEXT_DIRECTORY = ::Object.new.freeze

      ##
      # Context key for the name of the toys executable. Value is a string.
      # @return [Object]
      #
      EXECUTABLE_NAME = ::Object.new.freeze

      ##
      # Context key for unmatched positional args.
      # @return [Object]
      #
      EXTRA_ARGS = ::Object.new.freeze

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
      # Context key for the `Toys::Tool` object being executed.
      # @return [Object]
      #
      TOOL = ::Object.new.freeze

      ##
      # Context key for the full name of the tool being executed. Value is an
      # array of strings.
      # @return [Object]
      #
      TOOL_NAME = ::Object.new.freeze

      ##
      # Context key for the `Toys::SourceInfo` describing the
      # source of this tool.
      # @return [Object]
      #
      TOOL_SOURCE = ::Object.new.freeze

      ##
      # Context key for the list of usage errors raised. Value is an array
      # of {Toys::ArgParser::UsageError}.
      # @return [Object]
      #
      USAGE_ERRORS = ::Object.new.freeze

      ##
      # Context key for the verbosity value. Verbosity is an integer defaulting
      # to 0, with higher values meaning more verbose and lower meaning quieter.
      # @return [Object]
      #
      VERBOSITY = ::Object.new.freeze
    end

    ##
    # Create a Context object. Applications generally will not need to create
    # these objects directly; they are created by the tool when it is preparing
    # for execution.
    # @private
    #
    # @param data [Hash]
    #
    def initialize(data)
      @__data = data
    end

    ##
    # The raw arguments passed to the tool, as an array of strings.
    # This does not include the tool name itself.
    #
    # This is a convenience getter for {Toys::Context::Key::ARGS}.
    #
    # @return [Array<String>]
    #
    def args
      @__data[Key::ARGS]
    end

    ##
    # The name of the executable that was executed.
    #
    # This is a convenience getter for {Toys::Context::Key::EXECUTABLE_NAME}.
    #
    # @return [String]
    #
    def executable_name
      @__data[Key::EXECUTABLE_NAME]
    end

    ##
    # The currently running CLI.
    #
    # This is a convenience getter for {Toys::Context::Key::CLI}.
    #
    # @return [Toys::CLI]
    #
    def cli
      @__data[Key::CLI]
    end

    ##
    # Return the context directory for this tool. Generally, this defaults
    # to the directory containing the toys config directory structure being
    # read, but it may be changed by setting a different context directory
    # for the tool.
    #
    # This is a convenience getter for {Toys::Context::Key::CONTEXT_DIRECTORY}.
    #
    # @return [String] Context directory path
    # @return [nil] if there is no context.
    #
    def context_directory
      @__data[Key::CONTEXT_DIRECTORY]
    end

    ##
    # The active loader that can be used to get other tools.
    #
    # This is a convenience getter for {Toys::Context::Key::LOADER}.
    #
    # @return [Toys::Loader]
    #
    def loader
      @__data[Key::LOADER]
    end

    ##
    # The logger for this execution.
    #
    # This is a convenience getter for {Toys::Context::Key::LOGGER}.
    #
    # @return [Logger]
    #
    def logger
      @__data[Key::LOGGER]
    end

    ##
    # The tool being executed.
    #
    # This is a convenience getter for {Toys::Context::Key::TOOL}.
    #
    # @return [Toys::Tool]
    #
    def tool
      @__data[Key::TOOL]
    end

    ##
    # The full name of the tool being executed, as an array of strings.
    #
    # This is a convenience getter for {Toys::Context::Key::TOOL_NAME}.
    #
    # @return [Array<String>]
    #
    def tool_name
      @__data[Key::TOOL_NAME]
    end

    ##
    # The source of the tool being executed.
    #
    # This is a convenience getter for {Toys::Context::Key::TOOL_SOURCE}.
    #
    # @return [Toys::SourceInfo]
    #
    def tool_source
      @__data[Key::TOOL_SOURCE]
    end

    ##
    # The (possibly empty) array of errors detected during argument parsing.
    #
    # This is a convenience getter for {Toys::Context::Key::USAGE_ERRORS}.
    #
    # @return [Array<Toys::ArgParser::UsageError>]
    #
    def usage_errors
      @__data[Key::USAGE_ERRORS]
    end

    ##
    # The current verbosity setting as an integer.
    #
    # This is a convenience getter for {Toys::Context::Key::VERBOSITY}.
    #
    # @return [Integer]
    #
    def verbosity
      @__data[Key::VERBOSITY]
    end

    ##
    # Fetch an option or other piece of data by key.
    #
    # @param key [Symbol]
    # @return [Object]
    #
    def [](key)
      @__data[key]
    end
    alias get []
    alias __get []

    ##
    # Set an option or other piece of context data by key.
    #
    # @param key [Symbol]
    # @param value [Object]
    #
    def []=(key, value)
      @__data[key] = value
    end

    ##
    # Set an option or other piece of context data by key.
    #
    # @param key [Symbol]
    # @param value [Object]
    # @return [self]
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
    # The subset of the context that uses string or symbol keys. By convention,
    # this includes keys that are set by tool flags and arguments, but does not
    # include well-known context values such as verbosity or private context
    # values used by middleware or mixins.
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
    # @param path [String] The path to find
    # @param type [nil,:file,:directory] Type of file system object to find,
    #     or nil to return any type.
    #
    # @return [String] Absolute path of the result
    # @return [nil] if the data was not found.
    #
    def find_data(path, type: nil)
      @__data[Key::TOOL_SOURCE].find_data(path, type: type)
    end

    ##
    # Exit immediately with the given status code
    #
    # @param code [Integer] The status code, which should be 0 for no error,
    #     or nonzero for an error condition. Default is 0.
    # @return [void]
    #
    def exit(code = 0)
      throw :result, code
    end

    ##
    # Exit immediately with the given status code
    #
    # @param code [Integer] The status code, which should be 0 for no error,
    #     or nonzero for an error condition. Default is 0.
    # @return [void]
    #
    def self.exit(code = 0)
      throw :result, code
    end
  end
end
