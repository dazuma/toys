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
    # @param [String,Symbol] key The key to use to retrieve the value from
    #     the execution context.
    # @param [Symbol] type The type of arg. Valid values are `:required`,
    #     `:optional`, and `:remaining`.
    # @param [Object] accept An acceptor that validates and/or converts the
    #     value. You may provide either the name of an acceptor you have
    #     defined, or one of the default acceptors provided by OptionParser.
    #     Optional. If not specified, accepts any value as a string.
    # @param [Object] completion A specifier for shell tab completion. See
    #     {Toys::Completion.create} for recognized formats.
    # @param [String] display_name A name to use for display (in help text and
    #     error reports). Defaults to the key in upper case.
    # @param [String,Array<String>,Toys::WrappableString] desc Short
    #     description for the flag. See {Toys::DSL::Tool#desc} for a
    #     description of the allowed formats. Defaults to the empty string.
    # @param [Array<String,Array<String>,Toys::WrappableString>] long_desc
    #     Long description for the flag. See {Toys::DSL::Tool#long_desc} for
    #     a description of the allowed formats. (But note that this param
    #     takes an Array of description lines, rather than a series of
    #     arguments.) Defaults to the empty array.
    # @return [Toys::PositionalArg]
    #
    def self.create(key, type,
                    accept: nil, default: nil, completion: nil, desc: nil,
                    long_desc: nil, display_name: nil)
      new(key, type, accept, default, completion, desc, long_desc, display_name)
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
    # Returns the effective acceptor.
    # @return [Tool::Acceptor::Base]
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
