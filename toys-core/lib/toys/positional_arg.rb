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
    # Create a PositionalArg definition.
    # This argument list is subject to change. Use {Toys::PositionalArg.create}
    # instead for a more stable interface.
    # @private
    #
    def initialize(key, type, acceptor, default, completion, desc, long_desc, display_name)
      @key = key
      @type = type
      @acceptor = Acceptor.create(acceptor)
      @default = default
      @completion = Completion.create(completion)
      @desc = WrappableString.make(desc)
      @long_desc = WrappableString.make_array(long_desc)
      @display_name = display_name || key.to_s.tr("-", "_").gsub(/\W/, "").upcase
    end

    ##
    # Create a PositionalArg definition.
    #
    # @param key [String,Symbol] The key to use to retrieve the value from
    #     the execution context.
    # @param type [Symbol] The type of arg. Valid values are `:required`,
    #     `:optional`, and `:remaining`.
    # @param accept [Object] An acceptor that validates and/or converts the
    #     value. See {Toys::Acceptor.create} for recognized formats. Optional.
    #     If not specified, defaults to {Toys::Acceptor::DEFAULT}.
    # @param complete [Object] A specifier for shell tab completion. See
    #     {Toys::Completion.create} for recognized formats.
    # @param display_name [String] A name to use for display (in help text and
    #     error reports). Defaults to the key in upper case.
    # @param desc [String,Array<String>,Toys::WrappableString] Short
    #     description for the flag. See {Toys::DSL::Tool#desc} for a
    #     description of the allowed formats. Defaults to the empty string.
    # @param long_desc [Array<String,Array<String>,Toys::WrappableString>]
    #     Long description for the flag. See {Toys::DSL::Tool#long_desc} for
    #     a description of the allowed formats. (But note that this param
    #     takes an Array of description lines, rather than a series of
    #     arguments.) Defaults to the empty array.
    # @return [Toys::PositionalArg]
    #
    def self.create(key, type,
                    accept: nil, default: nil, complete: nil, desc: nil,
                    long_desc: nil, display_name: nil)
      new(key, type, accept, default, complete, desc, long_desc, display_name)
    end

    ##
    # The key for this arg.
    # @return [Symbol]
    #
    attr_reader :key

    ##
    # Type of this argument.
    # @return [:required,:optional,:remaining]
    #
    attr_reader :type

    ##
    # The effective acceptor.
    # @return [Tool::Acceptor::Base]
    #
    attr_accessor :acceptor

    ##
    # The default value, which may be `nil`.
    # @return [Object]
    #
    attr_reader :default

    ##
    # The proc that determines shell completions for the value.
    # @return [Proc,Toys::Completion::Base]
    #
    attr_reader :completion

    ##
    # The short description string.
    #
    # When reading, this is always returned as a {Toys::WrappableString}.
    #
    # When setting, the description may be provided as any of the following:
    # *   A {Toys::WrappableString}.
    # *   A normal String, which will be transformed into a
    #     {Toys::WrappableString} using spaces as word delimiters.
    # *   An Array of String, which will be transformed into a
    #     {Toys::WrappableString} where each array element represents an
    #     individual word for wrapping.
    #
    # @return [Toys::WrappableString]
    #
    attr_reader :desc

    ##
    # The long description strings.
    #
    # When reading, this is returned as an Array of {Toys::WrappableString}
    # representing the lines in the description.
    #
    # When setting, the description must be provided as an Array where _each
    # element_ may be any of the following:
    # *   A {Toys::WrappableString} representing one line.
    # *   A normal String representing a line. This will be transformed into a
    #     {Toys::WrappableString} using spaces as word delimiters.
    # *   An Array of String representing a line. This will be transformed into
    #     a {Toys::WrappableString} where each array element represents an
    #     individual word for wrapping.
    #
    # @return [Array<Toys::WrappableString>]
    #
    attr_reader :long_desc

    ##
    # The displayable name.
    # @return [String]
    #
    attr_accessor :display_name

    ##
    # Set the short description string.
    #
    # See {#desc} for details.
    #
    # @param desc [Toys::WrappableString,String,Array<String>]
    #
    def desc=(desc)
      @desc = WrappableString.make(desc)
    end

    ##
    # Set the long description strings.
    #
    # See {#long_desc} for details.
    #
    # @param long_desc [Array<Toys::WrappableString,String,Array<String>>]
    #
    def long_desc=(long_desc)
      @long_desc = WrappableString.make_array(long_desc)
    end
  end
end
