# frozen_string_literal: true

module Toys
  module DSL
    ##
    # DSL for a flag definition block. Lets you set flag attributes in a block
    # instead of a long series of keyword arguments.
    #
    # These directives are available inside a block passed to
    # {Toys::DSL::Tool#flag}.
    #
    # ### Example
    #
    #     tool "mytool" do
    #       flag :value do
    #         # The directives in here are defined by this class
    #         flags "--value=VAL"
    #         accept Integer
    #         desc "An integer value"
    #       end
    #       # ...
    #     end
    #
    class Flag
      ##
      # Add flags in OptionParser format. This may be called multiple times,
      # and the results are cumulative.
      #
      # Following are examples of valid syntax.
      #
      #  *  `-a` : A short boolean switch. When this appears as an argument,
      #     the value is set to `true`.
      #  *  `--abc` : A long boolean switch. When this appears as an argument,
      #     the value is set to `true`.
      #  *  `-aVAL` or `-a VAL` : A short flag that takes a required value.
      #     These two forms are treated identically. If this argument appears
      #     with a value attached (e.g. `-afoo`), the attached string (e.g.
      #     `"foo"`) is taken as the value. Otherwise, the following argument
      #     is taken as the value (e.g. for `-a foo`, the value is set to
      #     `"foo"`.) The following argument is treated as the value even if it
      #     looks like a flag (e.g. `-a -a` causes the string `"-a"` to be
      #     taken as the value.)
      #  *  `-a[VAL]` : A short flag that takes an optional value. If this
      #     argument appears with a value attached (e.g. `-afoo`), the attached
      #     string (e.g. `"foo"`) is taken as the value. Otherwise, the value
      #     is set to `true`. The following argument is never interpreted as
      #     the value. (Compare with `-a [VAL]`.)
      #  *  `-a [VAL]` : A short flag that takes an optional value. If this
      #     argument appears with a value attached (e.g. `-afoo`), the attached
      #     string (e.g. `"foo"`) is taken as the value. Otherwise, if the
      #     following argument does not look like a flag (i.e. it does not
      #     begin with a hyphen), it is taken as the value. (e.g. `-a foo`
      #     causes the string `"foo"` to be taken as the value.). If there is
      #     no following argument, or the following argument looks like a flag,
      #     the value is set to `true`. (Compare with `-a[VAL]`.)
      #  *  `--abc=VAL` or `--abc VAL` : A long flag that takes a required
      #     value. These two forms are treated identically. If this argument
      #     appears with a value attached (e.g. `--abc=foo`), the attached
      #     string (e.g. `"foo"`) is taken as the value. Otherwise, the
      #     following argument is taken as the value (e.g. for `--abc foo`, the
      #     value is set to `"foo"`.) The following argument is treated as the
      #     value even if it looks like a flag (e.g. `--abc --def` causes the
      #     string `"--def"` to be taken as the value.)
      #  *  `--abc[=VAL]` : A long flag that takes an optional value. If this
      #     argument appears with a value attached (e.g. `--abc=foo`), the
      #     attached string (e.g. `"foo"`) is taken as the value. Otherwise,
      #     the value is set to `true`. The following argument is never
      #     interpreted as the value. (Compare with `--abc [VAL]`.)
      #  *  `--abc [VAL]` : A long flag that takes an optional value. If this
      #     argument appears with a value attached (e.g. `--abc=foo`), the
      #     attached string (e.g. `"foo"`) is taken as the value. Otherwise, if
      #     the following argument does not look like a flag (i.e. it does not
      #     begin with a hyphen), it is taken as the value. (e.g. `--abc foo`
      #     causes the string `"foo"` to be taken as the value.). If there is
      #     no following argument, or the following argument looks like a flag,
      #     the value is set to `true`. (Compare with `--abc=[VAL]`.)
      #  *  `--[no-]abc` : A long boolean switch that can be turned either on
      #     or off. This effectively creates two flags, `--abc` which sets the
      #     value to `true`, and `--no-abc` which sets the falue to `false`.
      #
      # @param flags [String...]
      # @return [self]
      #
      def flags(*flags)
        @flags += flags.flatten
        self
      end

      ##
      # Set the acceptor for this flag's values.
      # You can pass either the string name of an acceptor defined in this tool
      # or any of its ancestors, or any other specification recognized by
      # {Toys::Acceptor.create}.
      #
      # @param spec [Object]
      # @param options [Hash]
      # @param block [Proc]
      # @return [self]
      #
      def accept(spec = nil, **options, &block)
        @acceptor = Acceptor.scalarize_spec(spec, options, block)
        self
      end

      ##
      # Set the default value.
      #
      # @param default [Object]
      # @return [self]
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
      # You can also pass one of the special values `:set` or `:push` as the
      # handler. The `:set` handler replaces the previous value (equivalent to
      # `-> (val, _prev) { val }`.) The `:push` handler expects the previous
      # value to be an array and pushes the given value onto it; it should be
      # combined with setting the default value to `[]` and is intended for
      # "multi-valued" flags.
      #
      # @param handler [Proc,:set,:push]
      # @param block [Proc]
      # @return [self]
      #
      def handler(handler = nil, &block)
        @handler = handler || block
        self
      end

      ##
      # Set the shell completion strategy for flag names.
      # You can pass one of the following:
      #
      #  *  The string name of a completion defined in this tool or any of its
      #     ancestors.
      #  *  A hash of options to pass to the constructor of
      #     {Toys::Flag::DefaultCompletion}.
      #  *  `nil` or `:default` to select the standard completion strategy
      #     (which is {Toys::Flag::DefaultCompletion} with no extra options).
      #  *  Any other specification recognized by {Toys::Completion.create}.
      #
      # @param spec [Object]
      # @param options [Hash]
      # @param block [Proc]
      # @return [self]
      #
      def complete_flags(spec = nil, **options, &block)
        @flag_completion = Completion.scalarize_spec(spec, options, block)
        self
      end

      ##
      # Set the shell completion strategy for flag values.
      # You can pass either the string name of a completion defined in this
      # tool or any of its ancestors, or any other specification recognized by
      # {Toys::Completion.create}.
      #
      # @param spec [Object]
      # @param options [Hash]
      # @param block [Proc]
      # @return [self]
      #
      def complete_values(spec = nil, **options, &block)
        @value_completion = Completion.scalarize_spec(spec, options, block)
        self
      end

      ##
      # Set whether to raise an exception if a flag is requested that is
      # already in use or marked as disabled.
      #
      # @param setting [Boolean]
      # @return [self]
      #
      def report_collisions(setting)
        @report_collisions = setting
        self
      end

      ##
      # Set the short description for the current flag. The short description
      # is displayed with the flag in online help.
      #
      # The description is a {Toys::WrappableString}, which may be word-wrapped
      # when displayed in a help screen. You may pass a {Toys::WrappableString}
      # directly to this method, or you may pass any input that can be used to
      # construct a wrappable string:
      #
      #  *  If you pass a String, its whitespace will be compacted (i.e. tabs,
      #     newlines, and multiple consecutive whitespace will be turned into a
      #     single space), and it will be word-wrapped on whitespace.
      #  *  If you pass an Array of Strings, each string will be considered a
      #     literal word that cannot be broken, and wrapping will be done
      #     across the strings in the array. In this case, whitespace is not
      #     compacted.
      #
      # ### Examples
      #
      # If you pass in a sentence as a simple string, it may be word wrapped
      # when displayed:
      #
      #     desc "This sentence may be wrapped."
      #
      # To specify a sentence that should never be word-wrapped, pass it as the
      # sole element of a string array:
      #
      #     desc ["This sentence will not be wrapped."]
      #
      # @param desc [String,Array<String>,Toys::WrappableString]
      # @return [self]
      #
      def desc(desc)
        @desc = desc
        self
      end

      ##
      # Add to the long description for the current flag. The long description
      # is displayed with the flag in online help. This directive may be given
      # multiple times, and the results are cumulative.
      #
      # A long description is a series of descriptions, which are generally
      # displayed in a series of lines/paragraphs. Each individual description
      # uses the form described in the {#desc} documentation, and may be
      # word-wrapped when displayed. To insert a blank line, include an empty
      # string as one of the descriptions.
      #
      # ### Example
      #
      #     long_desc "This initial paragraph might get word wrapped.",
      #               "This next paragraph is followed by a blank line.",
      #               "",
      #               ["This line will not be wrapped."],
      #               ["    This indent is preserved."]
      #     long_desc "This line is appended to the description."
      #
      # @param long_desc [String,Array<String>,Toys::WrappableString...]
      # @return [self]
      #
      def long_desc(*long_desc)
        @long_desc += long_desc
        self
      end

      ##
      # Set the group. A group may be set by name or group object. Setting
      # `nil` selects the default group.
      #
      # @param group [String,Symbol,Toys::FlagGroup,nil]
      # @return [self]
      #
      def group(group)
        @group = group
        self
      end

      ##
      # Set the display name for this flag. This may be used in help text and
      # error messages.
      #
      # @param display_name [String]
      # @return [self]
      #
      def display_name(display_name)
        @display_name = display_name
        self
      end

      ##
      # Called only from DSL::Tool
      #
      # @private
      #
      def initialize(flags, acceptor, default, handler, flag_completion, value_completion,
                     report_collisions, group, desc, long_desc, display_name)
        @flags = flags
        @default = default
        @handler = handler
        @report_collisions = report_collisions
        @group = group
        @desc = desc
        @long_desc = long_desc || []
        @display_name = display_name
        accept(acceptor)
        complete_flags(flag_completion, **{})
        complete_values(value_completion, **{})
      end

      ##
      # @private
      #
      def _add_to(tool, key)
        tool.add_flag(key, @flags,
                      accept: @acceptor, default: @default, handler: @handler,
                      complete_flags: @flag_completion, complete_values: @value_completion,
                      report_collisions: @report_collisions, group: @group,
                      desc: @desc, long_desc: @long_desc, display_name: @display_name)
      end
    end
  end
end
