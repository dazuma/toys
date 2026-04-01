# frozen_string_literal: true

module Toys
  ##
  # An exception indicating an error in a tool definition.
  #
  class ToolDefinitionError < ::StandardError
  end

  ##
  # An exception indicating that a tool has no run method.
  #
  class NotRunnableError < ::StandardError
  end

  ##
  # An exception indicating problems parsing arguments.
  #
  class ArgParsingError < ::StandardError
    ##
    # Create an ArgParsingError given a set of error messages
    # @param errors [Array<Toys::ArgParser::UsageError>]
    #
    def initialize(errors)
      @usage_errors = errors
      super(errors.join("\n"))
    end

    ##
    # The individual usage error messages.
    # @return [Array<Toys::ArgParser::UsageError>]
    #
    attr_reader :usage_errors
  end

  ##
  # A wrapper exception used to provide user-oriented context for an error
  # thrown during tool execution.
  #
  class ContextualError < ::StandardError
    ##
    # Construct a ContextualError. This exception type is thrown from
    # {ContextualError.capture} and should not be constructed directly.
    #
    # @private This interface is internal and subject to change without warning.
    #
    def initialize(cause, banner, path, tool_name, tool_args)
      banner ||= "Unexpected error"
      super("#{banner}: #{cause.message} (#{cause.class})")
      set_backtrace(cause.backtrace)
      @banner = banner
      @tool_name = tool_name
      @tool_args = tool_args
      @config_path = @config_line = nil
      line = line_from_cause(path, cause)
      if line
        @config_path = path
        @config_line = line
      end
    end

    ##
    # An overall banner message
    # @return [String]
    #
    attr_reader :banner

    ##
    # The path to the toys config file in which the error was detected
    # @return [String]
    #
    attr_reader :config_path

    ##
    # The line number in the toys config file in which the error was detected
    # @return [Integer]
    #
    attr_reader :config_line

    ##
    # The full name of the tool that was running when the error occurred
    # @return [Array<String>]
    #
    attr_reader :tool_name

    ##
    # The arguments passed to the tool that was running when the error occurred
    # @return [Array<String>]
    #
    attr_reader :tool_args

    ##
    # @private
    #
    def update_fields!(path: nil, tool_name: nil, tool_args: nil)
      if @config_path.nil? && @config_line.nil?
        line = line_from_cause(path, cause)
        if line
          @config_path = path
          @config_line = line
        end
      end
      @tool_name = tool_name if @tool_name.nil? && !tool_name.nil?
      @tool_args = tool_args if @tool_args.nil? && !tool_args.nil?
    end

    private

    ##
    # Extract a line number from a cause exception
    #
    def line_from_cause(path, cause)
      return nil if path.nil? || cause.nil?
      if cause.is_a?(::SyntaxError)
        match = /#{::Regexp.escape(path)}:(\d+)/.match(cause.message)
        return match[1].to_i if match
      end
      loc = (cause.backtrace_locations || []).find do |elem|
        elem.absolute_path == path || elem.path == path
      end
      loc&.lineno
    end

    class << self
      ##
      # Execute the given block, and wrap any exceptions thrown with a
      # ContextualError. This is intended for loading a config file from the
      # given path, and wraps any Ruby parsing errors.
      #
      # @private This interface is internal and subject to change without warning.
      #
      def capture(banner: nil, path: nil, tool_name: nil, tool_args: nil)
        yield
      rescue ContextualError => e
        e.update_fields!(path: path, tool_name: tool_name, tool_args: tool_args)
        raise e
      rescue ::ScriptError, ::StandardError, ::SignalException => e
        raise ContextualError.new(e, banner, path, tool_name, tool_args)
      end
    end
  end
end
