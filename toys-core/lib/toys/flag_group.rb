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
    # Create a flag group object of the given type.
    #
    # The type should be one of the following symbols:
    # *   `:optional` All flags in the group are optional
    # *   `:required` All flags in the group are required
    # *   `:exactly_one` Exactly one flag in the group must be provided
    # *   `:at_least_one` At least one flag in the group must be provided
    # *   `:at_most_one` At most one flag in the group must be provided
    #
    # @param [Symbol] type The type of group. Default is `:optional`.
    # @param [String,Array<String>,Toys::WrappableString] desc Short
    #     description for the group. See {Toys::Tool#desc=} for a description
    #     of allowed formats. Defaults to `"Flags"`.
    # @param [Array<String,Array<String>,Toys::WrappableString>] long_desc
    #     Long description for the flag group. See {Toys::Tool#long_desc=} for
    #     a description of allowed formats. Defaults to the empty array.
    # @param [String,Symbol,nil] name The name of the group, or nil for no
    #     name.
    # @return [Toys::FlagGroup::Base] A flag group of the correct subclass.
    #
    def self.create(type: nil, name: nil, desc: nil, long_desc: nil)
      type ||= Optional
      unless type.is_a?(::Class)
        class_name = ModuleLookup.to_module_name(type)
        type =
          begin
            FlagGroup.const_get(class_name)
          rescue ::NameError
            raise ToolDefinitionError, "Unknown flag group type: #{type}"
          end
      end
      unless type.ancestors.include?(Base)
        raise ToolDefinitionError, "Unknown flag group type: #{type}"
      end
      type.new(name, desc, long_desc)
    end

    ##
    # The base class of a FlagGroup, implementing everything except validation.
    # The base class effectively behaves as an Optional group. However, you
    # should use {Toys::FlagGroup::Optional} to represent such a group.
    #
    class Base
      ##
      # Create a flag group.
      # This argument list is subject to change. Use {Toys::FlagGroup.create}
      # instead for a more stable interface.
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
            str = "Flag \"#{flag.display_name}\" is required."
            results << ArgParser::FlagGroupConstraintError.new(str)
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
          str = "Exactly one flag out of group \"#{desc}\" is required, but #{seen_names.size}" \
                " were provided: #{seen_names.inspect}."
          [ArgParser::FlagGroupConstraintError.new(str)]
        elsif seen_names.empty?
          str = "Exactly one flag out of group \"#{desc}\" is required, but none were provided."
          [ArgParser::FlagGroupConstraintError.new(str)]
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
          str = "At most one flag out of group \"#{desc}\" is required, but #{seen_names.size}" \
                " were provided: #{seen_names.inspect}."
          [ArgParser::FlagGroupConstraintError.new(str)]
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
        str = "At least one flag out of group \"#{desc}\" is required, but none were provided."
        [ArgParser::FlagGroupConstraintError.new(str)]
      end

      ## @private
      def default_long_desc
        "At least one of these flags must be set."
      end
    end
  end
end
