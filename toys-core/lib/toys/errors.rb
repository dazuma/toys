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
  # An exception indicating a problem during tool lookup
  #
  class LoaderError < ::StandardError
  end

  ##
  # A wrapper exception used to provide user-oriented context for an error
  # thrown during tool execution.
  #
  class ContextualError < ::StandardError
    ##
    # Construct a ContextualError. This exception type is thrown from
    # {ContextualError.capture} and {ContextualError.capture_path} and should
    # not be constructed directly.
    #
    # @private This interface is internal and subject to change without warning.
    #
    def initialize(cause, banner,
                   config_path: nil, config_line: nil,
                   tool_name: nil, tool_args: nil)
      super("#{banner} : #{cause.message} (#{cause.class})")
      @cause = cause
      @banner = banner
      @config_path = config_path
      @config_line = config_line
      @tool_name = tool_name
      @tool_args = tool_args
      set_backtrace(cause.backtrace)
    end

    ##
    # The underlying exception
    # @return [::StandardError]
    #
    attr_reader :cause

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
    attr_writer :config_path

    ##
    # @private
    #
    attr_writer :config_line

    ##
    # @private
    #
    attr_writer :tool_name

    ##
    # @private
    #
    attr_writer :tool_args

    class << self
      ##
      # Execute the given block, and wrap any exceptions thrown with a
      # ContextualError. This is intended for loading a config file from the
      # given path, and wraps any Ruby parsing errors.
      #
      # @private This interface is internal and subject to change without warning.
      #
      def capture_path(banner, path, **opts)
        yield
      rescue ContextualError => e
        add_fields_if_missing(e, opts)
        add_config_path_if_missing(e, path)
        raise e
      rescue ::SyntaxError => e
        if (match = /#{::Regexp.escape(path)}:(\d+)/.match(e.message))
          opts = opts.merge(config_path: path, config_line: match[1].to_i)
          e = ContextualError.new(e, banner, **opts)
        end
        raise e
      rescue ::ScriptError, ::StandardError, ::SignalException => e
        e = ContextualError.new(e, banner)
        add_fields_if_missing(e, opts)
        add_config_path_if_missing(e, path)
        raise e
      end

      ##
      # Execute the given block, and wrap any exceptions thrown with a
      # ContextualError.
      #
      # @private This interface is internal and subject to change without warning.
      #
      def capture(banner, **opts)
        yield
      rescue ContextualError => e
        add_fields_if_missing(e, opts)
        raise e
      rescue ::ScriptError, ::StandardError, ::SignalException => e
        raise ContextualError.new(e, banner, **opts)
      end

      private

      def add_fields_if_missing(error, opts)
        opts.each do |k, v|
          error.send(:"#{k}=", v) if error.send(k).nil?
        end
      end

      def add_config_path_if_missing(error, path)
        if error.config_path.nil? && error.config_line.nil?
          l = (error.cause.backtrace_locations || []).find do |b|
            b.absolute_path == path || b.path == path
          end
          if l
            error.config_path = path
            error.config_line = l.lineno
          end
        end
      end
    end
  end
end
