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

require "highline"

module Toys
  module Utils
    ##
    # Something that outputs lines to the console or log.
    #
    class LineOutput
      ##
      # Create a line output.
      #
      # @param [IO,Logger,nil] sink Where to write lines.
      #
      def initialize(sink, log_level: ::Logger::INFO, support_styles: nil)
        @sink = sink
        @log_level = sink.is_a?(::Logger) ? log_level : nil
        @support_styles =
          if support_styles.nil?
            sink.respond_to?(:tty?) && sink.tty?
          else
            support_styles ? true : false
          end
      end

      ##
      # Where to write lines
      # @return [IO,Logger,nil]
      #
      attr_reader :sink

      ##
      # Whether the sink is a tty
      # @return [Boolean]
      #
      attr_reader :support_styles

      ##
      # If the sink is a Logger, the level to log, otherwise `nil`.
      # @return [Integer,nil]
      #
      attr_reader :log_level

      ##
      # Write a line.
      #
      # @param [String] str The line to write
      # @param [Symbol...] styles Styles to apply to the entire line.
      #
      def puts(str = "", *styles)
        if support_styles
          str = color(str, *styles) unless styles.empty?
        else
          str = ::HighLine.uncolor(str)
        end
        case sink
        when ::Logger
          sink.log(log_level, str)
        when ::IO
          sink.puts(str)
        end
        self
      end

      ##
      # Apply the given styles to a string
      #
      # @param [String] str The string
      # @param [Symbol...] styles Styles to apply to the string.
      # @return [String] The string with styles applied.
      #
      def color(str, *styles)
        ::HighLine.color(str, *styles)
      end
    end
  end
end
