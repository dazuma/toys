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

module Toys
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
    def string
      @fragments.join(" ")
    end
    alias to_s string

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
        frag_len = frag.gsub(/\e\[\d+(;\d+)*m/, "").size
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
      lines << line if line_len.positive?
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
        s = make(s)
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
    # @param [Toys::WrappableString,String,Array<String>] obj
    # @return [Toys::WrappableString]
    #
    def self.make(obj)
      obj.is_a?(WrappableString) ? obj : WrappableString.new(obj)
    end

    ##
    # Make the given object an array of WrappableString.
    #
    # @param [Array<Toys::WrappableString,String,Array<String>>] objs
    # @return [Array<Toys::WrappableString>]
    #
    def self.make_array(objs)
      Array(objs).map { |obj| make(obj) }
    end
  end
end
