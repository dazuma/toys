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

module Toys
  module Utils
    ##
    # A string marked as wrappable.
    #
    class WrappedString
      ##
      # Create a wrapped string.
      # @param [String] string The string.
      #
      def initialize(string = "")
        @string = string
      end

      ##
      # Returns the string.
      # @return [String]
      #
      attr_reader :string

      ##
      # Returns the string.
      # @return [String]
      #
      def to_s
        string
      end

      ##
      # Wraps the string to the given width.
      #
      # @param [Integer] width Width in characters.
      # @return [Array<String>] Wrapped lines
      #
      def wrap(width)
        lines = []
        str = string.gsub(/\s/, " ").sub(/^\s+/, "")
        until str.empty?
          i = str.index(/\S(\s|$)/) + 1
          loop do
            next_i = str.index(/\S(\s|$)/, i)
            break if next_i.nil? || next_i >= width
            i = next_i + 1
          end
          lines << str[0, i]
          str = str[i..-1].sub(/^\s+/, "")
        end
        lines
      end
    end
  end
end
