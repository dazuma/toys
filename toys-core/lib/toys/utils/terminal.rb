# Copyright 2018 Daniel Azuma
#
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice,
#   this list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# * Neither the name of the copyright holder, nor the names of any other
#   contributors to this software, may be used to endorse or promote products
#   derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
;

require "stringio"

begin
  require "io/console"
rescue ::LoadError # rubocop:disable Lint/HandleExceptions
  # TODO: use stty to get terminal size
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
    # *   A symbol indicating the name of a well-known style, or the name of
    #     a defined style.
    # *   An rgb string in hex "rgb" or "rrggbb" form.
    # *   An ANSI code string in `\e[XXm` form.
    # *   An array of ANSI codes as integers.
    #
    class Terminal
      ## ANSI style code to clear styles
      CLEAR_CODE = "\e[0m".freeze

      ## Standard ANSI style codes
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
        bg_black: [30],
        bg_red: [31],
        bg_green: [32],
        bg_yellow: [33],
        bg_blue: [34],
        bg_magenta: [35],
        bg_cyan: [36],
        bg_white: [37],
        bright_black: [90],
        bright_red: [91],
        bright_green: [92],
        bright_yellow: [93],
        bright_blue: [94],
        bright_magenta: [95],
        bright_cyan: [96],
        bright_white: [97],
        bg_bright_black: [100],
        bg_bright_red: [101],
        bg_bright_green: [102],
        bg_bright_yellow: [103],
        bg_bright_blue: [104],
        bg_bright_magenta: [105],
        bg_bright_cyan: [106],
        bg_bright_white: [107]
      }.freeze

      ##
      # Returns a copy of the given string with all ANSI style codes removed.
      #
      # @param [String] str Input string
      # @return [String] String with styles removed
      #
      def self.remove_style_escapes(str)
        str.gsub(/\e\[\d+(;\d+)*m/, "")
      end

      ##
      # Create a terminal.
      #
      # @param [IO,Logger,nil] output Output stream or logger.
      # @param [IO,nil] input Input stream.
      #
      def initialize(input: $stdin,
                     output: $stdout,
                     styled: nil)
        @input = input
        @output = output
        @styled =
          if styled.nil?
            output.respond_to?(:tty?) && output.tty?
          else
            styled ? true : false
          end
        @named_styles = BUILTIN_STYLE_NAMES.dup
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
      attr_accessor :styled

      ##
      # Write a line.
      #
      # @param [String] str The line to write
      # @param [Symbol,String,Array<Integer>...] styles Styles to apply to the
      #     entire line.
      #
      def puts(str = "", *styles)
        output.puts(apply_styles(str, *styles))
        output.flush
        self
      end

      ##
      # Write a line.
      #
      # @param [String] str The line to write
      #
      def <<(str)
        puts(str)
      end

      ##
      # Write a newline and flush the current line.
      #
      def newline
        puts
      end

      ##
      # Buffer a partial line but do not write it out yet because the line
      # may not yet be complete.
      #
      # @param [String] str The line to write
      # @param [Symbol,String,Array<Integer>...] styles Styles to apply to the
      #     partial line.
      #
      def write(str = "", *styles)
        output.write(apply_styles(str, *styles))
        output.flush
        self
      end

      ##
      # Confirm with the user.
      #
      # @param [String] prompt Prompt string. Defaults to `"Proceed?"`.
      # @return [Boolean]
      #
      def confirm(prompt = "Proceed?")
        write("#{prompt} (y/n) ")
        resp = input.gets
        if resp =~ /^y/i
          true
        elsif resp =~ /^n/i
          false
        else
          confirm("Please answer \"y\" or \"n\"")
        end
      end

      ##
      # Return the terminal size as an array of width, height.
      #
      # @return [Array(Integer,Integer)]
      #
      def terminal_size
        if @output.respond_to?(:tty?) && @output.tty? && @output.respond_to?(:winsize)
          @output.winsize.reverse
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
        terminal_size[0]
      end

      ##
      # Return the terminal height
      #
      # @return [Integer]
      #
      def height
        terminal_size[1]
      end

      ##
      # Define a named style.
      #
      # Style names must be symbols.
      # The definition of a style may include any valid style specification,
      # including the symbol names of existing defined styles.
      #
      # @param [Symbol] name The name for the style
      # @param [Symbol,String,Array<Integer>...] styles
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
      # @param [String] str String to style
      # @param [Symbol,String,Array<Integer>...] styles Styles to apply
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
          $1.split(";").map(&:to_i)
        end
      end
    end
  end
end
