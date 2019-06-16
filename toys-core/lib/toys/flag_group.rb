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
    # @param type [Symbol] The type of group. Default is `:optional`.
    # @param desc [String,Array<String>,Toys::WrappableString] Short
    #     description for the group. See {Toys::Tool#desc=} for a description
    #     of allowed formats. Defaults to `"Flags"`.
    # @param long_desc [Array<String,Array<String>,Toys::WrappableString>]
    #     Long description for the flag group. See {Toys::Tool#long_desc=} for
    #     a description of allowed formats. Defaults to the empty array.
    # @param name [String,Symbol,nil] The name of the group, or nil for no
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
        @desc = WrappableString.make(desc)
        @long_desc = WrappableString.make_array(long_desc)
        @flags = []
      end

      ##
      # The symbolic name for this group
      # @return [String,Symbol,nil]
      #
      attr_reader :name

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
      # When setting, the description must be provided as an Array where *each
      # element* may be any of the following:
      # *   A {Toys::WrappableString} representing one line.
      # *   A normal String representing a line. This will be transformed into
      #     a {Toys::WrappableString} using spaces as word delimiters.
      # *   An Array of String representing a line. This will be transformed
      #     into a {Toys::WrappableString} where each array element represents
      #     an individual word for wrapping.
      #
      # @return [Array<Toys::WrappableString>]
      #
      attr_reader :long_desc

      ##
      # An array of flags that are in this group.
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

      ##
      # Returns a string summarizing this group. This is generally either the
      # short description or a representation of all the flags included.
      # @return [String]
      #
      def summary
        return desc.to_s.inspect unless desc.empty?
        flags.map(&:display_name).inspect
      end

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

      ## @private
      def <<(flag)
        flags << flag
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
          str = "Exactly one flag out of group #{summary} is required, but #{seen_names.size}" \
                " were provided: #{seen_names.inspect}."
          [ArgParser::FlagGroupConstraintError.new(str)]
        elsif seen_names.empty?
          str = "Exactly one flag out of group #{summary} is required, but none were provided."
          [ArgParser::FlagGroupConstraintError.new(str)]
        else
          []
        end
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
          str = "At most one flag out of group #{summary} is required, but #{seen_names.size}" \
                " were provided: #{seen_names.inspect}."
          [ArgParser::FlagGroupConstraintError.new(str)]
        else
          []
        end
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
        str = "At least one flag out of group #{summary} is required, but none were provided."
        [ArgParser::FlagGroupConstraintError.new(str)]
      end
    end
  end
end
