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
      def initialize(accept, default, display_name, desc, long_desc)
        @accept = accept
        @default = default
        @display_name = display_name
        @desc = desc
        @long_desc = long_desc || []
      end

      ##
      # Set the OptionParser acceptor.
      # @param [Object] accept
      #
      def accept(accept)
        @accept = accept
        self
      end

      ##
      # Set the default value.
      # @param [Object] default
      #
      def default(default)
        @default = default
        self
      end

      ##
      # Set the name of this arg as it appears in help screens.
      # @param [String] display_name
      #
      def display_name(display_name)
        @display_name = display_name
        self
      end

      ##
      # Set the short description. See {Toys::DSL::Tool#desc} for the allowed
      # formats.
      #
      # @param [String,Array<String>,Toys::Utils::WrappableString] desc
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
      # @param [String,Array<String>,Toys::Utils::WrappableString...] long_desc
      #
      def long_desc(*long_desc)
        @long_desc += long_desc
        self
      end

      ## @private
      def _add_required_to(tool, key)
        tool.add_required_arg(key,
                              accept: @accept, display_name: @display_name,
                              desc: @desc, long_desc: @long_desc)
      end

      ## @private
      def _add_optional_to(tool, key)
        tool.add_optional_arg(key,
                              accept: @accept, default: @default, display_name: @display_name,
                              desc: @desc, long_desc: @long_desc)
      end

      ## @private
      def _set_remaining_on(tool, key)
        tool.set_remaining_args(key,
                                accept: @accept, default: @default, display_name: @display_name,
                                desc: @desc, long_desc: @long_desc)
      end
    end
  end
end
