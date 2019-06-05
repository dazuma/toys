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
  module DSL
    ##
    # DSL for a flag group definition block. Lets you create flags in a group.
    #
    # These directives are available inside a block passed to
    # {Toys::DSL::Tool#flag_group} and related methods.
    #
    class FlagGroup
      ## @private
      def initialize(tool_dsl, tool, flag_group)
        @tool_dsl = tool_dsl
        @tool = tool
        @flag_group = flag_group
      end

      ##
      # Add a flag to the current tool. Each flag must specify a key which
      # the script may use to obtain the flag value from the context.
      # You may then provide the flags themselves in OptionParser form.
      #
      # If the given key is a symbol representing a valid method name, then a
      # helper method is automatically added to retrieve the value. Otherwise,
      # if the key is a string or does not represent a valid method name, the
      # tool can retrieve the value by calling {Toys::Context#get}.
      #
      # Attributes of the flag may be passed in as arguments to this method, or
      # set in a block passed to this method. If you provide a block, you can
      # use directives in {Toys::DSL::Flag} within the block.
      #
      # @param [String,Symbol] key The key to use to retrieve the value from
      #     the execution context.
      # @param [String...] flags The flags in OptionParser format.
      # @param [Object] accept An acceptor that validates and/or converts the
      #     value. You may provide either the name of an acceptor you have
      #     defined, or one of the default acceptors provided by OptionParser.
      #     Optional. If not specified, accepts any value as a string.
      # @param [Object] default The default value. This is the value that will
      #     be set in the context if this flag is not provided on the command
      #     line. Defaults to `nil`.
      # @param [Proc,nil] handler An optional handler for setting/updating the
      #     value. If given, it should take two arguments, the new given value
      #     and the previous value, and it should return the new value that
      #     should be set. The default handler simply replaces the previous
      #     value. i.e. the default is effectively `-> (val, _prev) { val }`.
      # @param [Object] complete_flags A specifier for shell tab completion
      #     for flag names associated with this flag. By default, a
      #     {Toys::Flag::StandardCompletion} is used, which provides the flag's
      #     names as completion candidates. To customize completion, set this
      #     to the name of a previously defined completion, a hash of options
      #     to pass to the constructor for {Toys::Flag::StandardCompletion}, or
      #     any other spec recognized by {Toys::Completion.create}.
      # @param [Object] complete_values A specifier for shell tab completion
      #     for flag values associated with this flag. This is the empty
      #     completion by default. To customize completion, set this to the
      #     name of a previously defined completion, or any spec recognized by
      #     {Toys::Completion.create}.
      # @param [Boolean] report_collisions Raise an exception if a flag is
      #     requested that is already in use or marked as unusable. Default is
      #     true.
      # @param [String,Array<String>,Toys::WrappableString] desc Short
      #     description for the flag. See {Toys::DSL::Tool#desc} for a
      #     description of the allowed formats. Defaults to the empty string.
      # @param [Array<String,Array<String>,Toys::WrappableString>] long_desc
      #     Long description for the flag. See {Toys::DSL::Tool#long_desc} for
      #     a description of the allowed formats. (But note that this param
      #     takes an Array of description lines, rather than a series of
      #     arguments.) Defaults to the empty array.
      # @param [String] display_name A display name for this flag, used in help
      #     text and error messages.
      # @yieldparam flag_dsl [Toys::DSL::Flag] An object that lets you
      #     configure this flag in a block.
      # @return [self]
      #
      def flag(key, *flags,
               accept: nil, default: nil, handler: nil, complete_flags: nil, complete_values: nil,
               report_collisions: true, desc: nil, long_desc: nil, display_name: nil,
               &block)
        flag_dsl = DSL::Flag.new(flags, accept, default, handler, complete_flags, complete_values,
                                 report_collisions, @flag_group, desc, long_desc, display_name)
        flag_dsl.instance_exec(flag_dsl, &block) if block
        flag_dsl._add_to(@tool, key)
        DSL::Tool.maybe_add_getter(@tool_dsl, key)
        self
      end
    end
  end
end
