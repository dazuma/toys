# frozen_string_literal: true

module Toys
  ##
  # Representation of a formal set of flags that set a particular context
  # key. The flags within a single Flag definition are synonyms.
  #
  class Flag
    ##
    # Representation of a single flag.
    #
    class Syntax
      # rubocop:disable Style/PerlBackrefs

      ##
      # Parse flag syntax
      # @param str [String] syntax.
      #
      def initialize(str)
        case str
        when /\A(-([?\w]))\z/
          setup(str, $1, nil, $1, $2, :short, nil, nil, nil, nil)
        when /\A(-([?\w]))(?:( ?)\[|\[( ))(\w+)\]\z/
          setup(str, $1, nil, $1, $2, :short, :value, :optional, $3 || $4, $5)
        when /\A(-([?\w]))( ?)(\w+)\z/
          setup(str, $1, nil, $1, $2, :short, :value, :required, $3, $4)
        when /\A--\[no-\](\w[?\w-]*)\z/
          setup(str, "--#{$1}", "--no-#{$1}", str, $1, :long, :boolean, nil, nil, nil)
        when /\A(--(\w[?\w-]*))\z/
          setup(str, $1, nil, $1, $2, :long, nil, nil, nil, nil)
        when /\A(--(\w[?\w-]*))(?:([= ])\[|\[([= ]))(\w+)\]\z/
          setup(str, $1, nil, $1, $2, :long, :value, :optional, $3 || $4, $5)
        when /\A(--(\w[?\w-]*))([= ])(\w+)\z/
          setup(str, $1, nil, $1, $2, :long, :value, :required, $3, $4)
        else
          raise ToolDefinitionError, "Illegal flag: #{str.inspect}"
        end
      end

      # rubocop:enable Style/PerlBackrefs

      ##
      # The original string that was parsed to produce this syntax.
      # @return [String]
      #
      attr_reader :original_str

      ##
      # The flags (without values) corresponding to this syntax.
      # @return [Array<String>]
      #
      attr_reader :flags

      ##
      # The flag (without values) corresponding to the normal "positive" form
      # of this flag.
      # @return [String]
      #
      attr_reader :positive_flag

      ##
      # The flag (without values) corresponding to the "negative" form of this
      # flag, if any. i.e. if the original string was `"--[no-]abc"`, the
      # negative flag is `"--no-abc"`.
      # @return [String] The negative form.
      # @return [nil] if the flag has no negative form.
      #
      attr_reader :negative_flag

      ##
      # The original string with the value (if any) stripped, but retaining
      # the `[no-]` prefix if present.
      # @return [String]
      #
      attr_reader :str_without_value

      ##
      # A string used to sort this flag compared with others.
      # @return [String]
      #
      attr_reader :sort_str

      ##
      # The style of flag (`:long` or `:short`).
      # @return [:long] if this is a long flag (i.e. double hyphen)
      # @return [:short] if this is a short flag (i.e. single hyphen with one
      #     character).
      #
      attr_reader :flag_style

      ##
      # The type of flag (`:boolean` or `:value`)
      # @return [:boolean] if this is a boolean flag (i.e. no value)
      # @return [:value] if this flag takes a value (even if optional)
      # @return [nil] if this flag is indeterminate
      #
      attr_reader :flag_type

      ##
      # The type of value (`:required` or `:optional`)
      # @return [:required] if this flag takes a required value
      # @return [:optional] if this flag takes an optional value
      # @return [nil] if this flag is a boolean flag
      #
      attr_reader :value_type

      ##
      # The default delimiter used for the value of this flag. This could be
      # `""` or `" "` for a short flag, or `" "` or `"="` for a long flag.
      # @return [String] delimiter
      # @return [nil] if this flag is a boolean flag
      #
      attr_reader :value_delim

      ##
      # The default "label" for the value. e.g. in `--abc=VAL` the label is
      # `"VAL"`.
      # @return [String] the label
      # @return [nil] if this flag is a boolean flag
      #
      attr_reader :value_label

      ##
      # A canonical string representing this flag's syntax, normalized to match
      # the type, delimiters, etc. settings of other flag syntaxes. This is
      # generally used in help strings to represent this flag.
      # @return [String]
      #
      attr_reader :canonical_str

      ##
      # This method is accessible for testing only.
      #
      # @private This interface is internal and subject to change without warning.
      #
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
      ##
      # @private
      #
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
      def found_exact?
        @found_exact
      end

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

      ##
      # @private
      #
      def add!(flag, flag_syntax, negative, exact)
        @flags = [] if exact && !found_exact?
        if exact || !found_exact?
          @flags << [flag, flag_syntax, negative]
          @found_exact = exact
        end
        self
      end

      ##
      # @private
      #
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
    class DefaultCompletion < Completion::Base
      ##
      # Create a completion given configuration options.
      #
      # @param flag [Toys::Flag] The flag definition.
      # @param include_short [Boolean] Whether to include short flags.
      # @param include_long [Boolean] Whether to include long flags.
      # @param include_negative [Boolean] Whether to include `--no-*` forms.
      #
      def initialize(flag:, include_short: true, include_long: true, include_negative: true)
        super()
        @flag = flag
        @include_short = include_short
        @include_long = include_long
        @include_negative = include_negative
      end

      ##
      # Whether to include short flags
      # @return [Boolean]
      #
      def include_short?
        @include_short
      end

      ##
      # Whether to include long flags
      # @return [Boolean]
      #
      def include_long?
        @include_long
      end

      ##
      # Whether to include negative long flags
      # @return [Boolean]
      #
      def include_negative?
        @include_negative
      end

      ##
      # Returns candidates for the current completion.
      #
      # @param context [Toys::Completion::Context] the current completion
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
    # Create a flag definition.
    #
    # @param key [String,Symbol] The key to use to retrieve the value from
    #     the execution context.
    # @param flags [Array<String>] The flags in OptionParser format. If empty,
    #     a flag will be inferred from the key.
    # @param accept [Object] An acceptor that validates and/or converts the
    #     value. See {Toys::Acceptor.create} for recognized formats. Optional.
    #     If not specified, defaults to {Toys::Acceptor::DEFAULT}.
    # @param default [Object] The default value. This is the value that will
    #     be set in the context if this flag is not provided on the command
    #     line. Defaults to `nil`.
    # @param handler [Proc,nil,:set,:push] An optional handler for
    #     setting/updating the value. A handler is a proc taking two
    #     arguments, the given value and the previous value, returning the
    #     new value that should be set. You may also specify a predefined
    #     named handler. The `:set` handler (the default) replaces the
    #     previous value (effectively `-> (val, _prev) { val }`). The
    #     `:push` handler expects the previous value to be an array and
    #     pushes the given value onto it; it should be combined with setting
    #     `default: []` and is intended for "multi-valued" flags.
    # @param complete_flags [Object] A specifier for shell tab completion for
    #     flag names associated with this flag. By default, a
    #     {Toys::Flag::DefaultCompletion} is used, which provides the flag's
    #     names as completion candidates. To customize completion, set this to
    #     a hash of options to pass to the constructor for
    #     {Toys::Flag::DefaultCompletion}, or pass any other spec recognized
    #     by {Toys::Completion.create}.
    # @param complete_values [Object] A specifier for shell tab completion for
    #     flag values associated with this flag. Pass any spec recognized by
    #     {Toys::Completion.create}.
    # @param report_collisions [Boolean] Raise an exception if a flag is
    #     requested that is already in use or marked as disabled. Default is
    #     true.
    # @param group [Toys::FlagGroup] Group containing this flag.
    # @param desc [String,Array<String>,Toys::WrappableString] Short
    #     description for the flag. See {Toys::ToolDefinition#desc} for a
    #     description of allowed formats. Defaults to the empty string.
    # @param long_desc [Array<String,Array<String>,Toys::WrappableString>]
    #     Long description for the flag. See {Toys::ToolDefinition#long_desc}
    #     for a description of allowed formats. Defaults to the empty array.
    # @param display_name [String] A display name for this flag, used in help
    #     text and error messages.
    # @param used_flags [Array<String>] An array of flags already in use.
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
    # @return [Array<Toys::Flag::Syntax>]
    #
    attr_reader :flag_syntax

    ##
    # Returns the effective acceptor.
    # @return [Toys::Acceptor::Base]
    #
    attr_reader :acceptor

    ##
    # Returns the default value, which may be `nil`.
    # @return [Object]
    #
    attr_reader :default

    ##
    # The short description string.
    #
    # When reading, this is always returned as a {Toys::WrappableString}.
    #
    # When setting, the description may be provided as any of the following:
    #  *  A {Toys::WrappableString}.
    #  *  A normal String, which will be transformed into a
    #     {Toys::WrappableString} using spaces as word delimiters.
    #  *  An Array of String, which will be transformed into a
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
    #  *  A {Toys::WrappableString} representing one line.
    #  *  A normal String representing a line. This will be transformed into a
    #     {Toys::WrappableString} using spaces as word delimiters.
    #  *  An Array of String representing a line. This will be transformed into
    #     a {Toys::WrappableString} where each array element represents an
    #     individual word for wrapping.
    #
    # @return [Array<Toys::WrappableString>]
    #
    attr_reader :long_desc

    ##
    # The handler for setting/updating the value.
    # @return [Proc]
    #
    attr_reader :handler

    ##
    # The proc that determines shell completions for the flag.
    # @return [Proc,Toys::Completion::Base]
    #
    attr_reader :flag_completion

    ##
    # The proc that determines shell completions for the value.
    # @return [Proc,Toys::Completion::Base]
    #
    attr_reader :value_completion

    ##
    # The type of flag.
    #
    # @return [:boolean] if the flag is a simple boolean switch
    # @return [:value] if the flag sets a value
    #
    attr_reader :flag_type

    ##
    # The type of value.
    #
    # @return [:required] if the flag type is `:value` and the value is
    #     required.
    # @return [:optional] if the flag type is `:value` and the value is
    #     optional.
    # @return [nil] if the flag type is not `:value`.
    #
    attr_reader :value_type

    ##
    # The string label for the value as it should display in help.
    # @return [String] The label
    # @return [nil] if the flag type is not `:value`.
    #
    attr_reader :value_label

    ##
    # The value delimiter, which may be `""`, `" "`, or `"="`.
    #
    # @return [String] The delimiter
    # @return [nil] if the flag type is not `:value`.
    #
    attr_reader :value_delim

    ##
    # The display name of this flag.
    # @return [String]
    #
    attr_reader :display_name

    ##
    # A string that can be used to sort this flag
    # @return [String]
    #
    attr_reader :sort_str

    ##
    # An array of Flag::Syntax including only short (single dash) flags.
    # @return [Array<Flag::Syntax>]
    #
    def short_flag_syntax
      @short_flag_syntax ||= flag_syntax.find_all { |ss| ss.flag_style == :short }
    end

    ##
    # An array of Flag::Syntax including only long (double-dash) flags.
    # @return [Array<Flag::Syntax>]
    #
    def long_flag_syntax
      @long_flag_syntax ||= flag_syntax.find_all { |ss| ss.flag_style == :long }
    end

    ##
    # The list of all effective flags used.
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
    # @param str [String] Flag string to look up
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
    # A list of canonical flag syntax strings.
    #
    # @return [Array<String>]
    #
    def canonical_syntax_strings
      @canonical_syntax_strings ||= flag_syntax.map(&:canonical_str)
    end

    ##
    # Whether this flag is active--that is, it has a nonempty flags list.
    #
    # @return [Boolean]
    #
    def active?
      !effective_flags.empty?
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

    ##
    # Append long description strings.
    #
    # You must pass an array of lines in the long description. See {#long_desc}
    # for details on how each line may be represented.
    #
    # @param long_desc [Array<Toys::WrappableString,String,Array<String>>]
    # @return [self]
    #
    def append_long_desc(long_desc)
      @long_desc.concat(WrappableString.make_array(long_desc))
      self
    end

    ##
    # Create a Flag definition.
    # This argument list is subject to change. Use {Toys::Flag.create} instead
    # for a more stable interface.
    #
    # @private
    #
    def initialize(key, flags, used_flags, report_collisions, acceptor, handler, default,
                   flag_completion, value_completion, desc, long_desc, display_name, group)
      @group = group
      @key = key
      @flag_syntax = Array(flags).map { |s| Syntax.new(s) }
      @explicit_acceptor = !acceptor.nil?
      @acceptor = Acceptor.create(acceptor)
      @handler = resolve_handler(handler)
      @desc = WrappableString.make(desc)
      @long_desc = WrappableString.make_array(long_desc)
      @default = default
      @flag_completion = create_flag_completion(flag_completion)
      @value_completion = Completion.create(value_completion, **{})
      create_default_flag if @flag_syntax.empty?
      remove_used_flags(used_flags, report_collisions)
      canonicalize
      summarize(display_name)
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
      spec =
        case spec
        when nil, :default
          {"": DefaultCompletion, flag: self}
        when ::Hash
          spec[:""].nil? ? spec.merge({"": DefaultCompletion, flag: self}) : spec
        else
          spec
        end
      Completion.create(spec, **{})
    end

    def create_default_flag
      key_str = key.to_s
      flag_str =
        if key_str.length == 1
          "-#{key_str}" if key_str =~ /[a-zA-Z0-9?]/
        elsif key_str.length > 1
          key_str = key_str.downcase.tr("_", "-").gsub(/[^a-z0-9-]/, "").sub(/^-+/, "")
          "--#{key_str}" unless key_str.empty?
        end
      if flag_str
        needs_val = @value_completion != Completion::EMPTY ||
                    @explicit_acceptor ||
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
      if @flag_type == :boolean && @explicit_acceptor
        raise ToolDefinitionError,
              "Flag #{key.inspect} cannot have an acceptor because it does not take a value."
      end
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
  end
end
