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
    # DSL for an arg definition block. Lets you set arg attributes in a block
    # instead of a long series of keyword arguments.
    #
    # These directives are available inside a block passed to
    # {Toys::DSL::Tool#required_arg}, {Toys::DSL::Tool#optional_arg}, or
    # {Toys::DSL::Tool#remaining_args}.
    #
    class Arg
      ## @private
      def initialize(accept, default, completion, display_name, desc, long_desc)
        @accept = accept
        @default = default
        @completion = completion
        @display_name = display_name
        @desc = desc
        @long_desc = long_desc || []
      end

      ##
      # Set the OptionParser acceptor.
      #
      # @param [Object] accept
      # @return [Toys::DSL::Tool] self, for chaining.
      #
      def accept(accept)
        @accept = accept
        self
      end

      ##
      # Set the default value.
      #
      # @param [Object] default
      # @return [Toys::DSL::Tool] self, for chaining.
      #
      def default(default)
        @default = default
        self
      end

      ##
      # Set the shell completion strategy.
      # See {Toys::Definition::Completion.create} for recognized formats.
      #
      # @param [Object] value
      # @return [Toys::DSL::Tool] self, for chaining.
      #
      def completion(value, &block)
        @completion = value || block
        self
      end

      ##
      # Set the name of this arg as it appears in help screens.
      #
      # @param [String] display_name
      # @return [Toys::DSL::Tool] self, for chaining.
      #
      def display_name(display_name)
        @display_name = display_name
        self
      end

      ##
      # Set the short description. See {Toys::DSL::Tool#desc} for the allowed
      # formats.
      #
      # @param [String,Array<String>,Toys::WrappableString] desc
      # @return [Toys::DSL::Tool] self, for chaining.
      #
      def desc(desc)
        @desc = desc
        self
      end

      ##
      # Adds to the long description. This may be called multiple times, and
      # the results are cumulative. See {Toys::DSL::Tool#long_desc} for the
      # allowed formats.
      #
      # @param [String,Array<String>,Toys::WrappableString...] long_desc
      # @return [Toys::DSL::Tool] self, for chaining.
      #
      def long_desc(*long_desc)
        @long_desc += long_desc
        self
      end

      ## @private
      def _add_required_to(tool, key)
        tool.add_required_arg(key,
                              accept: @accept, completion: @completion,
                              display_name: @display_name, desc: @desc, long_desc: @long_desc)
      end

      ## @private
      def _add_optional_to(tool, key)
        tool.add_optional_arg(key,
                              accept: @accept, default: @default, completion: @completion,
                              display_name: @display_name, desc: @desc, long_desc: @long_desc)
      end

      ## @private
      def _set_remaining_on(tool, key)
        tool.set_remaining_args(key,
                                accept: @accept, default: @default, completion: @completion,
                                display_name: @display_name, desc: @desc, long_desc: @long_desc)
      end
    end
  end
end
