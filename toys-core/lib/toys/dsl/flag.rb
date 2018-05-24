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
    class Flag
      ## @private
      def initialize(flags, accept, default, handler, report_collisions, desc, long_desc)
        @flags = flags
        @accept = accept
        @default = default
        @handler = handler
        @report_collisions = report_collisions
        @desc = desc
        @long_desc = long_desc
      end

      ##
      # Add flags in OptionParser format. This may be called multiple times,
      # and the results are cumulative.
      # @param [String...] flags
      #
      def flags(*flags)
        @flags += flags
        self
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
      # Set the optional handler for setting/updating the value when a flag is
      # parsed. It should be a Proc taking two arguments, the new given value
      # and the previous value, and it should return the new value that should
      # be set.
      # @param [Proc] handler
      #
      def handler(handler)
        @handler = handler
        self
      end

      ##
      # Set whether to raise an exception if a flag is requested that is
      # already in use or marked as disabled.
      # @param [Boolean] setting
      #
      def report_collisions(setting)
        @report_collisions = setting
        self
      end

      ##
      # Set the short description. See {Toys::ConfigDSL#desc} for the allowed
      # formats.
      # @param [String,Array<String>,Toys::Utils::WrappableString] desc
      #
      def desc(desc)
        @desc = desc
        self
      end

      ##
      # Adds to the long description. This may be called multiple times, and
      # the results are cumulative. See {Toys::ConfigDSL#long_desc} for the
      # allowed formats.
      # @param [String,Array<String>,Toys::Utils::WrappableString...] long_desc
      #
      def long_desc(*long_desc)
        @long_desc += long_desc
        self
      end

      ## @private
      def _add_to(tool, key)
        tool.add_flag(key, @flags,
                      accept: @accept, default: @default, handler: @handler,
                      report_collisions: @report_collisions,
                      desc: @desc, long_desc: @long_desc)
      end
    end
  end
end
