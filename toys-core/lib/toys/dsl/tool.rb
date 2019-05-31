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
    # This class defines the DSL for a Toys configuration file.
    #
    # A Toys configuration defines one or more named tools. It provides syntax
    # for setting the description, defining flags and arguments, specifying
    # how to execute the tool, and requesting mixin modules and other services.
    # It also lets you define subtools, nested arbitrarily deep, using blocks.
    #
    # ## Simple example
    #
    # Create a file called `.toys.rb` in the current directory, with the
    # following contents:
    #
    #     tool "greet" do
    #       desc "Prints a simple greeting"
    #
    #       optional_arg :recipient, default: "world"
    #
    #       def run
    #         puts "Hello, #{recipient}!"
    #       end
    #     end
    #
    # Now you can execute it using:
    #
    #     toys greet
    #
    # or try:
    #
    #     toys greet rubyists
    #
    module Tool
      ## @private
      def method_added(_meth)
        DSL::Tool.current_tool(self, true)&.check_definition_state
      end

      ##
      # Create an acceptor that can be passed into a flag or arg. An acceptor
      # validates the string parameter passed to the flag or arg, and
      # optionally converts it to a different object before storing it in your
      # tool's data.
      #
      # When you create an acceptor, you provide a string name. The acceptor
      # can, from the current tool or its subtools, be referenced by that name.
      #
      # Acceptors can be defined in one of three ways.
      #
      # *   You can provide a **regular expression**. This acceptor validates
      #     only if the regex matches the *entire string parameter*.
      #
      #     You can also provide an optional conversion function as a block. If
      #     provided, function must take a variable number of arguments, the
      #     first being the matched string and the remainder being the captures
      #     from the regular expression. It should return the converted object
      #     that will be stored in the context data. If you do not provide a
      #     block, the original string will be used.
      #
      # *   You can provide an **array** of possible values. The acceptor
      #     validates if the string parameter matches the *string form* of one
      #     of the array elements (i.e. the results of calling `to_s` on the
      #     array elements.)
      #
      #     An array acceptor automatically converts the string parameter to
      #     the actual array element that it matchd. For example, if the symbol
      #     `:foo` is in the array, it will match the string `"foo"`, and then
      #     store the symbol `:foo` in the tool data.
      #
      # *   You can provide a **function** by passing it as a proc or a block.
      #     This function performs *both* validation and conversion. It should
      #     take the string parameter as its argument, and it must either
      #     return the object that should be stored in the tool data, or raise
      #     an exception (descended from `StandardError`) to indicate that the
      #     string parameter is invalid.
      #
      # @param [String] name The acceptor name.
      # @param [Regexp,Array,Proc,nil] arg The acceptor specification.
      # @return [Toys::DSL::Tool] self, for chaining.
      #
      def acceptor(name, arg = nil, &block)
        cur_tool = DSL::Tool.current_tool(self, false)
        return self if cur_tool.nil?
        name = name.to_s
        accept =
          case arg
          when ::Regexp
            Acceptor::Pattern.new(name, arg, &block)
          when ::Array
            Acceptor::Enum.new(name, arg)
          when ::Proc
            Acceptor::Simple.new(name, arg)
          when nil
            Acceptor::Simple.new(name, &block)
          else
            raise ToolDefinitionError, "Illegal acceptor: #{arg.inspect}"
          end
        cur_tool.add_acceptor(accept)
        self
      end

      ##
      # Create a named mixin module.
      # This module may be included by name in this tool or any subtool.
      #
      # You should pass a block and define methods in that block.
      #
      # @param [String] name Name of the mixin
      # @return [Toys::DSL::Tool] self, for chaining.
      #
      def mixin(name, &block)
        cur_tool = DSL::Tool.current_tool(self, false)
        if cur_tool
          mixin_mod = ::Module.new do
            include ::Toys::Mixin
          end
          mixin_mod.module_eval(&block)
          cur_tool.add_mixin(name, mixin_mod)
        end
        self
      end

      ##
      # Create a named template class.
      # This template may be expanded by name in this tool or any subtool.
      #
      # You should pass a block and define the template in that block. You do
      # not need to include `Toys::Template` in the block. Otherwise, see
      # {Toys::Template} for information on defining a template. In general,
      # the block should define an initialize method, and call `to_expand` to
      # define how to expand the template.
      #
      # @param [String] name Name of the template
      # @return [Toys::DSL::Tool] self, for chaining.
      #
      def template(name, &block)
        cur_tool = DSL::Tool.current_tool(self, false)
        if cur_tool
          template_class = ::Class.new do
            include ::Toys::Template
          end
          template_class.class_eval(&block)
          cur_tool.add_template(name, template_class)
        end
        self
      end

      ##
      # Create a subtool. You must provide a block defining the subtool.
      #
      # @param [String,Array<String>] words The name of the subtool
      # @param [:combine,:reset,:ignore] if_defined What to do if a definition
      #     already exists for this tool. Possible values are `:combine` (the
      #     default) indicating the definition should be combined with the
      #     existing definition, `:reset` indicating the earlier definition
      #     should be reset and the new definition applied instead, or
      #     `:ignore` indicating the new definition should be ignored.
      # @return [Toys::DSL::Tool] self, for chaining.
      #
      def tool(words, if_defined: :combine, &block)
        subtool_words = @__words
        next_remaining = @__remaining_words
        Array(words).each do |word|
          word = word.to_s
          subtool_words += [word]
          next_remaining = Loader.next_remaining_words(next_remaining, word)
        end
        subtool = @__loader.get_tool_definition(subtool_words, @__priority)
        if subtool.includes_definition?
          case if_defined
          when :ignore
            return self
          when :reset
            subtool.reset_definition(@__loader)
          end
        end
        subtool_class = subtool.tool_class
        DSL::Tool.prepare(subtool_class, next_remaining, source_info) do
          subtool_class.class_eval(&block)
        end
        self
      end
      alias name tool

      ##
      # Create an alias in the current namespace.
      #
      # @param [String] word The name of the alias
      # @param [String] target The target of the alias
      # @return [Toys::DSL::Tool] self, for chaining.
      #
      def alias_tool(word, target)
        @__loader.make_alias(@__words + [word.to_s], @__words + [target.to_s], @__priority)
        self
      end

      ##
      # Load another config file or directory, as if its contents were inserted
      # at the current location.
      #
      # @param [String] path The file or directory to load.
      # @return [Toys::DSL::Tool] self, for chaining.
      #
      def load(path)
        @__loader.load_path(source_info, path, @__words, @__remaining_words, @__priority)
        self
      end

      ##
      # Expand the given template in the current location.
      #
      # The template may be specified as a class or a well-known template name.
      # You may also provide arguments to pass to the template.
      #
      # @param [Class,String,Symbol] template_class The template, either as a
      #     class or a well-known name.
      # @param [Object...] args Template arguments
      # @return [Toys::DSL::Tool] self, for chaining.
      #
      def expand(template_class, *args)
        cur_tool = DSL::Tool.current_tool(self, false)
        name = template_class.to_s
        if template_class.is_a?(::String)
          template_class = cur_tool.resolve_template(template_class)
        elsif template_class.is_a?(::Symbol)
          template_class = @__loader.resolve_standard_template(name)
        end
        if template_class.nil?
          raise ToolDefinitionError, "Template not found: #{name.inspect}"
        end
        template = template_class.new(*args)
        yield template if block_given?
        class_exec(template, &template_class.expander)
        self
      end

      ##
      # Set the short description for the current tool. The short description is
      # displayed with the tool in a subtool list. You may also use the
      # equivalent method `short_desc`.
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
      #     literal word that cannot be broken, and wrapping will be done across
      #     the strings in the array. In this case, whitespace is not compacted.
      #
      # For example, if you pass in a sentence as a simple string, it may be
      # word wrapped when displayed:
      #
      #     desc "This sentence may be wrapped."
      #
      # To specify a sentence that should never be word-wrapped, pass it as the
      # sole element of a string array:
      #
      #     desc ["This sentence will not be wrapped."]
      #
      # @param [Toys::WrappableString,String,Array<String>] str
      # @return [Toys::DSL::Tool] self, for chaining.
      #
      def desc(str)
        cur_tool = DSL::Tool.current_tool(self, true)
        cur_tool.desc = str if cur_tool
        self
      end
      alias short_desc desc

      ##
      # Set the long description for the current tool. The long description is
      # displayed in the usage documentation for the tool itself.
      #
      # A long description is a series of descriptions, which are generally
      # displayed in a series of lines/paragraphs. Each individual description
      # uses the form described in the {Toys::DSL::Tool#desc} documentation, and
      # may be word-wrapped when displayed. To insert a blank line, include an
      # empty string as one of the descriptions.
      #
      # Example:
      #
      #     long_desc "This is an initial paragraph that might be word wrapped.",
      #               "This next paragraph is followed by a blank line.",
      #               "",
      #               ["This line will not be wrapped."]
      #
      # @param [Toys::WrappableString,String,Array<String>...] strs
      # @return [Toys::DSL::Tool] self, for chaining.
      #
      def long_desc(*strs)
        DSL::Tool.current_tool(self, true)&.append_long_desc(strs)
        self
      end

      ##
      # Create a flag group. If a block is given, flags defined in the block
      # belong to the group. The flags in the group are listed together in
      # help screens.
      #
      # Example:
      #
      #     flag_group desc: "Debug Flags" do
      #       flag :debug, "-D", desc: "Enable debugger"
      #       flag :warnings, "-W[VAL]", desc: "Enable warnings"
      #     end
      #
      # @param [Symbol] type The type of group. Allowed values: `:required`,
      #     `:optional`, `:exactly_one`, `:at_most_one`, `:at_least_one`.
      #     Default is `:optional`.
      # @param [String,Array<String>,Toys::WrappableString] desc Short
      #     description for the group. See {Toys::Tool#desc=} for a description
      #     of allowed formats. Defaults to `"Flags"`.
      # @param [Array<String,Array<String>,Toys::WrappableString>] long_desc
      #     Long description for the flag group. See
      #     {Toys::Tool#long_desc=} for a description of allowed formats.
      #     Defaults to the empty array.
      # @param [String,Symbol,nil] name The name of the group, or nil for no
      #     name.
      # @param [Boolean] report_collisions If `true`, raise an exception if a
      #     the given name is already taken. If `false`, ignore. Default is
      #     `true`.
      # @param [Boolean] prepend If `true`, prepend rather than append the
      #     group to the list. Default is `false`.
      # @yieldparam flag_group_dsl [Toys::DSL::FlagGroup] An object that lets
      #     add flags to this group in a block.
      # @return [Toys::DSL::Tool] self, for chaining.
      #
      def flag_group(type: :optional, desc: nil, long_desc: nil, name: nil,
                     report_collisions: true, prepend: false, &block)
        cur_tool = DSL::Tool.current_tool(self, true)
        return self if cur_tool.nil?
        cur_tool.add_flag_group(type: type, desc: desc, long_desc: long_desc, name: name,
                                report_collisions: report_collisions, prepend: prepend)
        group = prepend ? cur_tool.flag_groups.first : cur_tool.flag_groups.last
        flag_group_dsl = DSL::FlagGroup.new(self, cur_tool, group)
        flag_group_dsl.instance_exec(flag_group_dsl, &block) if block
        self
      end

      ##
      # Create a flag group of type `:required`. If a block is given, flags
      # defined in the block belong to the group. All flags in this group are
      # required.
      #
      # Example:
      #
      #     all_required do
      #       flag :username, "--username=VAL", desc: "Set the username (required)"
      #       flag :password, "--password=VAL", desc: "Set the password (required)"
      #     end
      #
      # @param [String,Array<String>,Toys::WrappableString] desc Short
      #     description for the group. See {Toys::Tool#desc=} for a description
      #     of allowed formats. Defaults to `"Flags"`.
      # @param [Array<String,Array<String>,Toys::WrappableString>] long_desc
      #     Long description for the flag group. See
      #     {Toys::Tool#long_desc=} for a description of allowed formats.
      #     Defaults to the empty array.
      # @param [String,Symbol,nil] name The name of the group, or nil for no
      #     name.
      # @param [Boolean] report_collisions If `true`, raise an exception if a
      #     the given name is already taken. If `false`, ignore. Default is
      #     `true`.
      # @param [Boolean] prepend If `true`, prepend rather than append the
      #     group to the list. Default is `false`.
      # @yieldparam flag_group_dsl [Toys::DSL::FlagGroup] An object that lets
      #     add flags to this group in a block.
      # @return [Toys::DSL::Tool] self, for chaining.
      #
      def all_required(desc: nil, long_desc: nil, name: nil, report_collisions: true,
                       prepend: false, &block)
        flag_group(type: :required, desc: desc, long_desc: long_desc,
                   name: name, report_collisions: report_collisions, prepend: prepend, &block)
      end

      ##
      # Create a flag group of type `:at_most_one`. If a block is given, flags
      # defined in the block belong to the group. At most one flag in this
      # group must be provided on the command line.
      #
      # @param [String,Array<String>,Toys::WrappableString] desc Short
      #     description for the group. See {Toys::Tool#desc=} for a description
      #     of allowed formats. Defaults to `"Flags"`.
      # @param [Array<String,Array<String>,Toys::WrappableString>] long_desc
      #     Long description for the flag group. See
      #     {Toys::Tool#long_desc=} for a description of allowed formats.
      #     Defaults to the empty array.
      # @param [String,Symbol,nil] name The name of the group, or nil for no
      #     name.
      # @param [Boolean] report_collisions If `true`, raise an exception if a
      #     the given name is already taken. If `false`, ignore. Default is
      #     `true`.
      # @param [Boolean] prepend If `true`, prepend rather than append the
      #     group to the list. Default is `false`.
      # @yieldparam flag_group_dsl [Toys::DSL::FlagGroup] An object that lets
      #     add flags to this group in a block.
      # @return [Toys::DSL::Tool] self, for chaining.
      #
      def at_most_one_required(desc: nil, long_desc: nil, name: nil, report_collisions: true,
                               prepend: false, &block)
        flag_group(type: :at_most_one, desc: desc, long_desc: long_desc,
                   name: name, report_collisions: report_collisions, prepend: prepend, &block)
      end

      ##
      # Create a flag group of type `:at_least_one`. If a block is given, flags
      # defined in the block belong to the group. At least one flag in this
      # group must be provided on the command line.
      #
      # @param [String,Array<String>,Toys::WrappableString] desc Short
      #     description for the group. See {Toys::Tool#desc=} for a description
      #     of allowed formats. Defaults to `"Flags"`.
      # @param [Array<String,Array<String>,Toys::WrappableString>] long_desc
      #     Long description for the flag group. See
      #     {Toys::Tool#long_desc=} for a description of allowed formats.
      #     Defaults to the empty array.
      # @param [String,Symbol,nil] name The name of the group, or nil for no
      #     name.
      # @param [Boolean] report_collisions If `true`, raise an exception if a
      #     the given name is already taken. If `false`, ignore. Default is
      #     `true`.
      # @param [Boolean] prepend If `true`, prepend rather than append the
      #     group to the list. Default is `false`.
      # @yieldparam flag_group_dsl [Toys::DSL::FlagGroup] An object that lets
      #     add flags to this group in a block.
      # @return [Toys::DSL::Tool] self, for chaining.
      #
      def at_least_one_required(desc: nil, long_desc: nil, name: nil, report_collisions: true,
                                prepend: false, &block)
        flag_group(type: :at_least_one, desc: desc, long_desc: long_desc,
                   name: name, report_collisions: report_collisions, prepend: prepend, &block)
      end

      ##
      # Create a flag group of type `:exactly_one`. If a block is given, flags
      # defined in the block belong to the group. Exactly one flag in this
      # group must be provided on the command line.
      #
      # @param [String,Array<String>,Toys::WrappableString] desc Short
      #     description for the group. See {Toys::Tool#desc=} for a description
      #     of allowed formats. Defaults to `"Flags"`.
      # @param [Array<String,Array<String>,Toys::WrappableString>] long_desc
      #     Long description for the flag group. See
      #     {Toys::Tool#long_desc=} for a description of allowed formats.
      #     Defaults to the empty array.
      # @param [String,Symbol,nil] name The name of the group, or nil for no
      #     name.
      # @param [Boolean] report_collisions If `true`, raise an exception if a
      #     the given name is already taken. If `false`, ignore. Default is
      #     `true`.
      # @param [Boolean] prepend If `true`, prepend rather than append the
      #     group to the list. Default is `false`.
      # @yieldparam flag_group_dsl [Toys::DSL::FlagGroup] An object that lets
      #     add flags to this group in a block.
      # @return [Toys::DSL::Tool] self, for chaining.
      #
      def exactly_one_required(desc: nil, long_desc: nil, name: nil, report_collisions: true,
                               prepend: false, &block)
        flag_group(type: :exactly_one, desc: desc, long_desc: long_desc,
                   name: name, report_collisions: report_collisions, prepend: prepend, &block)
      end

      ##
      # Add a flag to the current tool. Each flag must specify a key which
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
      # @param [String,Symbol] key The key to use to retrieve the value from
      #     the execution context.
      # @param [String...] flags The flags in OptionParser format.
      # @param [Object] accept An acceptor that validates and/or converts the
      #     value. You may provide either the name of an acceptor you have
      #     defined, or one of the default acceptors provided by OptionParser.
      #     Optional. If not specified, accepts any value as a string.
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
      # @param [Object] flag_completion A specifier for shell tab completion.
      #     for flag names associated with this flag. By default, a
      #     {Toys::Flag::StandardCompletion} is used, which provides the flag's
      #     names as completion candidates. To customize completion, set this
      #     to a hash of options to pass to the constructor for
      #     {Toys::Flag::StandardCompletion}, or pass any other spec recognized
      #     by {Toys::Completion.create}.
      # @param [Object] value_completion A specifier for shell tab completion.
      #     for flag values associated with this flag. Pass any spec
      #     recognized by {Toys::Completion.create}.
      # @param [Boolean] report_collisions Raise an exception if a flag is
      #     requested that is already in use or marked as unusable. Default is
      #     true.
      # @param [Toys::FlagGroup,String,Symbol,nil] group Group for this flag.
      #     You may provide a group name, a FlagGroup object, or `nil` which
      #     denotes the default group.
      # @param [String,Array<String>,Toys::WrappableString] desc Short
      #     description for the flag. See {Toys::DSL::Tool#desc} for a
      #     description of the allowed formats. Defaults to the empty string.
      # @param [Array<String,Array<String>,Toys::WrappableString>] long_desc
      #     Long description for the flag. See {Toys::DSL::Tool#long_desc} for
      #     a description of the allowed formats. (But note that this param
      #     takes an Array of description lines, rather than a series of
      #     arguments.) Defaults to the empty array.
      # @param [String] display_name A display name for this flag, used in help
      #     text and error messages.
      # @yieldparam flag_dsl [Toys::DSL::Flag] An object that lets you
      #     configure this flag in a block.
      # @return [Toys::DSL::Tool] self, for chaining.
      #
      def flag(key, *flags,
               accept: nil, default: nil, handler: nil,
               flag_completion: nil, value_completion: nil,
               report_collisions: true, group: nil,
               desc: nil, long_desc: nil, display_name: nil,
               &block)
        cur_tool = DSL::Tool.current_tool(self, true)
        return self if cur_tool.nil?
        flag_dsl = DSL::Flag.new(
          flags.flatten, accept, default, handler, flag_completion, value_completion,
          report_collisions, group, desc, long_desc, display_name
        )
        flag_dsl.instance_exec(flag_dsl, &block) if block
        flag_dsl._add_to(cur_tool, key)
        DSL::Tool.maybe_add_getter(self, key)
        self
      end

      ##
      # Add a required positional argument to the current tool. You must specify
      # a key which the script may use to obtain the argument value from the
      # context.
      #
      # If the given key is a symbol representing a valid method name, then a
      # helper method is automatically added to retrieve the value. Otherwise,
      # if the key is a string or does not represent a valid method name, the
      # tool can retrieve the value by calling {Toys::Context#get}.
      #
      # Attributes of the arg may be passed in as arguments to this method, or
      # set in a block passed to this method. If you provide a block, you can
      # use directives in {Toys::DSL::Arg} within the block.
      #
      # @param [String,Symbol] key The key to use to retrieve the value from
      #     the execution context.
      # @param [Object] accept An acceptor that validates and/or converts the
      #     value. You may provide either the name of an acceptor you have
      #     defined, or one of the default acceptors provided by OptionParser.
      #     Optional. If not specified, accepts any value as a string.
      # @param [Object] completion A specifier for shell tab completion. See
      #     {Toys::Completion.create} for recognized formats.
      # @param [String] display_name A name to use for display (in help text and
      #     error reports). Defaults to the key in upper case.
      # @param [String,Array<String>,Toys::WrappableString] desc Short
      #     description for the flag. See {Toys::DSL::Tool#desc} for a
      #     description of the allowed formats. Defaults to the empty string.
      # @param [Array<String,Array<String>,Toys::WrappableString>] long_desc
      #     Long description for the flag. See {Toys::DSL::Tool#long_desc} for
      #     a description of the allowed formats. (But note that this param
      #     takes an Array of description lines, rather than a series of
      #     arguments.) Defaults to the empty array.
      # @yieldparam arg_dsl [Toys::DSL::Arg] An object that lets you configure
      #     this argument in a block.
      # @return [Toys::DSL::Tool] self, for chaining.
      #
      def required_arg(key,
                       accept: nil, completion: nil, display_name: nil,
                       desc: nil, long_desc: nil,
                       &block)
        cur_tool = DSL::Tool.current_tool(self, true)
        return self if cur_tool.nil?
        arg_dsl = DSL::Arg.new(accept, nil, completion, display_name, desc, long_desc)
        arg_dsl.instance_exec(arg_dsl, &block) if block
        arg_dsl._add_required_to(cur_tool, key)
        DSL::Tool.maybe_add_getter(self, key)
        self
      end
      alias required required_arg

      ##
      # Add an optional positional argument to the current tool. You must specify
      # a key which the script may use to obtain the argument value from the
      # context. If an optional argument is not given on the command line, the
      # value is set to the given default.
      #
      # If the given key is a symbol representing a valid method name, then a
      # helper method is automatically added to retrieve the value. Otherwise,
      # if the key is a string or does not represent a valid method name, the
      # tool can retrieve the value by calling {Toys::Context#get}.
      #
      # Attributes of the arg may be passed in as arguments to this method, or
      # set in a block passed to this method. If you provide a block, you can
      # use directives in {Toys::DSL::Arg} within the block.
      #
      # @param [String,Symbol] key The key to use to retrieve the value from
      #     the execution context.
      # @param [Object] default The default value. This is the value that will
      #     be set in the context if this argument is not provided on the command
      #     line. Defaults to `nil`.
      # @param [Object] accept An acceptor that validates and/or converts the
      #     value. You may provide either the name of an acceptor you have
      #     defined, or one of the default acceptors provided by OptionParser.
      #     Optional. If not specified, accepts any value as a string.
      # @param [Object] completion A specifier for shell tab completion. See
      #     {Toys::Completion.create} for recognized formats.
      # @param [String] display_name A name to use for display (in help text and
      #     error reports). Defaults to the key in upper case.
      # @param [String,Array<String>,Toys::WrappableString] desc Short
      #     description for the flag. See {Toys::DSL::Tool#desc} for a
      #     description of the allowed formats. Defaults to the empty string.
      # @param [Array<String,Array<String>,Toys::WrappableString>] long_desc
      #     Long description for the flag. See {Toys::DSL::Tool#long_desc} for
      #     a description of the allowed formats. (But note that this param
      #     takes an Array of description lines, rather than a series of
      #     arguments.) Defaults to the empty array.
      # @yieldparam arg_dsl [Toys::DSL::Arg] An object that lets you configure
      #     this argument in a block.
      # @return [Toys::DSL::Tool] self, for chaining.
      #
      def optional_arg(key,
                       default: nil, accept: nil, completion: nil, display_name: nil,
                       desc: nil, long_desc: nil,
                       &block)
        cur_tool = DSL::Tool.current_tool(self, true)
        return self if cur_tool.nil?
        arg_dsl = DSL::Arg.new(accept, default, completion, display_name, desc, long_desc)
        arg_dsl.instance_exec(arg_dsl, &block) if block
        arg_dsl._add_optional_to(cur_tool, key)
        DSL::Tool.maybe_add_getter(self, key)
        self
      end
      alias optional optional_arg

      ##
      # Specify what should be done with unmatched positional arguments. You must
      # specify a key which the script may use to obtain the remaining args from
      # the context.
      #
      # If the given key is a symbol representing a valid method name, then a
      # helper method is automatically added to retrieve the value. Otherwise,
      # if the key is a string or does not represent a valid method name, the
      # tool can retrieve the value by calling {Toys::Context#get}.
      #
      # Attributes of the arg may be passed in as arguments to this method, or
      # set in a block passed to this method. If you provide a block, you can
      # use directives in {Toys::DSL::Arg} within the block.
      #
      # @param [String,Symbol] key The key to use to retrieve the value from
      #     the execution context.
      # @param [Object] default The default value. This is the value that will
      #     be set in the context if no unmatched arguments are provided on the
      #     command line. Defaults to the empty array `[]`.
      # @param [Object] accept An acceptor that validates and/or converts the
      #     value. You may provide either the name of an acceptor you have
      #     defined, or one of the default acceptors provided by OptionParser.
      #     Optional. If not specified, accepts any value as a string.
      # @param [Object] completion A specifier for shell tab completion. See
      #     {Toys::Completion.create} for recognized formats.
      # @param [String] display_name A name to use for display (in help text and
      #     error reports). Defaults to the key in upper case.
      # @param [String,Array<String>,Toys::WrappableString] desc Short
      #     description for the flag. See {Toys::DSL::Tool#desc} for a
      #     description of the allowed formats. Defaults to the empty string.
      # @param [Array<String,Array<String>,Toys::WrappableString>] long_desc
      #     Long description for the flag. See {Toys::DSL::Tool#long_desc} for
      #     a description of the allowed formats. (But note that this param
      #     takes an Array of description lines, rather than a series of
      #     arguments.) Defaults to the empty array.
      # @yieldparam arg_dsl [Toys::DSL::Arg] An object that lets you configure
      #     this argument in a block.
      # @return [Toys::DSL::Tool] self, for chaining.
      #
      def remaining_args(key,
                         default: [], accept: nil, completion: nil, display_name: nil,
                         desc: nil, long_desc: nil,
                         &block)
        cur_tool = DSL::Tool.current_tool(self, true)
        return self if cur_tool.nil?
        arg_dsl = DSL::Arg.new(accept, default, completion, display_name, desc, long_desc)
        arg_dsl.instance_exec(arg_dsl, &block) if block
        arg_dsl._set_remaining_on(cur_tool, key)
        DSL::Tool.maybe_add_getter(self, key)
        self
      end
      alias remaining remaining_args

      ##
      # Set an option value statically.
      #
      # If the given key is a symbol representing a valid method name, then a
      # helper method is automatically added to retrieve the value. Otherwise,
      # if the key is a string or does not represent a valid method name, the
      # tool can retrieve the value by calling {Toys::Context#get}.
      #
      # @param [String,Symbol] key The key to use to retrieve the value from
      #     the execution context.
      # @param [Object] value The value to set.
      # @return [Toys::DSL::Tool] self, for chaining.
      #
      def static(key, value = nil)
        cur_tool = DSL::Tool.current_tool(self, true)
        return self if cur_tool.nil?
        if key.is_a?(::Hash)
          cur_tool.default_data.merge!(key)
          key.each_key do |k|
            DSL::Tool.maybe_add_getter(self, k)
          end
        else
          cur_tool.default_data[key] = value
          DSL::Tool.maybe_add_getter(self, key)
        end
        self
      end

      ##
      # Enforce that all flags must be provided before any positional args.
      # That is, as soon as the first positional arg appears in the command
      # line arguments, flag parsing is disabled as if `--` had appeared.
      #
      # Issuing this directive by itself turns on enforcement. You may turn it
      # off by passsing `false` as the parameter.
      #
      # @param [Boolean] state
      # @return [Toys::DSL::Tool] self, for chaining.
      #
      def enforce_flags_before_args(state = true)
        DSL::Tool.current_tool(self, true)&.enforce_flags_before_args(state)
        self
      end

      ##
      # Disable argument parsing for this tool. Arguments will not be parsed
      # and the options will not be populated. Instead, tools can retrieve the
      # full unparsed argument list by calling {Toys::Context#args}.
      #
      # This directive is mutually exclusive with any of the directives that
      # declare arguments or flags.
      #
      # @return [Toys::DSL::Tool] self, for chaining.
      #
      def disable_argument_parsing
        DSL::Tool.current_tool(self, true)&.disable_argument_parsing
        self
      end

      ##
      # Mark one or more flags as disabled, preventing their use by any
      # subsequent flag definition. This can be used to prevent middleware from
      # defining a particular flag.
      #
      # @param [String...] flags The flags to disable
      # @return [Toys::DSL::Tool] self, for chaining.
      #
      def disable_flag(*flags)
        DSL::Tool.current_tool(self, true)&.disable_flag(*flags)
        self
      end

      ##
      # Specify how to run this tool. Typically you do this by defining a
      # method namd `run`. Alternatively, you can pass a block to this method.
      # You may want to do this if your method needs access to local variables
      # in the lexical scope.
      #
      # @return [Toys::DSL::Tool] self, for chaining.
      #
      def to_run(&block)
        define_method(:run, &block)
        self
      end

      ##
      # Specify how to handle interrupts. Typically you do this by defining a
      # method namd `interrupt`. Alternatively, you can pass a block to this
      # method. You may want to do this if your method needs access to local
      # variables in the lexical scope.
      #
      # @return [Toys::DSL::Tool] self, for chaining.
      #
      def to_interrupt(&block)
        define_method(:interrupt, &block)
        self
      end

      ##
      # Specify that the given module should be mixed into this tool, and its
      # methods made available when running the tool.
      #
      # You may provide either a module, the string name of a mixin that you
      # have defined in this tool or one of its ancestors, or the symbol name
      # of a well-known mixin.
      #
      # @param [Module,Symbol,String] mod Module or module name.
      # @param [Object...] args Arguments to pass to the initializer
      #
      def include(mod, *args)
        cur_tool = DSL::Tool.current_tool(self, true)
        return if cur_tool.nil?
        mod = DSL::Tool.resolve_mixin(mod, cur_tool, @__loader)
        if included_modules.include?(mod)
          raise ToolDefinitionError, "Mixin already included: #{mod.name}"
        end
        cur_tool.mark_includes_modules
        if mod.respond_to?(:initialization_callback)
          callback = mod.initialization_callback
          cur_tool.add_initializer(callback, *args) if callback
        end
        if mod.respond_to?(:inclusion_callback)
          callback = mod.inclusion_callback
          class_exec(*args, &callback) if callback
        end
        super(mod)
      end

      ##
      # Determine if the given module/mixin has already been included.
      #
      # You may provide either a module, the string name of a mixin that you
      # have defined in this tool or one of its ancestors, or the symbol name
      # of a well-known mixin.
      #
      # @param [Module,Symbol,String] mod Module or module name.
      # @return [Boolean,nil] A boolean value, or `nil` if the current tool
      #     is not active.
      #
      def include?(mod)
        cur_tool = DSL::Tool.current_tool(self, false)
        return if cur_tool.nil?
        super(DSL::Tool.resolve_mixin(mod, cur_tool, @__loader))
      end

      ##
      # Return the current source info object.
      #
      # @return [Toys::SourceInfo] Source info.
      #
      def source_info
        @__source.last
      end

      ##
      # Find the given data path (file or directory)
      #
      # @param [String] path The path to find
      # @param [nil,:file,:directory] type Type of file system object to find,
      #     or nil to return any type.
      # @return [String,nil] Absolute path of the result, or nil if not found.
      #
      def find_data(path, type: nil)
        source_info.find_data(path, type: type)
      end

      ##
      # Return the context directory for this tool. Generally, this defaults
      # to the directory containing the toys config directory structure being
      # read, but it may be changed by setting a different context directory
      # for the tool.
      # May return nil if there is no context.
      #
      # @return [String,nil] Context directory
      #
      def context_directory
        DSL::Tool.current_tool(self, false)&.context_directory || source_info.context_directory
      end

      ##
      # Set a custom context directory for this tool.
      #
      # @param [String] dir Context directory
      #
      def set_context_directory(dir) # rubocop:disable Naming/AccessorMethodName
        cur_tool = DSL::Tool.current_tool(self, false)
        return if cur_tool.nil?
        cur_tool.custom_context_directory = dir
        self
      end

      ## @private
      def self.new_class(words, priority, loader)
        tool_class = ::Class.new(::Toys::Context)
        tool_class.extend(DSL::Tool)
        tool_class.instance_variable_set(:@__words, words)
        tool_class.instance_variable_set(:@__priority, priority)
        tool_class.instance_variable_set(:@__loader, loader)
        tool_class.instance_variable_set(:@__remaining_words, nil)
        tool_class.instance_variable_set(:@__source, [])
        tool_class
      end

      ## @private
      def self.current_tool(tool_class, activate)
        memoize_var = activate ? :@__active_tool : :@__cur_tool
        if tool_class.instance_variable_defined?(memoize_var)
          cur_tool = tool_class.instance_variable_get(memoize_var)
        else
          loader = tool_class.instance_variable_get(:@__loader)
          words = tool_class.instance_variable_get(:@__words)
          priority = tool_class.instance_variable_get(:@__priority)
          cur_tool =
            if activate
              loader.activate_tool_definition(words, priority)
            else
              loader.get_tool_definition(words, priority)
            end
          if cur_tool.is_a?(Alias)
            raise ToolDefinitionError,
                  "Cannot configure #{words.join(' ').inspect} because it is an alias"
          end
          tool_class.instance_variable_set(memoize_var, cur_tool)
        end
        if cur_tool && activate
          source = tool_class.instance_variable_get(:@__source).last
          cur_tool.lock_source(source)
        end
        cur_tool
      end

      ## @private
      def self.prepare(tool_class, remaining_words, source)
        tool_class.instance_variable_set(:@__remaining_words, remaining_words)
        tool_class.instance_variable_get(:@__source).push(source)
        yield
      ensure
        tool_class.instance_variable_get(:@__source).pop
      end

      ## @private
      def self.maybe_add_getter(tool_class, key)
        if key.is_a?(::Symbol) && key.to_s =~ /^[_a-zA-Z]\w*[!\?]?$/
          tool_class.class_eval do
            define_method(key) do
              self[key]
            end
          end
        end
      end

      ## @private
      def self.resolve_mixin(mod, cur_tool, loader)
        name = mod.to_s
        if mod.is_a?(::String)
          mod = cur_tool.resolve_mixin(mod)
        elsif mod.is_a?(::Symbol)
          mod = loader.resolve_standard_mixin(name)
        end
        unless mod.is_a?(::Module)
          raise ToolDefinitionError, "Module not found: #{name.inspect}"
        end
        mod
      end
    end
  end
end
