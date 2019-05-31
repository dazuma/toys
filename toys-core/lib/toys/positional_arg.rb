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
  # Representation of a formal positional argument
  #
  class PositionalArg
    ##
    # Create an Arg definition.
    # Should be created only from methods of {Toys::ToolDefinition}.
    # @private
    #
    def initialize(key, type, acceptor, default, completion, desc, long_desc, display_name)
      @key = key
      @type = type
      @acceptor = acceptor
      @default = default
      @completion = completion
      @desc = WrappableString.make(desc)
      @long_desc = WrappableString.make_array(long_desc)
      @display_name = display_name || key.to_s.tr("-", "_").gsub(/\W/, "").upcase
    end

    ##
    # Returns the key.
    # @return [Symbol]
    #
    attr_reader :key

    ##
    # Type of this argument.
    # @return [:required,:optional,:remaining]
    #
    attr_reader :type

    ##
    # Returns the acceptor, which may be `nil`.
    # @return [Tool::Acceptor::Base,nil]
    #
    attr_accessor :acceptor

    ##
    # Returns the default value, which may be `nil`.
    # @return [Object]
    #
    attr_reader :default

    ##
    # Returns the proc that determines shell completions for the value.
    # @return [Proc,Toys::Completion::Base]
    #
    attr_reader :completion

    ##
    # Returns the short description string.
    # @return [Toys::WrappableString]
    #
    attr_reader :desc

    ##
    # Returns the long description strings as an array.
    # @return [Array<Toys::WrappableString>]
    #
    attr_reader :long_desc

    ##
    # Returns the displayable name.
    # @return [String]
    #
    attr_accessor :display_name

    ##
    # Set the short description string.
    #
    # The description may be provided as a {Toys::WrappableString}, a single
    # string (which will be wrapped), or an array of strings, which will be
    # interpreted as string fragments that will be concatenated and wrapped.
    #
    # @param [Toys::WrappableString,String,Array<String>] desc
    #
    def desc=(desc)
      @desc = WrappableString.make(desc)
    end

    ##
    # Set the long description strings.
    #
    # Each string may be provided as a {Toys::WrappableString}, a single
    # string (which will be wrapped), or an array of strings, which will be
    # interpreted as string fragments that will be concatenated and wrapped.
    #
    # @param [Array<Toys::WrappableString,String,Array<String>>] long_desc
    #
    def long_desc=(long_desc)
      @long_desc = WrappableString.make_array(long_desc)
    end
  end
end
