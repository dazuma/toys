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
  # A wrapper exception used to provide user-oriented context for an exception
  #
  class ContextualError < ::StandardError
    ## @private
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

    attr_reader :cause
    attr_reader :banner

    attr_accessor :config_path
    attr_accessor :config_line
    attr_accessor :tool_name
    attr_accessor :tool_args

    class << self
      ## @private
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
      rescue ::ScriptError, ::StandardError => e
        e = ContextualError.new(e, banner)
        add_fields_if_missing(e, opts)
        add_config_path_if_missing(e, path)
        raise e
      end

      ## @private
      def capture(banner, **opts)
        yield
      rescue ContextualError => e
        add_fields_if_missing(e, opts)
        raise e
      rescue ::ScriptError, ::StandardError => e
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
          l = (error.cause.backtrace_locations || []).find { |b| b.absolute_path == path }
          if l
            error.config_path = path
            error.config_line = l.lineno
          end
        end
      end
    end
  end
end
