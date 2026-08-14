# frozen_string_literal: true

module Toys
  ##
  # Splits tool names into words, according to a set of delimiter characters.
  #
  # A tool name is a series of words. On the command line, and in various
  # places in the DSL, a name can be written as a single string with its words
  # separated by delimiters. Whitespace is always a delimiter; additional
  # characters can be configured when a splitter is created.
  #
  # A splitter is immutable, and can be shared by any number of objects that
  # need to interpret tool names the same way.
  #
  class ToolNameSplitter
    ##
    # Create a splitter.
    #
    # @param extra_delimiters [String] A string containing characters that can
    #     function as delimiters in a tool name, in addition to whitespace.
    #     Defaults to empty. Allowed characters are period, colon, and slash.
    #
    def initialize(extra_delimiters = "")
      unless %r{^[[:space:]./:]*$}.match?(extra_delimiters)
        raise ::ArgumentError, "Illegal delimiters in #{extra_delimiters.inspect}"
      end
      @extra_delimiters = -extra_delimiters
      # Whitespace is always a delimiter, so any whitespace in the extra
      # delimiters is dropped here rather than duplicated in the character
      # class, which Ruby warns about.
      chars = ::Regexp.escape(extra_delimiters.chars.uniq.grep_v(/[[:space:]]/).join)
      @delimiters = ::Regexp.new("[[:space:]#{chars}]")
      @trailing_word = ::Regexp.new("\\A(.+#{@delimiters})(.*)\\z", ::Regexp::MULTILINE)
      freeze
    end

    ##
    # The extra delimiters this splitter was created with, as given. Whitespace
    # is a delimiter whether or not it appears here.
    #
    # @return [String]
    #
    attr_reader :extra_delimiters

    ##
    # Splits the given tool name into words. You may pass either an array,
    # whose elements are copied as strings without being split further, or a
    # single string or symbol possibly delimited by this splitter's delimiters.
    # Always returns a new array of strings.
    #
    # @param name [String,Symbol,Array<String,Symbol>] The name to split.
    # @return [Array<String>]
    #
    def split(name)
      return name.map(&:to_s) if name.is_a?(::Array)
      name.to_s.split(@delimiters)
    end

    ##
    # Splits a partially typed name, such as a fragment being completed, into
    # the portion that names a path and the trailing partial word.
    #
    # Returns a two-element array. The first element is the leading portion of
    # the string through its final delimiter, or the empty string if there is
    # none; pass it to {#split} to get the path words. The second element is
    # the text following that delimiter.
    #
    # A delimiter is recognized as a separator only if at least one character
    # precedes it, so a string that begins with a delimiter is not split.
    #
    # @param str [String] The partial name to split.
    # @return [Array(String,String)]
    #
    def split_partial(str)
      match = @trailing_word.match(str)
      match ? [match[1], match[2]] : ["", str]
    end

    ##
    # @return [String] a description of this splitter's delimiters
    #
    def inspect
      "#<Toys::ToolNameSplitter extra_delimiters=#{@extra_delimiters.inspect}>"
    end

    ##
    # A splitter that recognizes only whitespace as a delimiter. This is the
    # splitter used when no other is configured.
    #
    # @return [Toys::ToolNameSplitter]
    #
    DEFAULT = new
  end
end
