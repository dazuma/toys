# frozen_string_literal: true

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
    # DSL for a flag definition block. Lets you set flag attributes in a block
    # instead of a long series of keyword arguments.
    #
    # These directives are available inside a block passed to
    # {Toys::DSL::Tool#flag}.
    #
    class Flag
      ## @private
      def initialize(flags, accept, default, handler, report_collisions,
                     group, desc, long_desc, display_name)
        @flags = flags
        @accept = accept
        @default = default
        @handler = handler
        @report_collisions = report_collisions
        @group = group
        @desc = desc
        @long_desc = long_desc || []
        @display_name = display_name
      end

      ##
      # Add flags in OptionParser format. This may be called multiple times,
      # and the results are cumulative.
      #
      # @param [String...] flags
      # @return [Toys::DSL::Flag] self, for chaining.
      #
      def flags(*flags)
        @flags += flags
        self
      end

      ##
      # Set the OptionParser acceptor.
      #
      # @param [Object] accept
      # @return [Toys::DSL::Flag] self, for chaining.
      #
      def accept(accept)
        @accept = accept
        self
      end

      ##
      # Set the default value.
      #
      # @param [Object] default
      # @return [Toys::DSL::Flag] self, for chaining.
      #
      def default(default)
        @default = default
        self
      end

      ##
      # Set the optional handler for setting/updating the value when a flag is
      # parsed. A handler should be a Proc taking two arguments, the new given
      # value and the previous value, and it should return the new value that
      # should be set. You may pass the handler as a Proc (or an object
      # responding to the `call` method) or you may pass a block.
      #
      # @param [Proc] handler
      # @return [Toys::DSL::Flag] self, for chaining.
      #
      def handler(handler = nil, &block)
        @handler = handler || block
        self
      end

      ##
      # Set whether to raise an exception if a flag is requested that is
      # already in use or marked as disabled.
      #
      # @param [Boolean] setting
      # @return [Toys::DSL::Flag] self, for chaining.
      #
      def report_collisions(setting)
        @report_collisions = setting
        self
      end

      ##
      # Set the short description. See {Toys::DSL::Tool#desc} for the allowed
      # formats.
      #
      # @param [String,Array<String>,Toys::Utils::WrappableString] desc
      # @return [Toys::DSL::Flag] self, for chaining.
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
      # @return [Toys::DSL::Flag] self, for chaining.
      #
      def long_desc(*long_desc)
        @long_desc += long_desc
        self
      end

      ##
      # Set the group. A group may be set by name or group object. Setting
      # `nil` selects the default group.
      #
      # @param [String,Symbol,Toys::Definition::FlagGroup,nil] group
      # @return [Toys::DSL::Flag] self, for chaining.
      #
      def group(group)
        @group = group
        self
      end

      ##
      # Set the display name. This may be used in help text and error messages.
      #
      # @param [String] display_name
      # @return [Toys::DSL::Flag] self, for chaining.
      #
      def display_name(display_name)
        @display_name = display_name
        self
      end

      ## @private
      def _add_to(tool, key)
        tool.add_flag(key, @flags,
                      accept: @accept, default: @default, handler: @handler,
                      report_collisions: @report_collisions, group: @group,
                      desc: @desc, long_desc: @long_desc, display_name: @display_name)
      end
    end
  end
end
