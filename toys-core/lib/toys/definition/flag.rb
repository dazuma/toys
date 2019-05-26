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
  module Definition
    ##
    # Representation of a single flag.
    #
    class FlagSyntax
      ##
      # Parse flag syntax
      # @param [String] str syntax.
      #
      def initialize(str)
        case str
        when /^(-([\?\w]))$/
          setup(str, $1, nil, $1, $2, "-", nil, nil, nil, nil)
        when /^(-([\?\w]))( ?)\[(\w+)\]$/
          setup(str, $1, nil, $1, $2, "-", :value, :optional, $3, $4)
        when /^(-([\?\w]))\[( )(\w+)\]$/
          setup(str, $1, nil, $1, $2, "-", :value, :optional, $3, $4)
        when /^(-([\?\w]))( ?)(\w+)$/
          setup(str, $1, nil, $1, $2, "-", :value, :required, $3, $4)
        when /^--\[no-\](\w[\?\w-]*)$/
          setup(str, "--#{$1}", "--no-#{$1}", str, $1, "--", :boolean, nil, nil, nil)
        when /^(--(\w[\?\w-]*))$/
          setup(str, $1, nil, $1, $2, "--", nil, nil, nil, nil)
        when /^(--(\w[\?\w-]*))([= ])\[(\w+)\]$/
          setup(str, $1, nil, $1, $2, "--", :value, :optional, $3, $4)
        when /^(--(\w[\?\w-]*))\[([= ])(\w+)\]$/
          setup(str, $1, nil, $1, $2, "--", :value, :optional, $3, $4)
        when /^(--(\w[\?\w-]*))([= ])(\w+)$/
          setup(str, $1, nil, $1, $2, "--", :value, :required, $3, $4)
        else
          raise ToolDefinitionError, "Illegal flag: #{str.inspect}"
        end
      end

      attr_reader :original_str
      attr_reader :flags
      attr_reader :positive_flag
      attr_reader :negative_flag
      attr_reader :str_without_value
      attr_reader :sort_str
      attr_reader :flag_style
      attr_reader :flag_type
      attr_reader :value_type
      attr_reader :value_delim
      attr_reader :value_label
      attr_reader :canonical_str

      ## @private
      def configure_canonical(canonical_flag_type, canonical_value_type,
                              canonical_value_label, canonical_value_delim)
        return unless flag_type.nil?
        @flag_type = canonical_flag_type
        return unless canonical_flag_type == :value
        @value_type = canonical_value_type
        canonical_value_delim = "" if canonical_value_delim == "=" && flag_style == "-"
        canonical_value_delim = "=" if canonical_value_delim == "" && flag_style == "--"
        @value_delim = canonical_value_delim
        @value_label = canonical_value_label
        label = @value_type == :optional ? "[#{@value_label}]" : @value_label
        @canonical_str = "#{str_without_value}#{@value_delim}#{label}"
      end

      private

      def setup(original_str, positive_flag, negative_flag, str_without_value, sort_str,
                flag_style, flag_type, value_type, value_delim, value_label)
        @original_str = original_str
        @positive_flag = positive_flag
        @negative_flag = negative_flag
        @flags = [positive_flag]
        @flags << negative_flag if negative_flag
        @str_without_value = str_without_value
        @sort_str = sort_str
        @flag_style = flag_style
        @flag_type = flag_type
        @value_type = value_type
        @value_delim = value_delim
        @value_label = value_label ? value_label.upcase : value_label
        @canonical_str = original_str
      end
    end

    ##
    # Representation of a formal set of flags that set a particular context
    # key. The flags within a single Flag definition are synonyms.
    #
    class Flag
      ##
      # The set handler replaces the previous value.
      # @return [Proc]
      #
      SET_HANDLER = ->(val, _prev) { val }

      ##
      # The push handler pushes the given value using the `<<` operator.
      # @return [Proc]
      #
      PUSH_HANDLER = ->(val, prev) { prev.nil? ? [val] : prev << val }

      ##
      # The default handler is the set handler, replacing the previous value.
      # @return [Proc]
      #
      DEFAULT_HANDLER = SET_HANDLER

      ##
      # Create a Flag definition.
      # Should be created only from {Toys::Definition::Tool#add_flag}.
      # @private
      #
      def initialize(key, flags, used_flags, report_collisions, acceptor, handler,
                     default, completion, display_name, group)
        @group = group
        @key = key
        @flag_syntax = flags.map { |s| FlagSyntax.new(s) }
        @acceptor = acceptor
        @handler = resolve_handler(handler)
        @desc = WrappableString.make(desc)
        @long_desc = WrappableString.make_array(long_desc)
        @default = default
        @completion = completion
        needs_val =
          @flag_syntax.empty? &&
          ((!acceptor.nil? && acceptor.name != ::TrueClass && acceptor.name != ::FalseClass) ||
           (!default.nil? && default != true && default != false))
        create_default_flag_if_needed(needs_val)
        remove_used_flags(used_flags, report_collisions)
        canonicalize(needs_val)
        summarize(display_name)
      end

      ##
      # Returns the flag group containing this flag
      # @return [Toys::Definition::FlagGroup]
      #
      attr_reader :group

      ##
      # Returns the key.
      # @return [Symbol]
      #
      attr_reader :key

      ##
      # Returns an array of FlagSyntax for the flags.
      # @return [Array<FlagSyntax>]
      #
      attr_reader :flag_syntax

      ##
      # Returns the acceptor, which may be `nil`.
      # @return [Tool::Definition::Acceptor]
      #
      attr_reader :acceptor

      ##
      # Returns the default value, which may be `nil`.
      # @return [Object]
      #
      attr_reader :default

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
      # Returns the handler for setting/updating the value.
      # @return [Proc]
      #
      attr_reader :handler

      ##
      # Returns the proc that determines shell completions for the value.
      # @return [Toys::Definition::Completion]
      #
      attr_reader :completion

      ##
      # The type of flag. Possible values are `:boolean` for a simple boolean
      # switch, or `:value` for a flag that sets a value.
      # @return [:boolean,:value]
      #
      attr_reader :flag_type

      ##
      # The type of value. Set to `:required` or `:optional` if the flag type
      # is `:value`. Otherwise set to `nil`.
      # @return [:required,:optional,nil]
      #
      attr_reader :value_type

      ##
      # The string label for the value as it should display in help, or `nil`
      # if the flag type is not `:value`.
      # @return [String,nil]
      #
      attr_reader :value_label

      ##
      # The value delimiter, which may be `""`, `" "`, or `"="`. Set to `nil`
      # if the flag type is not `:value`.
      # @return [String,nil]
      #
      attr_reader :value_delim

      ##
      # Returns the display name of this flag.
      # @return [String]
      #
      attr_reader :display_name

      ##
      # Returns a string that can be used to sort this flag
      # @return [String]
      #
      attr_reader :sort_str

      ##
      # Returns an array of FlagSyntax including only single-dash flags
      # @return [Array<FlagSyntax>]
      #
      def single_flag_syntax
        @single_flag_syntax ||= flag_syntax.find_all { |ss| ss.flag_style == "-" }
      end

      ##
      # Returns an array of FlagSyntax including only double-dash flags
      # @return [Array<FlagSyntax>]
      #
      def double_flag_syntax
        @double_flag_syntax ||= flag_syntax.find_all { |ss| ss.flag_style == "--" }
      end

      ##
      # Returns the list of all effective flags used.
      # @return [Array<String>]
      #
      def effective_flags
        @effective_flags ||= flag_syntax.map(&:flags).flatten
      end

      ##
      # Look up the flag by string. Returns an object that indicates whether
      # the given string matched this flag, whether the match was unique, and
      # other pertinent information.
      #
      # @param [String] str Flag string to look up
      # @return [Toys::Definition::FlagResolution] Information about the match.
      #
      def resolve(str)
        resolution = FlagResolution.new(str)
        flag_syntax.each do |fs|
          if fs.positive_flag == str
            resolution.add!(self, fs, false, true)
          elsif fs.negative_flag == str
            resolution.add!(self, fs, true, true)
          elsif fs.positive_flag.start_with?(str)
            resolution.add!(self, fs, false, false)
          elsif fs.negative_flag.to_s.start_with?(str)
            resolution.add!(self, fs, true, false)
          end
        end
        resolution
      end

      ##
      # Returns a list of canonical flag syntax strings.
      # @return [Array]
      #
      def canonical_syntax_strings
        @canonical_syntax_strings ||= flag_syntax.map(&:canonical_str)
      end

      ##
      # Returns true if this flag is active. That is, it has a nonempty
      # flags list.
      # @return [Boolean]
      #
      def active?
        !effective_flags.empty?
      end

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

      private

      def resolve_handler(handler)
        case handler
        when ::Proc
          handler
        when nil, :default
          DEFAULT_HANDLER
        when :set
          SET_HANDLER
        when :push, :append
          PUSH_HANDLER
        else
          raise ToolDefinitionError, "Unknown handler: #{handler.inspect}"
        end
      end

      def create_default_flag_if_needed(needs_val)
        return unless @flag_syntax.empty?
        canonical_flag = key.to_s.downcase.tr("_", "-").gsub(/[^a-z0-9-]/, "").sub(/^-+/, "")
        unless canonical_flag.empty?
          flag = needs_val ? "--#{canonical_flag} VALUE" : "--#{canonical_flag}"
          @flag_syntax << FlagSyntax.new(flag)
        end
      end

      def remove_used_flags(used_flags, report_collisions)
        @flag_syntax.select! do |fs|
          fs.flags.all? do |f|
            collision = used_flags.include?(f)
            if collision && report_collisions
              raise ToolDefinitionError,
                    "Cannot use flag #{f.inspect} because it is already assigned or reserved."
            end
            !collision
          end
        end
        used_flags.concat(effective_flags.uniq)
      end

      def canonicalize(needs_val)
        @flag_type = needs_val ? :value : nil
        @value_type = nil
        @value_label = needs_val ? "VALUE" : nil
        @value_delim = " "
        single_flag_syntax.reverse_each do |flag|
          analyze_flag_syntax(flag)
        end
        double_flag_syntax.reverse_each do |flag|
          analyze_flag_syntax(flag)
        end
        @flag_type ||= :boolean
        @value_type ||= :required if @flag_type == :value
        flag_syntax.each do |flag|
          flag.configure_canonical(@flag_type, @value_type, @value_label, @value_delim)
        end
      end

      def analyze_flag_syntax(flag)
        return if flag.flag_type.nil?
        if !@flag_type.nil? && @flag_type != flag.flag_type
          raise ToolDefinitionError, "Cannot have both value and boolean flags for #{key.inspect}"
        end
        @flag_type = flag.flag_type
        return unless @flag_type == :value
        if !@value_type.nil? && @value_type != flag.value_type
          raise ToolDefinitionError,
                "Cannot have both required and optional values for flag #{key.inspect}"
        end
        @value_type = flag.value_type
        @value_label = flag.value_label
        @value_delim = flag.value_delim
      end

      def summarize(name)
        @display_name =
          name ||
          double_flag_syntax.first&.canonical_str ||
          single_flag_syntax.first&.canonical_str ||
          key.to_s
        @sort_str =
          double_flag_syntax.first&.sort_str ||
          single_flag_syntax.first&.sort_str ||
          ""
      end
    end

    ##
    # The result of looking up a flag by name.
    #
    class FlagResolution
      ## @private
      def initialize(str)
        @string = str
        @flags = []
        @found_exact = false
      end

      ##
      # The flag string that was looked up
      # @return [String]
      #
      attr_reader :string

      ##
      # Whether an exact match of the string was found
      # @return [Boolean]
      #
      attr_reader :found_exact
      alias found_exact? found_exact

      ##
      # The number of matches that were found.
      # @return [Integer]
      #
      def count
        @flags.size
      end

      ##
      # Whether a single unique match was found.
      # @return [Boolean]
      #
      def found_unique?
        @flags.size == 1
      end

      ##
      # Whether no matches were found.
      # @return [Boolean]
      #
      def not_found?
        @flags.empty?
      end

      ##
      # Whether multiple matches were found (i.e. ambiguous input).
      # @return [Boolean]
      #
      def found_multiple?
        @flags.size > 1
      end

      ##
      # Return the unique {Toys::Definition::Flag}, or `nil` if not found or
      # not unique.
      # @return [Toys::Definition::Flag,nil]
      #
      def unique_flag
        found_unique? ? @flags.first[0] : nil
      end

      ##
      # Return the unique {Toys::Definition::FlagSyntax}, or `nil` if not found
      # or not unique.
      # @return [Toys::Definition::FlagSyntax,nil]
      #
      def unique_flag_syntax
        found_unique? ? @flags.first[1] : nil
      end

      ##
      # Return whether the unique match was a hit on the negative (`--no-*`)
      # case, or `nil` if not found or not unique.
      # @return [Boolean,nil]
      #
      def unique_flag_negative?
        found_unique? ? @flags.first[2] : nil
      end

      ## @private
      def add!(flag, flag_syntax, negative, exact)
        @flags = [] if exact && !found_exact?
        if exact || !found_exact?
          @flags << [flag, flag_syntax, negative]
          @found_exact = exact
        end
        self
      end

      ## @private
      def merge!(other)
        raise "String mismatch" unless string == other.string
        other.instance_variable_get(:@flags).each do |flag, flag_syntax, negative|
          add!(flag, flag_syntax, negative, other.found_exact?)
        end
        self
      end
    end
  end
end
