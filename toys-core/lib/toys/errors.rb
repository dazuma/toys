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
  # Signals are not wrapped in this class. A `SignalException` raised by a tool
  # propagates as itself, so that tools can intercept it and the Ruby VM can
  # ultimately handle it. See {Toys::CLI#run} for how each is reported.
  #
  class ContextualError < ::StandardError
    ##
    # Construct a ContextualError. This exception type is thrown by the CLI
    # and should not be constructed directly.
    #
    # @private This interface is internal and subject to change without warning.
    #
    def initialize(cause, banner, path, tool_name, tool_args, final)
      banner ||= "Unexpected error"
      original = cause.is_a?(ContextualError) ? cause.root_cause || cause : cause
      super("#{banner}: #{original.message} (#{original.class})")
      # Prefer the locations, because they let an enclosing capture locate the
      # config file line (see #line_from_cause). They are unavailable if the
      # cause was never raised, or if it is itself a ContextualError on a Ruby
      # too old to retain locations through set_backtrace, so fall back to the
      # strings rather than leaving the backtrace unset.
      Compat.set_backtrace(self, cause.backtrace_locations || cause.backtrace)
      @banner = banner
      @tool_name = tool_name
      @tool_args = tool_args
      @config_path = @config_line = nil
      line = line_from_cause(path, cause)
      if line
        @config_path = path
        @config_line = line
      end
      @final = final
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
    # Returns the root cause of this error, i.e. the first cause in the chain
    # that is not itself a ContextualError.
    #
    # @return [Exception] The root cause.
    #
    def root_cause
      current = cause
      while current.is_a?(ContextualError)
        current = current.cause
      end
      current
    end

    ##
    # @private
    #
    def final?
      @final
    end

    ##
    # @private
    #
    def update_fields!(path: nil, tool_name: nil, tool_args: nil, final: false)
      if @config_path.nil? && @config_line.nil?
        line = line_from_cause(path, cause)
        if line
          @config_path = path
          @config_line = line
        end
      end
      @tool_name = tool_name if @tool_name.nil? && !tool_name.nil?
      @tool_args = tool_args if @tool_args.nil? && !tool_args.nil?
      @final = true if final
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
      # ContextualError. This is intended for errors caught during Ruby parsing
      # or tool loading, or `StandardError`s caught during tool execution.
      #
      # Error types other than `StandardError` and `ScriptError` are *not*
      # wrapped but passed through bare. In particular, a `SignalException`
      # means the process is being asked to terminate, so it must stay
      # recognizable as a signal all the way up the stack.
      #
      # @private This interface is internal and subject to change without warning.
      #
      def capture(banner: nil, path: nil, tool_name: nil, tool_args: nil, final: false)
        yield
      rescue ContextualError => e
        if e.final?
          raise ContextualError.new(e, banner, path, tool_name, tool_args, final)
        else
          e.update_fields!(path: path, tool_name: tool_name, tool_args: tool_args, final: final)
          raise e
        end
      rescue ::ScriptError, ::StandardError => e
        raise ContextualError.new(e, banner, path, tool_name, tool_args, final)
      end
    end
  end
end
