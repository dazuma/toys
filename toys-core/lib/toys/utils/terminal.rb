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

require "stringio"
require "monitor"

begin
  require "io/console"
rescue ::LoadError # rubocop:disable Lint/SuppressedException
  # TODO: alternate methods of getting terminal size
end

module Toys
  module Utils
    ##
    # A simple terminal class.
    #
    # ## Styles
    #
    # This class supports ANSI styled output where supported.
    #
    # Styles may be specified in any of the following forms:
    #  *  A symbol indicating the name of a well-known style, or the name of
    #     a defined style.
    #  *  An rgb string in hex "rgb" or "rrggbb" form.
    #  *  An ANSI code string in `\e[XXm` form.
    #  *  An array of ANSI codes as integers.
    #
    class Terminal
      ##
      # Fatal terminal error.
      #
      class TerminalError < ::StandardError
      end

      ##
      # ANSI style code to clear styles
      # @return [String]
      #
      CLEAR_CODE = "\e[0m"

      ##
      # Standard ANSI style codes by name.
      # @return [Hash{Symbol => Array<Integer>}]
      #
      BUILTIN_STYLE_NAMES = {
        clear: [0],
        reset: [0],
        bold: [1],
        faint: [2],
        italic: [3],
        underline: [4],
        blink: [5],
        reverse: [7],
        black: [30],
        red: [31],
        green: [32],
        yellow: [33],
        blue: [34],
        magenta: [35],
        cyan: [36],
        white: [37],
        on_black: [30],
        on_red: [31],
        on_green: [32],
        on_yellow: [33],
        on_blue: [34],
        on_magenta: [35],
        on_cyan: [36],
        on_white: [37],
        bright_black: [90],
        bright_red: [91],
        bright_green: [92],
        bright_yellow: [93],
        bright_blue: [94],
        bright_magenta: [95],
        bright_cyan: [96],
        bright_white: [97],
        on_bright_black: [100],
        on_bright_red: [101],
        on_bright_green: [102],
        on_bright_yellow: [103],
        on_bright_blue: [104],
        on_bright_magenta: [105],
        on_bright_cyan: [106],
        on_bright_white: [107],
      }.freeze

      ##
      # Default length of a single spinner frame, in seconds.
      # @return [Float]
      #
      DEFAULT_SPINNER_FRAME_LENGTH = 0.1

      ##
      # Default set of spinner frames.
      # @return [Array<String>]
      #
      DEFAULT_SPINNER_FRAMES = ["-", "\\", "|", "/"].freeze

      ##
      # Returns a copy of the given string with all ANSI style codes removed.
      #
      # @param str [String] Input string
      # @return [String] String with styles removed
      #
      def self.remove_style_escapes(str)
        str.gsub(/\e\[\d+(;\d+)*m/, "")
      end

      ##
      # Create a terminal.
      #
      # @param input [IO,nil] Input stream.
      # @param output [IO,Logger,nil] Output stream or logger.
      # @param styled [Boolean,nil] Whether to output ansi styles. If `nil`, the
      #     setting is inferred from whether the output has a tty.
      #
      def initialize(input: $stdin, output: $stdout, styled: nil)
        @input = input
        @output = output
        @styled =
          if styled.nil?
            output.respond_to?(:tty?) && output.tty?
          else
            styled ? true : false
          end
        @named_styles = BUILTIN_STYLE_NAMES.dup
        @output_mutex = ::Monitor.new
        @input_mutex = ::Monitor.new
      end

      ##
      # Output stream or logger
      # @return [IO,Logger,nil]
      #
      attr_reader :output

      ##
      # Input stream
      # @return [IO,nil]
      #
      attr_reader :input

      ##
      # Whether output is styled
      # @return [Boolean]
      #
      attr_reader :styled

      ##
      # Write a partial line without appending a newline.
      #
      # @param str [String] The line to write
      # @param styles [Symbol,String,Array<Integer>...] Styles to apply to the
      #     partial line.
      # @return [self]
      #
      def write(str = "", *styles)
        @output_mutex.synchronize do
          begin
            output&.write(apply_styles(str, *styles))
            output&.flush
          rescue ::IOError
            nil
          end
        end
        self
      end

      ##
      # Read a line, blocking until one is available.
      #
      # @return [String] the entire string including the temrinating newline
      # @return [nil] if the input is closed or at eof, or there is no input
      #
      def readline
        @input_mutex.synchronize do
          begin
            input&.gets
          rescue ::IOError
            nil
          end
        end
      end

      ##
      # This method is defined so that `::Logger` will recognize a terminal as
      # a log device target, but it does not actually close anything.
      #
      def close
        nil
      end

      ##
      # Write a line, appending a newline if one is not already present.
      #
      # @param str [String] The line to write
      # @param styles [Symbol,String,Array<Integer>...] Styles to apply to the
      #     entire line.
      # @return [self]
      #
      def puts(str = "", *styles)
        str = "#{str}\n" unless str.end_with?("\n")
        write(str, *styles)
      end
      alias say puts

      ##
      # Write a line, appending a newline if one is not already present.
      #
      # @param str [String] The line to write
      # @return [self]
      #
      def <<(str)
        puts(str)
      end

      ##
      # Write a newline and flush the current line.
      # @return [self]
      #
      def newline
        puts
      end

      ##
      # Ask a question and get a response.
      #
      # @param prompt [String] Required prompt string.
      # @param styles [Symbol,String,Array<Integer>...] Styles to apply to the
      #     prompt.
      # @param default [String,nil] Default value, or `nil` for no default.
      #     Uses `nil` if not specified.
      # @param trailing_text [:default,String,nil] Trailing text appended to
      #     the prompt, `nil` for none, or `:default` to show the default.
      # @return [String]
      #
      def ask(prompt, *styles, default: nil, trailing_text: :default)
        if trailing_text == :default
          trailing_text = default.nil? ? nil : "[#{default}]"
        end
        if trailing_text
          ptext, pspaces, = prompt.partition(/\s+$/)
          prompt = "#{ptext} #{trailing_text}#{pspaces}"
        end
        write(prompt, *styles)
        resp = readline.to_s.chomp
        resp.empty? ? default.to_s : resp
      end

      ##
      # Confirm with the user.
      #
      # @param prompt [String] Prompt string. Defaults to `"Proceed?"`.
      # @param styles [Symbol,String,Array<Integer>...] Styles to apply to the
      #     prompt.
      # @param default [Boolean,nil] Default value, or `nil` for no default.
      #     Uses `nil` if not specified.
      # @return [Boolean]
      #
      def confirm(prompt = "Proceed? ", *styles, default: nil)
        default_val, trailing_text =
          case default
          when true
            ["y", "(Y/n)"]
          when false
            ["n", "(y/N)"]
          else
            [nil, "(y/n)"]
          end
        resp = ask(prompt, *styles, default: default_val, trailing_text: trailing_text)
        return true if resp =~ /^y/i
        return false if resp =~ /^n/i
        if resp.nil? && default.nil?
          raise TerminalError, "Cannot confirm because the input stream is at eof."
        end
        if !resp.strip.empty? || default.nil?
          if input.nil?
            raise TerminalError, "Cannot confirm because there is no input stream."
          end
          confirm('Please answer "y" or "n"', default: default)
        else
          default
        end
      end

      ##
      # Display a spinner during a task. You should provide a block that
      # performs the long-running task. While the block is executing, a
      # spinner will be displayed.
      #
      # @param leading_text [String] Optional leading string to display to the
      #     left of the spinner. Default is the empty string.
      # @param frame_length [Float] Length of a single frame, in seconds.
      #     Defaults to {DEFAULT_SPINNER_FRAME_LENGTH}.
      # @param frames [Array<String>] An array of frames. Defaults to
      #     {DEFAULT_SPINNER_FRAMES}.
      # @param style [Symbol,Array<Symbol>] A terminal style or array of styles
      #     to apply to all frames in the spinner. Defaults to empty,
      # @param final_text [String] Optional final string to display when the
      #     spinner is complete. Default is the empty string. A common practice
      #     is to set this to newline.
      # @return [Object] The return value of the block.
      #
      def spinner(leading_text: "", final_text: "",
                  frame_length: nil, frames: nil, style: nil)
        return nil unless block_given?
        frame_length ||= DEFAULT_SPINNER_FRAME_LENGTH
        frames ||= DEFAULT_SPINNER_FRAMES
        write(leading_text) unless leading_text.empty?
        spin = SpinDriver.new(self, frames, Array(style), frame_length)
        begin
          yield
        ensure
          spin.stop
          write(final_text) unless final_text.empty?
        end
      end

      ##
      # Return the terminal size as an array of width, height.
      #
      # @return [Array(Integer,Integer)]
      #
      def size
        if output.respond_to?(:tty?) && output.tty? && output.respond_to?(:winsize)
          output.winsize.reverse
        else
          [80, 25]
        end
      end

      ##
      # Return the terminal width
      #
      # @return [Integer]
      #
      def width
        size[0]
      end

      ##
      # Return the terminal height
      #
      # @return [Integer]
      #
      def height
        size[1]
      end

      ##
      # Define a named style.
      #
      # Style names must be symbols.
      # The definition of a style may include any valid style specification,
      # including the symbol names of existing defined styles.
      #
      # @param name [Symbol] The name for the style
      # @param styles [Symbol,String,Array<Integer>...]
      # @return [self]
      #
      def define_style(name, *styles)
        @named_styles[name] = resolve_styles(*styles)
        self
      end

      ##
      # Apply the given styles to the given string, returning the styled
      # string. Honors the styled setting; if styling is disabled, does not
      # add any ANSI style codes and in fact removes any existing codes. If
      # styles were added, ensures that the string ends with a clear code.
      #
      # @param str [String] String to style
      # @param styles [Symbol,String,Array<Integer>...] Styles to apply
      # @return [String] The styled string
      #
      def apply_styles(str, *styles)
        if styled
          prefix = escape_styles(*styles)
          suffix = prefix.empty? || str.end_with?(CLEAR_CODE) ? "" : CLEAR_CODE
          "#{prefix}#{str}#{suffix}"
        else
          Terminal.remove_style_escapes(str)
        end
      end

      private

      ##
      # Resolve a style to an ANSI style escape sequence.
      #
      def escape_styles(*styles)
        codes = resolve_styles(*styles)
        codes.empty? ? "" : "\e[#{codes.join(';')}m"
      end

      ##
      # Resolve a style to an array of ANSI style codes (integers).
      #
      def resolve_styles(*styles)
        result = []
        styles.each do |style|
          codes =
            case style
            when ::Array
              style
            when ::String
              interpret_style_string(style)
            when ::Symbol
              @named_styles[style]
            end
          raise ::ArgumentError, "Unknown style code: #{s.inspect}" unless codes
          result.concat(codes)
        end
        result
      end

      ##
      # Transform various style string formats into a list of style codes.
      #
      def interpret_style_string(style)
        case style
        when /^[0-9a-fA-F]{6}$/
          rgb = style.to_i(16)
          [38, 2, rgb >> 16, (rgb & 0xff00) >> 8, rgb & 0xff]
        when /^[0-9a-fA-F]{3}$/
          rgb = style.to_i(16)
          [38, 2, (rgb >> 8) * 0x11, ((rgb & 0xf0) >> 4) * 0x11, (rgb & 0xf) * 0x11]
        when /^\e\[([\d;]+)m$/
          ::Regexp.last_match(1).split(";").map(&:to_i)
        end
      end

      ## @private
      class SpinDriver
        include ::MonitorMixin

        def initialize(terminal, frames, style, frame_length)
          @mutex = ::Monitor.new
          @terminal = terminal
          @frames = frames.map do |f|
            [@terminal.apply_styles(f, *style), Terminal.remove_style_escapes(f).size]
          end
          @frame_length = frame_length
          @cur_frame = 0
          @stopping = false
          @cond = new_cond
          @thread = @terminal.output.tty? ? start_thread : nil
        end

        def stop
          @mutex.synchronize do
            @stopping = true
            @cond.broadcast
          end
          @thread&.join
          self
        end

        private

        def start_thread
          ::Thread.new do
            @mutex.synchronize do
              until @stopping
                @terminal.write(@frames[@cur_frame][0])
                @cond.wait(@frame_length)
                size = @frames[@cur_frame][1]
                @terminal.write("\b" * size + " " * size + "\b" * size)
                @cur_frame += 1
                @cur_frame = 0 if @cur_frame >= @frames.size
              end
            end
          end
        end
      end
    end
  end
end
