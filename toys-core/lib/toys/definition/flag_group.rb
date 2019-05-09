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
  module Definition
    ##
    # Representation of a group of flags with the same requirement settings.
    #
    class FlagGroup
      ##
      # Create a flag group.
      # @private
      #
      def initialize(name, desc, long_desc)
        @name = name
        @desc = WrappableString.make(desc || default_desc)
        @long_desc = WrappableString.make_array(long_desc || default_long_desc)
        @flag_definitions = []
      end

      ##
      # Returns the symbolic name for this group
      # @return [String,Symbol,nil]
      #
      attr_reader :name

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
      # Returns an array of flags that are in this group.
      # Do not modify the returned array.
      # @return [Array<Toys::Definition::Flag>]
      #
      attr_reader :flag_definitions

      ##
      # Returns true if this group is empty
      # @return [Boolean]
      #
      def empty?
        flag_definitions.empty?
      end

      ## @private
      def <<(flag)
        flag_definitions << flag
      end

      ## @private
      def default_desc
        "Flags"
      end

      ## @private
      def default_long_desc
        nil
      end

      ## @private
      def validation_error(_seen)
        nil
      end

      ##
      # A FlagGroup containing all required flags
      #
      class Required < FlagGroup
        ## @private
        def validation_error(seen)
          flag_definitions.each do |flag|
            unless seen.include?(flag.key)
              return "Flag \"#{flag.display_name}\" is required"
            end
          end
          nil
        end

        ## @private
        def default_desc
          "Required Flags"
        end

        ## @private
        def default_long_desc
          "These flags are required."
        end
      end

      ##
      # A FlagGroup containing all optional flags
      #
      class Optional < FlagGroup
      end

      ##
      # A FlagGroup in which exactly one flag must be set
      #
      class ExactlyOne < FlagGroup
        ## @private
        def validation_error(seen)
          set_flag = nil
          flag_definitions.each do |flag|
            if seen.include?(flag.key)
              if set_flag
                return "Exactly one out of group \"#{desc}\" is required, but both" \
                  " \"#{set_flag.display_name}\" and \"#{flag.display_name}\" were set"
              else
                set_flag = flag
              end
            end
          end
          return "Exactly one out of group \"#{desc}\" is required" unless set_flag
          nil
        end

        ## @private
        def default_long_desc
          "Exactly one of these flags must be set."
        end
      end

      ##
      # A FlagGroup in which at most one flag must be set
      #
      class AtMostOne < FlagGroup
        ## @private
        def validation_error(seen)
          set_flag = nil
          flag_definitions.each do |flag|
            if seen.include?(flag.key)
              if set_flag
                return "At most one out of group \"#{desc}\" is required, but both" \
                  " \"#{set_flag.display_name}\" and \"#{flag.display_name}\" were set"
              else
                set_flag = flag
              end
            end
          end
          nil
        end

        ## @private
        def default_long_desc
          "At most one of these flags must be set."
        end
      end

      ##
      # A FlagGroup in which at least one flag must be set
      #
      class AtLeastOne < FlagGroup
        ## @private
        def validation_error(seen)
          flag_definitions.each do |flag|
            return nil if seen.include?(flag.key)
          end
          "At least one out of group \"#{desc}\" is required"
        end

        ## @private
        def default_long_desc
          "At least one of these flags must be set."
        end
      end
    end
  end
end
