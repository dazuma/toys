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
    # A string intended to be wrapped.
    #
    class WrappableString
      ##
      # Create a wrapped string.
      # @param [String,Array<String>] string The string or array of string
      #     fragments
      #
      def initialize(string = "")
        @fragments = string.is_a?(::Array) ? string.map(&:to_s) : string.to_s.split
      end

      ##
      # Returns the fragments.
      # @return [Array<String>]
      #
      attr_reader :fragments

      ##
      # Concatenates this WrappableString with another WrappableString
      # @param [WrappableString] other
      #
      def +(other)
        other = WrappableString.new(other) unless other.is_a?(WrappableString)
        WrappableString.new(fragments + other.fragments)
      end

      ##
      # Returns true if the string is empty (i.e. has no fragments)
      # @return [String]
      #
      def empty?
        @fragments.empty?
      end

      ##
      # Returns the string without any wrapping
      # @return [String]
      #
      def to_s
        @fragments.join(" ")
      end
      alias string to_s

      ## @private
      def ==(other)
        return false unless other.is_a?(WrappableString)
        other.fragments == fragments
      end
      alias eql? ==

      ## @private
      def hash
        fragments.hash
      end

      ##
      # Wraps the string to the given width.
      #
      # @param [Integer,nil] width Width in characters, or `nil` for infinite.
      # @param [Integer,nil] width2 Width in characters for the second and
      #     subsequent lines, or `nil` to use the same as width.
      # @return [Array<String>] Wrapped lines
      #
      def wrap(width, width2 = nil)
        lines = []
        line = ""
        line_len = 0
        fragments.each do |frag|
          frag_len = Utils::Terminal.remove_style_escapes(frag).size
          if line_len.zero?
            line = frag
            line_len = frag_len
          elsif width && line_len + 1 + frag_len > width
            lines << line
            line = frag
            line_len = frag_len
            width = width2 if width2
          else
            line_len += frag_len + 1
            line = "#{line} #{frag}"
          end
        end
        lines << line if line_len > 0
        lines
      end

      ##
      # Wraps an array of lines to the given width.
      #
      # @param [Array<WrappableString>] strs Array of strings to wrap.
      # @param [Integer,nil] width Width in characters, or `nil` for infinite.
      # @param [Integer,nil] width2 Width in characters for the second and
      #     subsequent lines, or `nil` to use the same as width.
      # @return [Array<String>] Wrapped lines
      #
      def self.wrap_lines(strs, width, width2 = nil)
        result = Array(strs).map do |s|
          lines = s.empty? ? [""] : s.wrap(width, width2)
          width = width2 if width2
          lines
        end.flatten
        result = [] if result.all?(&:empty?)
        result
      end

      ##
      # Make the given object a WrappableString.
      # If the object is already a WrappableString, return it. Otherwise,
      # treat it as a string or an array of strings and wrap it in a
      # WrappableString.
      #
      # @param [Toys::Utils::WrappableString,String,Array<String>] obj
      # @return [Toys::Utils::WrappableString]
      #
      def self.make(obj)
        obj.is_a?(Utils::WrappableString) ? obj : Utils::WrappableString.new(obj)
      end

      ##
      # Make the given object an array of WrappableString.
      #
      # @param [Array<Toys::Utils::WrappableString,String,Array<String>>] objs
      # @return [Array<Toys::Utils::WrappableString>]
      #
      def self.make_array(objs)
        Array(objs).map { |obj| make(obj) }
      end
    end
  end
end
