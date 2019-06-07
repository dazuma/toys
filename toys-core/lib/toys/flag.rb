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
    # This argument list is subject to change. Use {Toys::Flag.create} instead
    # for a more stable interface.
    # @private
    #
    def initialize(key, flags, used_flags, report_collisions, acceptor, handler, default,
                   flag_completion, value_completion, desc, long_desc, display_name, group)
      @group = group
      @key = key
      @flag_syntax = Array(flags).map { |s| Syntax.new(s) }
      @acceptor = Acceptor.create(acceptor)
      @handler = resolve_handler(handler)
      @desc = WrappableString.make(desc)
      @long_desc = WrappableString.make_array(long_desc)
      @default = default
      @flag_completion = create_flag_completion(flag_completion)
      @value_completion = Completion.create(value_completion)
      create_default_flag if @flag_syntax.empty?
      remove_used_flags(used_flags, report_collisions)
      canonicalize
      summarize(display_name)
    end

    ##
    # Create a flag definition.
    #
    # @param [String,Symbol] key The key to use to retrieve the value from
    #     the execution context.
    # @param [Array<String>] flags The flags in OptionParser format. If empty,
    #     a flag will be inferred from the key.
    # @param [Object] accept An acceptor that validates and/or converts the
    #     value. See {Toys::Acceptor.create} for recognized formats. Optional.
    #     If not specified, defaults to {Toys::Acceptor::DEFAULT}.
    # @param [Object] default The default value. This is the value that will
    #     be set in the context if this flag is not provided on the command
    #     line. Defaults to `nil`.
    # @param [Proc,nil,:set,:push] handler An optional handler for
    #     setting/updating the value. A handler is a proc taking two
    #     arguments, the given value and the previous value, returning the
    #     new value that should be set. You may also specify a predefined
    #     named handler. The `:set` handler (the default) replaces the
    #     previous value (effectively `-> (val, _prev) { val }`). The
    #     `:push` handler expects the previous value to be an array and
    #     pushes the given value onto it; it should be combined with setting
    #     `default: []` and is intended for "multi-valued" flags.
    # @param [Object] complete_flags A specifier for shell tab completion for
    #     flag names associated with this flag. By default, a
    #     {Toys::Flag::StandardCompletion} is used, which provides the flag's
    #     names as completion candidates. To customize completion, set this to
    #     a hash of options to pass to the constructor for
    #     {Toys::Flag::StandardCompletion}, or pass any other spec recognized
    #     by {Toys::Completion.create}.
    # @param [Object] complete_values A specifier for shell tab completion for
    #     flag values associated with this flag. Pass any spec recognized by
    #     {Toys::Completion.create}.
    # @param [Boolean] report_collisions Raise an exception if a flag is
    #     requested that is already in use or marked as disabled. Default is
    #     true.
    # @param [Toys::FlagGroup] group Group containing this flag.
    # @param [String,Array<String>,Toys::WrappableString] desc Short
    #     description for the flag. See {Toys::Tool#desc=} for a description of
    #     allowed formats. Defaults to the empty string.
    # @param [Array<String,Array<String>,Toys::WrappableString>] long_desc
    #     Long description for the flag. See {Toys::Tool#long_desc=} for a
    #     description of allowed formats. Defaults to the empty array.
    # @param [String] display_name A display name for this flag, used in help
    #     text and error messages.
    # @param [Array<String>] used_flags An array of flags already in use.
    #
    def self.create(key, flags = [],
                    used_flags: nil, report_collisions: true, accept: nil, handler: nil,
                    default: nil, complete_flags: nil, complete_values: nil, display_name: nil,
                    desc: nil, long_desc: nil, group: nil)
      new(key, flags, used_flags, report_collisions, accept, handler, default, complete_flags,
          complete_values, desc, long_desc, display_name, group)
    end

    ##
    # Returns the flag group containing this flag
    # @return [Toys::FlagGroup]
    #
    attr_reader :group

    ##
    # Returns the key.
    # @return [Symbol]
    #
    attr_reader :key

    ##
    # Returns an array of Flag::Syntax for the flags.
    # @return [Array<Flag::Syntax>]
    #
    attr_reader :flag_syntax

    ##
    # Returns the effective acceptor.
    # @return [Tool::Acceptor::Base]
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
    # Returns the proc that determines shell completions for the flag.
    # @return [Proc,Toys::Completion::Base]
    #
    attr_reader :flag_completion

    ##
    # Returns the proc that determines shell completions for the value.
    # @return [Proc,Toys::Completion::Base]
    #
    attr_reader :value_completion

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
    # Returns an array of Flag::Syntax including only short (single dash) flags
    # @return [Array<Flag::Syntax>]
    #
    def short_flag_syntax
      @short_flag_syntax ||= flag_syntax.find_all { |ss| ss.flag_style == :short }
    end

    ##
    # Returns an array of Flag::Syntax including only long (double-dash) flags
    # @return [Array<Flag::Syntax>]
    #
    def long_flag_syntax
      @long_flag_syntax ||= flag_syntax.find_all { |ss| ss.flag_style == :long }
    end

    ##
    # Returns the list of all effective flags used.
    # @return [Array<String>]
    #
    def effective_flags
      @effective_flags ||= flag_syntax.flat_map(&:flags)
    end

    ##
    # Look up the flag by string. Returns an object that indicates whether
    # the given string matched this flag, whether the match was unique, and
    # other pertinent information.
    #
    # @param [String] str Flag string to look up
    # @return [Toys::Flag::Resolution] Information about the match.
    #
    def resolve(str)
      resolution = Resolution.new(str)
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

    def create_flag_completion(spec)
      case spec
      when nil, :default
        StandardCompletion.new(self)
      when ::Hash
        StandardCompletion.new(self, spec)
      else
        Completion.create(spec)
      end
    end

    def create_default_flag
      canonical_flag = key.to_s.downcase.tr("_", "-").gsub(/[^a-z0-9-]/, "").sub(/^-+/, "")
      unless canonical_flag.empty?
        flag_str =
          if canonical_flag.length == 1
            "-#{canonical_flag}"
          else
            "--#{canonical_flag}"
          end
        needs_val = @value_completion != Completion::EMPTY ||
                    ![::NilClass, ::TrueClass, ::FalseClass].include?(@acceptor.well_known_spec) ||
                    ![nil, true, false].include?(@default)
        flag_str = "#{flag_str} VALUE" if needs_val
        @flag_syntax << Syntax.new(flag_str)
      end
    end

    def remove_used_flags(used_flags, report_collisions)
      return if !used_flags && !report_collisions
      @flag_syntax.select! do |fs|
        fs.flags.all? do |f|
          collision = used_flags&.include?(f)
          if collision && report_collisions
            raise ToolDefinitionError,
                  "Cannot use flag #{f.inspect} because it is already assigned or reserved."
          end
          !collision
        end
      end
      used_flags&.concat(effective_flags.uniq)
    end

    def canonicalize
      @flag_type = nil
      @value_type = nil
      @value_label = nil
      @value_delim = " "
      short_flag_syntax.reverse_each do |flag|
        analyze_flag_syntax(flag)
      end
      long_flag_syntax.reverse_each do |flag|
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
        long_flag_syntax.first&.canonical_str ||
        short_flag_syntax.first&.canonical_str ||
        key.to_s
      @sort_str =
        long_flag_syntax.first&.sort_str ||
        short_flag_syntax.first&.sort_str ||
        ""
    end

    ##
    # Representation of a single flag.
    #
    class Syntax
      # rubocop:disable Style/PerlBackrefs

      ##
      # Parse flag syntax
      # @param [String] str syntax.
      #
      def initialize(str)
        case str
        when /\A(-([\?\w]))\z/
          setup(str, $1, nil, $1, $2, :short, nil, nil, nil, nil)
        when /\A(-([\?\w]))( ?)\[(\w+)\]\z/
          setup(str, $1, nil, $1, $2, :short, :value, :optional, $3, $4)
        when /\A(-([\?\w]))\[( )(\w+)\]\z/
          setup(str, $1, nil, $1, $2, :short, :value, :optional, $3, $4)
        when /\A(-([\?\w]))( ?)(\w+)\z/
          setup(str, $1, nil, $1, $2, :short, :value, :required, $3, $4)
        when /\A--\[no-\](\w[\?\w-]*)\z/
          setup(str, "--#{$1}", "--no-#{$1}", str, $1, :long, :boolean, nil, nil, nil)
        when /\A(--(\w[\?\w-]*))\z/
          setup(str, $1, nil, $1, $2, :long, nil, nil, nil, nil)
        when /\A(--(\w[\?\w-]*))([= ])\[(\w+)\]\z/
          setup(str, $1, nil, $1, $2, :long, :value, :optional, $3, $4)
        when /\A(--(\w[\?\w-]*))\[([= ])(\w+)\]\z/
          setup(str, $1, nil, $1, $2, :long, :value, :optional, $3, $4)
        when /\A(--(\w[\?\w-]*))([= ])(\w+)\z/
          setup(str, $1, nil, $1, $2, :long, :value, :required, $3, $4)
        else
          raise ToolDefinitionError, "Illegal flag: #{str.inspect}"
        end
      end

      # rubocop:enable Style/PerlBackrefs

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
        canonical_value_delim = "" if canonical_value_delim == "=" && flag_style == :short
        canonical_value_delim = "=" if canonical_value_delim == "" && flag_style == :long
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
    # The result of looking up a flag by name.
    #
    class Resolution
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
      # Return the unique {Toys::Flag}, or `nil` if not found or
      # not unique.
      # @return [Toys::Flag,nil]
      #
      def unique_flag
        found_unique? ? @flags.first[0] : nil
      end

      ##
      # Return the unique {Toys::Flag::Syntax}, or `nil` if not found
      # or not unique.
      # @return [Toys::Flag::Syntax,nil]
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

      ##
      # Returns an array of the matching full flag strings.
      # @return [Array<String>]
      #
      def matching_flag_strings
        @flags.map do |_flag, flag_syntax, negative|
          negative ? flag_syntax.negative_flag : flag_syntax.positive_flag
        end
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

    ##
    # A Completion that returns all possible flags associated with a
    # {Toys::Flag}.
    #
    class StandardCompletion < Completion::Base
      ##
      # Create a completion given configuration options.
      #
      # @param [Toys::Flag] flag The flag definition.
      # @param [Boolean] include_short Whether to include short flags.
      # @param [Boolean] include_long Whether to include long flags.
      # @param [Boolean] include_negative Whether to include `--no-*` forms.
      #
      def initialize(flag, include_short: true, include_long: true, include_negative: true)
        @flag = flag
        @include_short = include_short
        @include_long = include_long
        @include_negative = include_negative
      end

      ##
      # Whether to include short flags
      # @return [Boolean]
      #
      attr_reader :include_short
      alias include_short? include_short

      ##
      # Whether to include long flags
      # @return [Boolean]
      #
      attr_reader :include_long
      alias include_long? include_long

      ##
      # Whether to include negative long flags
      # @return [Boolean]
      #
      attr_reader :include_negative
      alias include_negative? include_negative

      ##
      # Returns candidates for the current completion.
      #
      # @param [Toys::Completion::Context] context the current completion
      #     context including the string fragment.
      # @return [Array<Toys::Completion::Candidate>] an array of candidates
      #
      def call(context)
        results =
          if @include_short && @include_long && @include_negative
            @flag.effective_flags
          else
            collect_results
          end
        fragment = context.fragment
        results.find_all { |val| val.start_with?(fragment) }
               .map { |str| Completion::Candidate.new(str) }
      end

      private

      def collect_results
        results = []
        if @include_short
          results += @flag.short_flag_syntax.map(&:positive_flag)
        end
        if @include_long
          results +=
            if @include_negative
              @flag.long_flag_syntax.flat_map(&:flags)
            else
              @flag.long_flag_syntax.map(&:positive_flag)
            end
        end
        results
      end
    end
  end
end
