# frozen_string_literal: true

module Toys
  ##
  # A string intended for word-wrapped display.
  #
  class WrappableString
    ##
    # Create a wrapped string.
    # @param string [String,Array<String>] The string or array of string
    #     fragments
    #
    def initialize(string = "")
      @fragments = string.is_a?(::Array) ? string.map(&:to_s) : string.to_s.split
    end

    ##
    # Returns the string fragments, i.e. the individual "words" for wrapping.
    #
    # @return [Array<String>]
    #
    attr_reader :fragments

    ##
    # Returns a new WrappaableString whose content is the concatenation of this
    # WrappableString with another WrappableString.
    #
    # @param other [WrappableString]
    # @return [WrappableString]
    #
    def +(other)
      other = WrappableString.new(other) unless other.is_a?(WrappableString)
      WrappableString.new(fragments + other.fragments)
    end

    ##
    # Returns true if the string is empty (i.e. has no fragments)
    # @return [Boolean]
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

    ##
    # Tests two wrappable strings for equality
    # @param other [Object]
    # @return [Boolean]
    #
    def ==(other)
      return false unless other.is_a?(WrappableString)
      other.fragments == fragments
    end
    alias eql? ==

    ##
    # Returns a hash code for this object
    # @return [Integer]
    #
    def hash
      fragments.hash
    end

    ##
    # Wraps the string to the given width.
    #
    # @param width [Integer,nil] Width in characters, or `nil` for infinite.
    # @param width2 [Integer,nil] Width in characters for the second and
    #     subsequent lines, or `nil` to use the same as width.
    #
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
    # @param strs [Array<WrappableString>] Array of strings to wrap.
    # @param width [Integer,nil] Width in characters, or `nil` for infinite.
    # @param width2 [Integer,nil] Width in characters for the second and
    #     subsequent lines, or `nil` to use the same as width.
    #
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
    # @param obj [Toys::WrappableString,String,Array<String>]
    # @return [Toys::WrappableString]
    #
    def self.make(obj)
      obj.is_a?(WrappableString) ? obj : WrappableString.new(obj)
    end

    ##
    # Make the given object an array of WrappableString.
    #
    # @param objs [Array<Toys::WrappableString,String,Array<String>>]
    # @return [Array<Toys::WrappableString>]
    #
    def self.make_array(objs)
      Array(objs).map { |obj| make(obj) }
    end
  end
end
