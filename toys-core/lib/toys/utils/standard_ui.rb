# frozen_string_literal: true

require "logger"

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
      # @param backtrace_omit_prefixes [Array<String>] An array of directories
      #     under which Ruby files should be elided from backtraces. Optional.
      #     To elide internal Toys framework files, you can pass
      #     {Toys.framework_lib_paths}.
      # @param incomplete_backtrace_message [String] A message to display when
      #     the backtrace has been elided. Optional.
      #
      def initialize(output: nil, backtrace_omit_prefixes: nil, incomplete_backtrace_message: nil)
        require "toys/utils/terminal"
        @terminal = output || $stderr
        @terminal = Terminal.new(output: @terminal) unless @terminal.is_a?(Terminal)
        @backtrace_omit_prefixes = backtrace_omit_prefixes&.map do |dir|
          dir.end_with?(::File::SEPARATOR) ? dir : "#{dir}#{::File::SEPARATOR}"
        end
        @incomplete_backtrace_message = incomplete_backtrace_message
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
          error_handler: error_handler_proc,
          logger_factory: logger_factory_proc,
        }
      end

      ##
      # Convenience method that returns the error handler proc implemented by
      # this UI (in the {#handle_error} method). This proc can be passed to
      # the `:error_handler` argument in the {Toys::CLI} constructor.
      #
      # @return [Proc]
      #
      def error_handler_proc
        method(:handle_error).to_proc
      end

      ##
      # Convenience method that returns the logger factory proc implemented by
      # this UI (in the {#create_logger} method). This proc can be passed to
      # the `:logger_factory` argument in the {Toys::CLI} constructor.
      #
      # @return [Proc]
      #
      def logger_factory_proc
        method(:create_logger).to_proc
      end

      ##
      # Implementation of an error handler. As dictated by the error handler
      # specification in {Toys::Runner}, this takes the error as its argument,
      # and returns an exit code or raises an exception.
      #
      # The base implementation uses {#display_error_notice} and
      # {#display_signal_notice} to print an appropriate message to the UI's
      # terminal, and uses {#exit_code_for} to determine the correct exit code.
      # Any of those methods can be overridden by a subclass to alter their
      # behavior, or this main implementation method can be overridden to
      # change the overall behavior.
      #
      # @param error [Toys::ContextualError,SignalException,StandardError,ScriptError]
      #     The error received. An unhandled signal arrives unwrapped. Any
      #     other error normally arrives as a {Toys::ContextualError} wrapper,
      #     but arrives unwrapped if the run disabled error wrapping.
      # @return [Integer] The exit code
      #
      def handle_error(error)
        case error
        when ::SignalException
          display_signal_notice(error)
          exit_code_for(error)
        when ContextualError
          display_error_notice(error)
          exit_code_for(error.root_cause)
        else
          display_error_notice(error)
          exit_code_for(error)
        end
      end

      ##
      # Implementation of a logger factory. As dictated by the logger factory
      # specification in {Toys::Runner}, this must take a {Toys::ToolDefinition}
      # as an argument, and return a `Logger`.
      #
      # The base implementation returns a logger that writes to the UI's
      # terminal, using {#format_log_entry} as the formatter. It sets the level
      # to `Logger::WARN` by default. Either this method or the helper methods
      # can be overridden to change this behavior.
      #
      # @param _tool {Toys::ToolDefinition} The tool definition of the tool to
      #     be executed
      # @return [Logger]
      #
      def create_logger(_tool)
        logger = ::Logger.new(@terminal)
        logger.formatter = method(:format_log_entry).to_proc
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
      # This method is used by {#handle_error} and can be overridden to change
      # its behavior.
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
      # This method is used by {#handle_error} and can be overridden to change
      # its behavior.
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
      # Displays a default output for an error.
      #
      # The output format includes the error message itself, a backtrace
      # (possibly with some entries omitted), and the stack of tool calls if
      # available (i.e. if the error is a ContextualError).
      #
      # This method is used by {#handle_error} and can be overridden to change
      # the rendering.
      #
      # @param error [Toys::ContextualError,StandardError,ScriptError] The
      #     error to display. An error that is not a {Toys::ContextualError}
      #     is displayed by itself, with no context blocks.
      #
      def display_error_notice(error)
        @terminal.puts
        origin, banner, frames = error_frames(error)
        render_backtrace(origin)
        render_banner(banner)
        frames.each do |frame|
          render_tool_line(frame)
        end
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
      def format_log_entry(severity, time, _progname, msg)
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

      # Walks the chain of nested ContextualErrors starting from the given
      # error, to determine which errors to use for which purposes. Returns,
      # in order:
      #  1. The error to use for backtraces, usually the original cause (the
      #     first non-ContextualError in the chain)
      #  2. The error to use for the banner, usually the first ContextualError
      #     in the chain
      #  3. The full chain of ContextualErrors, to use for the tool call stack
      def error_frames(error)
        frames = []
        current = error
        while current.is_a?(ContextualError)
          frames << current
          current = current.cause
        end
        frames.reverse!
        first_frame = frames.first
        [current || first_frame, first_frame || current, frames]
      end

      # Renders a stack trace, if appropriate
      def render_backtrace(error)
        internals_count = 0
        frames_hidden = false
        backtrace = error.backtrace_locations || error.backtrace || []
        @terminal.puts("Backtrace (outermost to innermost)") unless backtrace.empty?
        backtrace.each_with_index.reverse_each do |loc, i|
          if omit_frame?(loc)
            internals_count += 1
            frames_hidden = true
          else
            render_internal_frames(internals_count)
            internals_count = 0
            @terminal.puts("  #{(i + 1).to_s.rjust(3)}: #{loc}")
          end
        end
        render_internal_frames(internals_count)
        @terminal.puts("    #{@incomplete_backtrace_message}") if frames_hidden && @incomplete_backtrace_message
      end

      def omit_frame?(loc)
        return false unless @backtrace_omit_prefixes
        loc_str = loc.respond_to?(:absolute_path) ? (loc.absolute_path || loc.path).to_s : loc.strip
        @backtrace_omit_prefixes.any? { |pre| loc_str.start_with?(pre) }
      end

      def render_internal_frames(count)
        return unless count.positive?
        frame_text = count == 1 ? "frame" : "frames"
        @terminal.puts("    (...#{count} internal framework #{frame_text}...)")
      end

      # Renders the headline of the error: the message and the calculated
      # source location.
      def render_banner(error)
        if error.is_a?(::Toys::ContextualError)
          @terminal.puts(error.message, :bold)
          unless error.tool_file_path.nil?
            @terminal.puts("    (#{error.tool_file_path}:#{error.tool_file_line})", :bold)
          end
        else
          @terminal.puts("#{error.message} (#{error.class})", :bold)
        end
      end

      # Renders the tool name and arguments for one frame.
      def render_tool_line(error)
        return unless error.tool_verb
        tool_desc =
          if error.tool_name.nil?
            "tools"
          else
            desc1 = error.tool_name.empty? ? "the root tool" : "tool: #{error.tool_name.join(' ').inspect}"
            error.tool_args.nil? ? desc1 : "#{desc1}, with arguments: #{error.tool_args.inspect}"
          end
        @terminal.puts("while #{error.tool_verb} #{tool_desc}")
      end
    end
  end
end
