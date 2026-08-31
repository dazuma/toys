# frozen_string_literal: true

module Toys
  ##
  # An exception indicating a semantic error in a tool definition.
  # This could include issues such as illegal names, or contradictory or
  # nonsensical argument configurations.
  #
  class ToolDefinitionError < ::StandardError
  end

  ##
  # An exception indicating a problem with a tool source, e.g. a path that
  # cannot be read, a git repo that cannot be accessed, a gem that cannot be
  # activated, etc.
  #
  class ToolSourceError < ::StandardError
  end

  ##
  # An exception indicating an attempt to run a tool that has no run method or
  # otherwise cannot be run.
  #
  class NotRunnableError < ::StandardError
  end

  ##
  # An exception indicating that a source was added to a {Toys::CLI} after its
  # source list was already finalized. The source list is finalized the first
  # time the CLI's loader is needed, i.e. when {Toys::CLI#loader} or
  # {Toys::CLI#runner} is called, or when a tool is run.
  #
  class SourceListFinalizedError < ::StandardError
  end

  ##
  # An exception indicating problems parsing arguments. These are generally
  # handled internally by triggering usage error handlers.
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
  # thrown during tool execution. Most exceptions raised during a tool run are
  # wrapped with one of these (with the original exception set as the `cause`.)
  #
  # Signals are not wrapped in this class. A `SignalException` raised by a tool
  # propagates as itself, so that tools can intercept it and the Ruby VM can
  # ultimately handle it. See the `error_handler` argument to
  # {Toys::Runner#initialize} for how each is reported.
  #
  class ContextualError < ::StandardError
    ##
    # Construct a ContextualError. This exception type is thrown by the CLI
    # and should not be constructed directly.
    #
    # @private This interface is internal and subject to change without warning.
    #
    def initialize(wrapped, banner, path, tool_verb, tool_name, tool_args, final)
      banner ||= "Unexpected error"
      original = original_of(wrapped)
      super("#{banner}: #{original.message} (#{original.class})")
      # Prefer the locations, because they let an enclosing capture locate the
      # tool file line (see #find_locations). They are unavailable if the
      # wrapped error was never raised, or if it is itself a ContextualError on
      # a Ruby too old to retain locations through set_backtrace, so fall back
      # to the strings rather than leaving the backtrace unset.
      Compat.set_backtrace(self, wrapped.backtrace_locations || wrapped.backtrace)
      @banner = banner
      @tool_verb = tool_verb
      @tool_name = tool_name
      @tool_args = tool_args
      @tool_file_path = @tool_file_line = nil
      find_locations(path, original)
      @final = final
    end

    ##
    # An overall banner message
    # @return [String]
    #
    attr_reader :banner

    ##
    # The path to the toys tool file in which the error was detected.
    #
    # @return [String] if a tool file is found in the backtrace.
    # @return [nil] if no backtrace is available or no toys tool file could be
    #     found in it.
    #
    attr_reader :tool_file_path
    alias config_path tool_file_path

    ##
    # The line number in the toys tool file in which the error was detected.
    #
    # @return [Integer] if a tool file is found in the backtrace.
    # @return [nil] if no backtrace is available or no toys tool file could be
    #     found in it.
    #
    attr_reader :tool_file_line
    alias config_line tool_file_line

    ##
    # The verb in progress when the error occurred.
    #
    # @return [String] should be either "loading" or "running"
    # @return [nil] if the verb is not known
    #
    attr_reader :tool_verb

    ##
    # The full name of the tool that was running or being loaded when the error
    # occurred.
    #
    # @return [Array<String>]
    #
    attr_reader :tool_name

    ##
    # The arguments passed to the tool that was running when the error occurred.
    #
    # @return [Array<String>]
    #
    attr_reader :tool_args

    ##
    # Returns the root cause of this error, i.e. the first cause in the chain
    # that is not itself a ContextualError.
    #
    # @return [Exception] The root cause.
    # @return [nil] if this error has no cause, which happens only if it was
    #     constructed outside a rescue.
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
    def update_fields!(path: nil, tool_verb: nil, tool_name: nil, tool_args: nil, final: false)
      @tool_verb = tool_verb if @tool_verb.nil? && !tool_verb.nil?
      @tool_name = tool_name if @tool_name.nil? && !tool_name.nil?
      @tool_args = tool_args if @tool_args.nil? && !tool_args.nil?
      find_locations(path, original_of(cause))
      @final = true if final
    end

    private

    ##
    # Look through any ContextualError wrappers to the exception that
    # originally caused the error. Falls back to the wrapper itself if it has
    # no cause of its own, and returns nil if given nil.
    #
    def original_of(wrapped)
      wrapped.is_a?(ContextualError) ? wrapped.root_cause || wrapped : wrapped
    end

    ##
    # Extract tool_file_path and tool_file_line from the error, if needed.
    # Uses text in the SyntaxError, or the backtrace.
    #
    def find_locations(path, original)
      return if path.nil? || original.nil? || !@tool_file_path.nil? || !@tool_file_line.nil?
      if original.is_a?(::SyntaxError)
        match = /#{::Regexp.escape(path)}:(\d+)/.match(original.message)
        if match
          @tool_file_path = path
          @tool_file_line = match[1].to_i
          return
        end
      end
      (original.backtrace_locations || []).each do |loc|
        if loc.absolute_path == path || loc.path == path
          @tool_file_path = path
          @tool_file_line = loc.lineno
          break
        end
      end
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
      def capture(banner: nil, path: nil, tool_verb: nil, tool_name: nil, tool_args: nil, final: false)
        yield
      rescue ContextualError => e
        if e.final?
          raise ContextualError.new(e, banner, path, tool_verb, tool_name, tool_args, final)
        else
          e.update_fields!(path: path, tool_verb: tool_verb, tool_name: tool_name, tool_args: tool_args, final: final)
          raise e
        end
      rescue ::ScriptError, ::StandardError => e
        raise ContextualError.new(e, banner, path, tool_verb, tool_name, tool_args, final)
      end
    end
  end
end
