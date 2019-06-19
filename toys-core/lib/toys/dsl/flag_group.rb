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
  module DSL
    ##
    # DSL for a flag group definition block. Lets you create flags in a group.
    #
    # These directives are available inside a block passed to
    # {Toys::DSL::Tool#flag_group}, {Toys::DSL::Tool#all_required},
    # {Toys::DSL::Tool#at_most_one}, {Toys::DSL::Tool#at_least_one}, or
    # {Toys::DSL::Tool#exactly_one}.
    #
    # ## Example
    #
    #     tool "login" do
    #       all_required do
    #         # The directives in here are defined by this class
    #         flag :username, "--username=VAL", desc: "Set username (required)"
    #         flag :password, "--password=VAL", desc: "Set password (required)"
    #       end
    #       # ...
    #     end
    #
    class FlagGroup
      ## @private
      def initialize(tool_dsl, tool, flag_group)
        @tool_dsl = tool_dsl
        @tool = tool
        @flag_group = flag_group
      end

      ##
      # Add a flag to the current group. Each flag must specify a key which
      # the script may use to obtain the flag value from the context.
      # You may then provide the flags themselves in OptionParser form.
      #
      # If the given key is a symbol representing a valid method name, then a
      # helper method is automatically added to retrieve the value. Otherwise,
      # if the key is a string or does not represent a valid method name, the
      # tool can retrieve the value by calling {Toys::Context#get}.
      #
      # Attributes of the flag may be passed in as arguments to this method, or
      # set in a block passed to this method. If you provide a block, you can
      # use directives in {Toys::DSL::Flag} within the block.
      #
      # ## Flag syntax
      #
      # The flags themselves should be provided in OptionParser form. Following
      # are examples of valid syntax.
      #
      # *   `-a` : A short boolean switch. When this appears as an argument,
      #     the value is set to `true`.
      # *   `--abc` : A long boolean switch. When this appears as an argument,
      #     the value is set to `true`.
      # *   `-aVAL` or `-a VAL` : A short flag that takes a required value.
      #     These two forms are treated identically. If this argument appears
      #     with a value attached (e.g. `-afoo`), the attached string (e.g.
      #     `"foo"`) is taken as the value. Otherwise, the following argument
      #     is taken as the value (e.g. for `-a foo`, the value is set to
      #     `"foo"`.) The following argument is treated as the value even if it
      #     looks like a flag (e.g. `-a -a` causes the string `"-a"` to be
      #     taken as the value.)
      # *   `-a[VAL]` : A short flag that takes an optional value. If this
      #     argument appears with a value attached (e.g. `-afoo`), the attached
      #     string (e.g. `"foo"`) is taken as the value. Otherwise, the value
      #     is set to `true`. The following argument is never interpreted as
      #     the value. (Compare with `-a [VAL]`.)
      # *   `-a [VAL]` : A short flag that takes an optional value. If this
      #     argument appears with a value attached (e.g. `-afoo`), the attached
      #     string (e.g. `"foo"`) is taken as the value. Otherwise, if the
      #     following argument does not look like a flag (i.e. it does not
      #     begin with a hyphen), it is taken as the value. (e.g. `-a foo`
      #     causes the string `"foo"` to be taken as the value.). If there is
      #     no following argument, or the following argument looks like a flag,
      #     the value is set to `true`. (Compare with `-a[VAL]`.)
      # *   `--abc=VAL` or `--abc VAL` : A long flag that takes a required
      #     value. These two forms are treated identically. If this argument
      #     appears with a value attached (e.g. `--abc=foo`), the attached
      #     string (e.g. `"foo"`) is taken as the value. Otherwise, the
      #     following argument is taken as the value (e.g. for `--abc foo`, the
      #     value is set to `"foo"`.) The following argument is treated as the
      #     value even if it looks like a flag (e.g. `--abc --abc` causes the
      #     string `"--abc"` to be taken as the value.)
      # *   `--abc[=VAL]` : A long flag that takes an optional value. If this
      #     argument appears with a value attached (e.g. `--abc=foo`), the
      #     attached string (e.g. `"foo"`) is taken as the value. Otherwise,
      #     the value is set to `true`. The following argument is never
      #     interpreted as the value. (Compare with `--abc [VAL]`.)
      # *   `--abc [VAL]` : A long flag that takes an optional value. If this
      #     argument appears with a value attached (e.g. `--abc=foo`), the
      #     attached string (e.g. `"foo"`) is taken as the value. Otherwise, if
      #     the following argument does not look like a flag (i.e. it does not
      #     begin with a hyphen), it is taken as the value. (e.g. `--abc foo`
      #     causes the string `"foo"` to be taken as the value.). If there is
      #     no following argument, or the following argument looks like a flag,
      #     the value is set to `true`. (Compare with `--abc=[VAL]`.)
      # *   `--[no-]abc` : A long boolean switch that can be turned either on
      #     or off. This effectively creates two flags, `--abc` which sets the
      #     value to `true`, and `--no-abc` which sets the falue to `false`.
      #
      # ## Default flag syntax
      #
      # If no flag syntax strings are provided, a default syntax will be
      # inferred based on the key and other options.
      #
      # Specifically, if the key has one character, then that character will be
      # chosen as a short flag. If the key has multiple characters, a long flag
      # will be generated.
      #
      # Furthermore, if a custom completion, a non-boolean acceptor, or a
      # non-boolean default value is provided in the options, then the flag
      # will be considered to take a value. Otherwise, it will be considered to
      # be a boolean switch.
      #
      # For example, the following pairs of flags are identical:
      #
      #     flag :a
      #     flag :a, "-a"
      #
      #     flag :abc_def
      #     flag :abc_def, "--abc-def"
      #
      #     flag :number, accept: Integer
      #     flag :number, "--number=VAL", accept: Integer
      #
      # ## More examples
      #
      # A flag that sets its value to the number of times it appears on the
      # command line:
      #
      #     flag :verbose, "-v", "--verbose",
      #          default: 0, handler: ->(_val, count) { count + 1 }
      #
      # An example using block form:
      #
      #     flag :shout do
      #       flags "-s", "--shout"
      #       default false
      #       desc "Say it louder"
      #       long_desc "This flag says it lowder.",
      #                 "You might use this when people can't hear you.",
      #                 "",
      #                 "Example:",
      #                 ["    toys say --shout hello"]
      #     end
      #
      # @param key [String,Symbol] The key to use to retrieve the value from
      #     the execution context.
      # @param flags [String...] The flags in OptionParser format.
      # @param accept [Object] An acceptor that validates and/or converts the
      #     value. You may provide either the name of an acceptor you have
      #     defined, or one of the default acceptors provided by OptionParser.
      #     Optional. If not specified, accepts any value as a string.
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
      # @param complete_flags [Object] A specifier for shell tab completion
      #     for flag names associated with this flag. By default, a
      #     {Toys::Flag::DefaultCompletion} is used, which provides the flag's
      #     names as completion candidates. To customize completion, set this
      #     to the name of a previously defined completion, a hash of options
      #     to pass to the constructor for {Toys::Flag::DefaultCompletion}, or
      #     any other spec recognized by {Toys::Completion.create}.
      # @param complete_values [Object] A specifier for shell tab completion
      #     for flag values associated with this flag. This is the empty
      #     completion by default. To customize completion, set this to the
      #     name of a previously defined completion, or any spec recognized by
      #     {Toys::Completion.create}.
      # @param report_collisions [Boolean] Raise an exception if a flag is
      #     requested that is already in use or marked as unusable. Default is
      #     true.
      # @param desc [String,Array<String>,Toys::WrappableString] Short
      #     description for the flag. See {Toys::DSL::Tool#desc} for a
      #     description of the allowed formats. Defaults to the empty string.
      # @param long_desc [Array<String,Array<String>,Toys::WrappableString>]
      #     Long description for the flag. See {Toys::DSL::Tool#long_desc} for
      #     a description of the allowed formats. (But note that this param
      #     takes an Array of description lines, rather than a series of
      #     arguments.) Defaults to the empty array.
      # @param display_name [String] A display name for this flag, used in help
      #     text and error messages.
      # @param block [Proc] Configures the flag. See {Toys::DSL::Flag} for the
      #     directives that can be called in this block.
      # @return [self]
      #
      def flag(key, *flags,
               accept: nil, default: nil, handler: nil, complete_flags: nil, complete_values: nil,
               report_collisions: true, desc: nil, long_desc: nil, display_name: nil,
               &block)
        flag_dsl = DSL::Flag.new(flags, accept, default, handler, complete_flags, complete_values,
                                 report_collisions, @flag_group, desc, long_desc, display_name)
        flag_dsl.instance_exec(flag_dsl, &block) if block
        flag_dsl._add_to(@tool, key)
        DSL::Tool.maybe_add_getter(@tool_dsl, key)
        self
      end

      ##
      # Set the short description for the current flag group. The short
      # description is displayed as the group title in online help.
      #
      # The description is a {Toys::WrappableString}, which may be word-wrapped
      # when displayed in a help screen. You may pass a {Toys::WrappableString}
      # directly to this method, or you may pass any input that can be used to
      # construct a wrappable string:
      #
      # *   If you pass a String, its whitespace will be compacted (i.e. tabs,
      #     newlines, and multiple consecutive whitespace will be turned into a
      #     single space), and it will be word-wrapped on whitespace.
      # *   If you pass an Array of Strings, each string will be considered a
      #     literal word that cannot be broken, and wrapping will be done
      #     across the strings in the array. In this case, whitespace is not
      #     compacted.
      #
      # ## Examples
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
        @flag_group.desc = desc
        self
      end

      ##
      # Add to the long description for the current flag group. The long
      # description is displayed with the flag group in online help. This
      # directive may be given multiple times, and the results are cumulative.
      #
      # A long description is a series of descriptions, which are generally
      # displayed in a series of lines/paragraphs. Each individual description
      # uses the form described in the {#desc} documentation, and may be
      # word-wrapped when displayed. To insert a blank line, include an empty
      # string as one of the descriptions.
      #
      # ## Example
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
        @flag_group.append_long_desc(long_desc)
        self
      end
    end
  end
end
