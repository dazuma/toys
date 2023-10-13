# frozen_string_literal: true

module Toys
  module Utils
    ##
    # An object that implements standard UI elements, such as error reports and
    # logging, as provided by the `toys` command line. Specifically, it
    # implements pretty formatting of log entries and stack traces, and renders
    # using ANSI coloring where available via {Toys::Utils::Terminal}.
    #
    # This object can be used to implement `toys`-style behavior when creating
    # a CLI object. For example:
    #
    #     require "toys/utils/standard_ui"
    #     ui = Toys::Utils::StandardUI.new
    #     cli = Toys::CLI.new(**ui.cli_args)
    #
    class StandardUI
      ##
      # Create a Standard UI.
      #
      # By default, all output is written to `$stderr`, and will share a single
      # {Toys::Utils::Terminal} object, allowing multiple tools and/or threads
      # to interleave messages without interrupting one another.
      #
      # @param output [IO,Toys::Utils::Terminal] Where to write output. You can
      #     pass a terminal object, or an IO stream that will be wrapped in a
      #     terminal output. Default is `$stderr`.
      #
      def initialize(output: nil)
        require "logger"
        require "toys/utils/terminal"
        @terminal = output || $stderr
        @terminal = Terminal.new(output: @terminal) unless @terminal.is_a?(Terminal)
        @log_header_severity_styles = {
          "FATAL" => [:bright_magenta, :bold, :underline],
          "ERROR" => [:bright_red, :bold],
          "WARN" => [:bright_yellow],
          "INFO" => [:bright_cyan],
          "DEBUG" => [:white],
        }
      end

      ##
      # The terminal underlying this UI
      #
      # @return [Toys::Utils::Terminal]
      #
      attr_reader :terminal

      ##
      # A hash that maps severities to styles recognized by
      # {Toys::Utils::Terminal}. Used to style the header for each log entry.
      # This hash can be modified in place to adjust the behavior of loggers
      # created by this UI.
      #
      # @return [Hash{String => Array<Symbol>}]
      #
      attr_reader :log_header_severity_styles

      ##
      # Convenience method that returns a hash of arguments that can be passed
      # to the {Toys::CLI} constructor. Includes the `:error_handler` and
      # `:logger_factory` arguments.
      #
      # @return [Hash]
      #
      def cli_args
        {
          error_handler: error_handler,
          logger_factory: logger_factory,
        }
      end

      ##
      # Returns an error handler conforming to the `:error_handler` argument to
      # the {Toys::CLI} constructor. Specifically, it returns the
      # {#error_handler_impl} method as a proc.
      #
      # @return [Proc]
      #
      def error_handler
        @error_handler ||= method(:error_handler_impl).to_proc
      end

      ##
      # Returns a logger factory conforming to the `:logger_factory` argument
      # to the {Toys::CLI} constructor. Specifically, it returns the
      # {#logger_factory_impl} method as a proc.
      #
      # @return [Proc]
      #
      def logger_factory
        @logger_factory ||= method(:logger_factory_impl).to_proc
      end

      ##
      # Implementation of the error handler. As dictated by the error handler
      # specification in {Toys::CLI}, this must take a {Toys::ContextualError}
      # as an argument, and return an exit code.
      #
      # The base implementation uses {#display_error_notice} and
      # {#display_signal_notice} to print an appropriate message to the UI's
      # terminal, and uses {#exit_code_for} to determine the correct exit code.
      # Any of those methods can be overridden by a subclass to alter their
      # behavior, or this main implementation method can be overridden to
      # change the overall behavior.
      #
      # @param error [Toys::ContextualError] The error received
      # @return [Integer] The exit code
      #
      def error_handler_impl(error)
        cause = error.cause
        if cause.is_a?(::SignalException)
          display_signal_notice(cause)
        else
          display_error_notice(error)
        end
        exit_code_for(cause)
      end

      ##
      # Implementation of the logger factory. As dictated by the logger factory
      # specification in {Toys::CLI}, this must take a {Toys::ToolDefinition}
      # as an argument, and return a `Logger`.
      #
      # The base implementation returns a logger that writes to the UI's
      # terminal, using {#logger_formatter_impl} as the formatter. It sets the
      # level to `Logger::WARN` by default. Either this method or the helper
      # methods can be overridden to change this behavior.
      #
      # @param _tool {Toys::ToolDefinition} The tool definition of the tool to
      #     be executed
      # @return [Logger]
      #
      def logger_factory_impl(_tool)
        logger = ::Logger.new(@terminal)
        logger.formatter = method(:logger_formatter_impl).to_proc
        logger.level = ::Logger::WARN
        logger
      end

      ##
      # Returns an exit code appropriate for the given exception. Currently,
      # the logic interprets signals (returning the convention of 128 + signo),
      # usage errors (returning the conventional value of 2), and tool not
      # runnable errors (returning the conventional value of 126), and defaults
      # to 1 for all other error types.
      #
      # This method is used by {#error_handler_impl} and can be overridden to
      # change its behavior.
      #
      # @param error [Exception] The exception raised. This method expects the
      #     original exception, rather than a ContextualError.
      # @return [Integer] The appropriate exit code
      #
      def exit_code_for(error)
        case error
        when ArgParsingError
          2
        when NotRunnableError
          126
        when ::SignalException
          error.signo + 128
        else
          1
        end
      end

      ##
      # Displays a default output for a signal received.
      #
      # This method is used by {#error_handler_impl} and can be overridden to
      # change its behavior.
      #
      # @param error [SignalException]
      #
      def display_signal_notice(error)
        @terminal.puts
        if error.is_a?(::Interrupt)
          @terminal.puts("INTERRUPTED", :bold)
        else
          @terminal.puts("SIGNAL RECEIVED: #{error.signm || error.signo}", :bold)
        end
      end

      ##
      # Displays a default output for an error. Displays the error, the
      # backtrace, and contextual information regarding what tool was run and
      # where in its code the error occurred.
      #
      # This method is used by {#error_handler_impl} and can be overridden to
      # change its behavior.
      #
      # @param error [Toys::ContextualError]
      #
      def display_error_notice(error)
        @terminal.puts
        @terminal.puts(cause_string(error.cause))
        @terminal.puts(context_string(error), :bold)
      end

      ##
      # Implementation of the formatter used by loggers created by this UI's
      # logger factory. This interface is defined by the standard `Logger`
      # class.
      #
      # This method can be overridden to change the behavior of loggers created
      # by this UI.
      #
      # @param severity [String]
      # @param time [Time]
      # @param _progname [String]
      # @param msg [Object]
      # @return [String]
      #
      def logger_formatter_impl(severity, time, _progname, msg)
        msg_str =
          case msg
          when ::String
            msg
          when ::Exception
            "#{msg.message} (#{msg.class})\n" << (msg.backtrace || []).join("\n")
          else
            msg.inspect
          end
        timestr = time.strftime("%Y-%m-%d %H:%M:%S")
        header = format("[%<time>s %<sev>5s]", time: timestr, sev: severity)
        styles = log_header_severity_styles[severity]
        header = @terminal.apply_styles(header, *styles) if styles
        "#{header}  #{msg_str}\n"
      end

      private

      def cause_string(cause)
        lines = ["#{cause.class}: #{cause.message}"]
        cause.backtrace.each_with_index.reverse_each do |bt, i|
          lines << "    #{(i + 1).to_s.rjust(3)}: #{bt}"
        end
        lines.join("\n")
      end

      def context_string(error)
        lines = [
          error.banner || "Unexpected error!",
          "    #{error.cause.class}: #{error.cause.message}",
        ]
        if error.config_path
          lines << "    in config file: #{error.config_path}:#{error.config_line}"
        end
        if error.tool_name
          lines << "    while executing tool: #{error.tool_name.join(' ').inspect}"
          if error.tool_args
            lines << "    with arguments: #{error.tool_args.inspect}"
          end
        end
        lines.join("\n")
      end
    end
  end
end
