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
  # A FlagGroup is a group of flags with the same requirement settings.
  #
  module FlagGroup
    ##
    # The base class of a FlagGroup, implementing everything except validation.
    # The base class effectively behaves as an Optional group. However, you
    # should use {Toys::FlagGroup::Optional} to represent such a group.
    #
    class Base
      ##
      # Create a flag group.
      # Should be created only from methods of {Toys::ToolDefinition}.
      # @private
      #
      def initialize(name, desc, long_desc)
        @name = name
        @desc = WrappableString.make(desc || default_desc)
        @long_desc = WrappableString.make_array(long_desc || default_long_desc)
        @flags = []
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
      # @return [Array<Toys::Flag>]
      #
      attr_reader :flags

      ##
      # Returns true if this group is empty
      # @return [Boolean]
      #
      def empty?
        flags.empty?
      end

      ## @private
      def <<(flag)
        flags << flag
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
      def validation_errors(_seen)
        []
      end
    end

    ##
    # A FlagGroup containing all required flags
    #
    class Required < Base
      ## @private
      def validation_errors(seen)
        results = []
        flags.each do |flag|
          unless seen.include?(flag.key)
            results << "Flag \"#{flag.display_name}\" is required."
          end
        end
        results
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
    class Optional < Base
    end

    ##
    # A FlagGroup in which exactly one flag must be set
    #
    class ExactlyOne < Base
      ## @private
      def validation_errors(seen)
        seen_names = []
        flags.each do |flag|
          seen_names << flag.display_name if seen.include?(flag.key)
        end
        if seen_names.size > 1
          ["Exactly one flag out of group \"#{desc}\" is required, but #{seen_names.size}" \
            " were provided: #{seen_names.inspect}."]
        elsif seen_names.empty?
          ["Exactly one flag out of group \"#{desc}\" is required, but none were provided."]
        else
          []
        end
      end

      ## @private
      def default_long_desc
        "Exactly one of these flags must be set."
      end
    end

    ##
    # A FlagGroup in which at most one flag must be set
    #
    class AtMostOne < Base
      ## @private
      def validation_errors(seen)
        seen_names = []
        flags.each do |flag|
          seen_names << flag.display_name if seen.include?(flag.key)
        end
        if seen_names.size > 1
          ["At most one flag out of group \"#{desc}\" is required, but #{seen_names.size}" \
            " were provided: #{seen_names.inspect}."]
        else
          []
        end
      end

      ## @private
      def default_long_desc
        "At most one of these flags must be set."
      end
    end

    ##
    # A FlagGroup in which at least one flag must be set
    #
    class AtLeastOne < Base
      ## @private
      def validation_errors(seen)
        flags.each do |flag|
          return [] if seen.include?(flag.key)
        end
        ["At least one flag out of group \"#{desc}\" is required, but none were provided."]
      end

      ## @private
      def default_long_desc
        "At least one of these flags must be set."
      end
    end
  end
end
