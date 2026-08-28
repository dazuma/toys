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
      # Implementation note: The Key module is mixed into the context class in
      # InputFile where the class is created.

      ##
      # Context key for the argument list passed to the current tool. Value is
      # an array of strings.
      # @return [Object]
      #
      ARGS = ::Toys::UniqueKey.new("Toys::Context::Key::ARGS")

      ##
      # Context key for the currently running {Toys::CLI}. You can use the
      # value to reconfigure the framework, for example by calling
      # {Toys::CLI#child} to run a tool under modified settings. To run a
      # sibling tool without reconfiguring anything, you can also use
      # {Key::RUNNER} instead. The value could be nil if a CLI is not present.
      # @return [Object]
      #
      CLI = ::Toys::UniqueKey.new("Toys::Context::Key::CLI")

      ##
      # Context key for the context directory path. The value is a string.
      # @return [Object]
      #
      CONTEXT_DIRECTORY = ::Toys::UniqueKey.new("Toys::Context::Key::CONTEXT_DIRECTORY")

      ##
      # Context key for the context from which the current call was delegated.
      # The value is either another context object, or `nil` if the current
      # call is not delegated.
      # @return [Object]
      #
      DELEGATED_FROM = ::Toys::UniqueKey.new("Toys::Context::Key::DELEGATED_FROM")

      ##
      # Context key for the executable name displayed in help text. The value
      # is a String, provided by the {Toys::Runner}.
      # @return [Object]
      #
      EXECUTABLE_NAME = ::Toys::UniqueKey.new("Toys::Context::Key::EXECUTABLE_NAME")

      ##
      # Context key for the active `Loader` object.
      # @return [Object]
      #
      LOADER = ::Toys::UniqueKey.new("Toys::Context::Key::LOADER")

      ##
      # Context key for the active `Logger` object.
      # @return [Object]
      #
      LOGGER = ::Toys::UniqueKey.new("Toys::Context::Key::LOGGER")

      ##
      # Context key for the {Toys::Runner} that is running the current tool.
      # You can use the value to run other tools from your tool by calling
      # {Toys::Runner#run}.
      # @return [Object]
      #
      RUNNER = ::Toys::UniqueKey.new("Toys::Context::Key::RUNNER")

      ##
      # Context key for the {Toys::ToolDefinition} object being executed.
      # @return [Object]
      #
      TOOL = ::Toys::UniqueKey.new("Toys::Context::Key::TOOL")

      ##
      # Context key for the full name of the tool being executed. Value is an
      # array of strings.
      # @return [Object]
      #
      TOOL_NAME = ::Toys::UniqueKey.new("Toys::Context::Key::TOOL_NAME")

      ##
      # Context key for the {Toys::SourceInfo} describing the source of this
      # tool.
      # @return [Object]
      #
      TOOL_SOURCE = ::Toys::UniqueKey.new("Toys::Context::Key::TOOL_SOURCE")

      ##
      # Context key for all unmatched args in order. The value is an array of
      # strings.
      # @return [Object]
      #
      UNMATCHED_ARGS = ::Toys::UniqueKey.new("Toys::Context::Key::UNMATCHED_ARGS")

      ##
      # Context key for unmatched flags. The value is an array of strings.
      # @return [Object]
      #
      UNMATCHED_FLAGS = ::Toys::UniqueKey.new("Toys::Context::Key::UNMATCHED_FLAGS")

      ##
      # Context key for unmatched positional args. The value is an array of
      # strings.
      # @return [Object]
      #
      UNMATCHED_POSITIONAL = ::Toys::UniqueKey.new("Toys::Context::Key::UNMATCHED_POSITIONAL")

      ##
      # Context key for the list of usage errors raised. The value is an array
      # of {Toys::ArgParser::UsageError}.
      # @return [Object]
      #
      USAGE_ERRORS = ::Toys::UniqueKey.new("Toys::Context::Key::USAGE_ERRORS")

      ##
      # Context key for the verbosity value. The value is an integer defaulting
      # to 0, with higher values meaning more verbose and lower meaning more
      # quiet.
      # @return [Object]
      #
      VERBOSITY = ::Toys::UniqueKey.new("Toys::Context::Key::VERBOSITY")
    end

    ##
    # The raw arguments passed to the tool, as an array of strings.
    # This does not include the tool name itself.
    #
    # This is a convenience getter for {Toys::Context::Key::ARGS}.
    #
    # If the `args` method is overridden by the tool, you can still access it
    # using the name `__args`.
    #
    # @return [Array<String>]
    #
    def args
      @__data[Key::ARGS]
    end
    alias __args args

    ##
    # The currently running CLI.
    #
    # This is a convenience getter for {Toys::Context::Key::CLI}. Note the
    # value could be nil if no CLI is present during the execution.
    #
    # If the `cli` method is overridden by the tool, you can still access it
    # using the name `__cli`.
    #
    # @return [Toys::CLI,nil]
    #
    def cli
      @__data[Key::CLI]
    end
    alias __cli cli

    ##
    # Return the effective context directory for this tool run. Generally, this
    # is set to the directory _containing_ the toys tool directory structure
    # being read, or it may have been set by the tool definition itself. If a
    # context directory has not been set explicitly, returns the current
    # working directory. Will not return nil.
    #
    # This is a convenience getter for {Toys::Context::Key::CONTEXT_DIRECTORY}.
    #
    # If the `context_directory` method is overridden by the tool, you can
    # still access it using the name `__context_directory`.
    #
    # @return [String] Effective context directory path
    #
    def context_directory
      @__data[Key::CONTEXT_DIRECTORY]
    end
    alias __context_directory context_directory

    ##
    # The loader that loaded the tool being executed. It can be used to look up
    # and load other tools.
    #
    # This is a convenience getter for {Toys::Context::Key::LOADER}.
    #
    # If the `loader` method is overridden by the tool, you can still access it
    # using the name `__loader`.
    #
    # @return [Toys::Loader]
    #
    def loader
      @__data[Key::LOADER]
    end
    alias __loader loader

    ##
    # The logger for this execution.
    #
    # This is a convenience getter for {Toys::Context::Key::LOGGER}.
    #
    # If the `logger` method is overridden by the tool, you can still access it
    # using the name `__logger`.
    #
    # @return [Logger]
    #
    def logger
      @__data[Key::LOGGER]
    end
    alias __logger logger

    ##
    # The runner that is running the tool. It can be used to run other tools
    # in the same process.
    #
    # This is a convenience getter for {Toys::Context::Key::RUNNER}.
    #
    # If the `runner` method is overridden by the tool, you can still access it
    # using the name `__runner`.
    #
    # @return [Toys::Runner]
    #
    def runner
      @__data[Key::RUNNER]
    end
    alias __runner runner

    ##
    # The full name of the tool being executed, as an array of strings.
    #
    # This is a convenience getter for {Toys::Context::Key::TOOL_NAME}.
    #
    # If the `tool_name` method is overridden by the tool, you can still access
    # it using the name `__tool_name`.
    #
    # @return [Array<String>]
    #
    def tool_name
      @__data[Key::TOOL_NAME]
    end
    alias __tool_name tool_name

    ##
    # The source of the tool being executed.
    #
    # This is a convenience getter for {Toys::Context::Key::TOOL_SOURCE}.
    #
    # If the `tool_source` method is overridden by the tool, you can still
    # access it using the name `__tool_source`.
    #
    # @return [Toys::SourceInfo]
    #
    def tool_source
      @__data[Key::TOOL_SOURCE]
    end
    alias __tool_source tool_source

    ##
    # The (possibly empty) array of errors detected during argument parsing.
    #
    # This is a convenience getter for {Toys::Context::Key::USAGE_ERRORS}.
    #
    # If the `usage_errors` method is overridden by the tool, you can still
    # access it using the name `__usage_errors`.
    #
    # @return [Array<Toys::ArgParser::UsageError>]
    #
    def usage_errors
      @__data[Key::USAGE_ERRORS]
    end
    alias __usage_errors usage_errors

    ##
    # The current verbosity setting as an integer.
    #
    # This is a convenience getter for {Toys::Context::Key::VERBOSITY}.
    #
    # If the `verbosity` method is overridden by the tool, you can still access
    # it using the name `__verbosity`.
    #
    # @return [Integer]
    #
    def verbosity
      @__data[Key::VERBOSITY]
    end
    alias __verbosity verbosity

    ##
    # Fetch an option or other piece of data by key.
    #
    # If the `get` method is overridden by the tool, you can still access it
    # using the name `__get` or the `[]` operator.
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
    # If the `set` method is overridden by the tool, you can still access it
    # using the name `__set`.
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
    alias __set set

    ##
    # The subset of the context that uses string or symbol keys. By convention,
    # this includes keys that are set by tool flags and arguments, but does not
    # include well-known context values such as verbosity or private context
    # values used by middleware or mixins.
    #
    # If the `options` method is overridden by the tool, you can still access
    # it using the name `__options`.
    #
    # @return [Hash]
    #
    def options
      @__data.select do |k, _v|
        k.is_a?(::Symbol) || k.is_a?(::String)
      end
    end
    alias __options options

    ##
    # Find the given data file or directory in this tool's search path.
    #
    # If the `find_data` method is overridden by the tool, you can still access
    # it using the name `__find_data`.
    #
    # @param path [String] The path to find
    # @param type [nil,:file,:directory] Type of file system object to find,
    #     or nil to return any type.
    #
    # @return [String] Absolute path of the result
    # @return [nil] if the data was not found.
    #
    def find_data(path, type: nil)
      @__data[Key::TOOL_SOURCE]&.find_data(path, type: type)
    end
    alias __find_data find_data

    ##
    # Exit immediately with the given status code.
    #
    # If the `exit` method is overridden by the tool, you can still access it
    # using the name `__exit` or by calling {Context.exit}.
    #
    # @param code [Integer] The status code, which should be 0 for no error,
    #     or nonzero for an error condition. Default is 0.
    # @return [void]
    #
    def exit(code = 0)
      Context.exit(code)
    end
    alias __exit exit

    ##
    # Exit immediately with the given status code. This class method can be
    # called if the instance method is or could be replaced by the tool.
    #
    # @param code [Integer] The status code, which should be 0 for no error,
    #     or nonzero for an error condition. Default is 0.
    #     (Note: if a non-integer is passed in, it is changed to -1.)
    # @return [void]
    #
    def self.exit(code = 0)
      code = -1 unless code.is_a?(::Integer)
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
