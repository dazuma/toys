# frozen_string_literal: true

module Toys
  ##
  # This is the base class for tool execution. It represents `self` when your
  # tool's methods (such as `run`) are called, and it defines the methods that
  # can be called by your tool (such as {#logger} and {#exit}.)
  #
  # This class also manages the "data" available to your tool when it runs.
  # This data is a hash of key-value pairs. It consists of values set by flags
  # and arguments defined by the tool, plus some "well-known" values such as
  # the logger and verbosity level.
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
  # or symbols as keys. Keys that are not strings or symbols should either be
  # well-known keys such as {Toys::Context::Key::VERBOSITY}, or should be used
  # for internal private information needed by middleware and mixins. The
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
    # ### Example
    #
    #     tool "my-name" do
    #       def run
    #         # TOOL_NAME is available here.
    #         puts "My name is #{get(TOOL_NAME)}"
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
      # Context key for the currently running {Toys::CLI}. You can use the
      # value to run other tools from your tool by calling {Toys::CLI#run}.
      # @return [Object]
      #
      CLI = ::Object.new.freeze

      ##
      # Context key for the context directory path. The value is a string
      # @return [Object]
      #
      CONTEXT_DIRECTORY = ::Object.new.freeze

      ##
      # Context key for the context from which the current call was delegated.
      # The value is either another context object, or `nil` if the current
      # call is not delegated.
      # @return [Object]
      #
      DELEGATED_FROM = ::Object.new.freeze

      ##
      # Context key for the active `Logger` object.
      # @return [Object]
      #
      LOGGER = ::Object.new.freeze

      ##
      # Context key for the {Toys::ToolDefinition} object being executed.
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
      # Context key for the {Toys::SourceInfo} describing the source of this
      # tool.
      # @return [Object]
      #
      TOOL_SOURCE = ::Object.new.freeze

      ##
      # Context key for all unmatched args in order. The value is an array of
      # strings.
      # @return [Object]
      #
      UNMATCHED_ARGS = ::Object.new.freeze

      ##
      # Context key for unmatched flags. The value is an array of strings.
      # @return [Object]
      #
      UNMATCHED_FLAGS = ::Object.new.freeze

      ##
      # Context key for unmatched positional args. The value is an array of
      # strings.
      # @return [Object]
      #
      UNMATCHED_POSITIONAL = ::Object.new.freeze

      ##
      # Context key for the list of usage errors raised. The value is an array
      # of {Toys::ArgParser::UsageError}.
      # @return [Object]
      #
      USAGE_ERRORS = ::Object.new.freeze

      ##
      # Context key for the verbosity value. The value is an integer defaulting
      # to 0, with higher values meaning more verbose and lower meaning more
      # quiet.
      # @return [Object]
      #
      VERBOSITY = ::Object.new.freeze
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
    # Set one or more options or other context data by key.
    #
    # @return [self]
    #
    # @overload set(key, value)
    #   Set an option or other piece of context data by key.
    #   @param key [Symbol]
    #   @param value [Object]
    #   @return [self]
    #
    # @overload set(hash)
    #   Set multiple content data keys and values
    #   @param hash [Hash] The keys and values to set
    #   @return [self]
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
    # Exit immediately with the given status code.
    #
    # @param code [Integer] The status code, which should be 0 for no error,
    #     or nonzero for an error condition. Default is 0.
    # @return [void]
    #
    def exit(code = 0)
      throw :result, code
    end

    ##
    # Exit immediately with the given status code. This class method can be
    # called if the instance method is or could be replaced by the tool.
    #
    # @param code [Integer] The status code, which should be 0 for no error,
    #     or nonzero for an error condition. Default is 0.
    # @return [void]
    #
    def self.exit(code = 0)
      throw :result, code
    end

    ##
    # Create a Context object. Applications generally will not need to create
    # these objects directly; they are created by the tool when it is preparing
    # for execution.
    #
    # @param data [Hash]
    #
    # @private This interface is internal and subject to change without warning.
    #
    def initialize(data)
      @__data = data
    end

    ##
    # Include the tool name in the object inspection dump.
    #
    # @private
    #
    def inspect
      words = Array(@__data[Key::TOOL_NAME])
      name = words.empty? ? "(root)" : words.join(" ").inspect
      id = object_id.to_s(16)
      "#<Toys::Context id=0x#{id} tool=#{name}>"
    end
  end
end
