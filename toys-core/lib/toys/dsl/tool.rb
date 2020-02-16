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
        DSL::Tool.current_tool(self, true)&.check_definition_state(is_method: true)
      end

      ##
      # Create a named acceptor that can be referenced by name from any flag or
      # positional argument in this tool or its subtools.
      #
      # An acceptor validates the string parameter passed to a flag or
      # positional argument. It also optionally converts the string to a
      # different object before storing it in your tool's data.
      #
      # Acceptors can be defined in one of four ways.
      #
      #  *  You can provide a **regular expression**. This acceptor validates
      #     only if the regex matches the *entire string parameter*.
      #
      #     You can also provide an optional conversion function as a block. If
      #     provided, function must take a variable number of arguments, the
      #     first being the matched string and the remainder being the captures
      #     from the regular expression. It should return the converted object
      #     that will be stored in the context data. If you do not provide a
      #     block, the original string will be used.
      #
      #  *  You can provide an **array** of possible values. The acceptor
      #     validates if the string parameter matches the *string form* of one
      #     of the array elements (i.e. the results of calling `to_s` on the
      #     array elements.)
      #
      #     An array acceptor automatically converts the string parameter to
      #     the actual array element that it matched. For example, if the
      #     symbol `:foo` is in the array, it will match the string `"foo"`,
      #     and then store the symbol `:foo` in the tool data.
      #
      #  *  You can provide a **range** of possible values, along with a
      #     conversion function that converts a string parameter to a type
      #     comparable by the range. (See the "function" spec below for a
      #     detailed description of conversion functions.) If the range has
      #     numeric endpoints, the conversion function is optional because a
      #     default will be provided.
      #
      #  *  You can provide a **function** by passing it as a proc or a block.
      #     This function performs *both* validation and conversion. It should
      #     take the string parameter as its argument, and it must either
      #     return the object that should be stored in the tool data, or raise
      #     an exception (descended from `StandardError`) to indicate that the
      #     string parameter is invalid.
      #
      # ## Example
      #
      # The following example creates an acceptor named "hex" that is defined
      # via a regular expression. It then uses it to validate values passed to
      # a flag.
      #
      #     tool "example" do
      #       acceptor "hex", /[0-9a-fA-F]+/, type_desc: "hex numbers"
      #       flag :number, accept: "hex"
      #       def run
      #         puts "number was #{number}"
      #       end
      #     end
      #
      # @param name [String] The acceptor name.
      # @param spec [Object] See the description for recognized values.
      # @param type_desc [String] Type description string, shown in help.
      #     Defaults to the acceptor name.
      # @param block [Proc] See the description for recognized forms.
      # @return [self]
      #
      def acceptor(name, spec = nil, type_desc: nil, &block)
        cur_tool = DSL::Tool.current_tool(self, false)
        cur_tool&.add_acceptor(name, spec, type_desc: type_desc || name.to_s, &block)
        self
      end

      ##
      # Create a named mixin module that can be included by name from this tool
      # or its subtools.
      #
      # A mixin is a module that defines methods that can be called from a
      # tool. It is commonly used to provide "utility" methods, implementing
      # common functionality and allowing tools to share code.
      #
      # Normally you provide a block and define the mixin's methods in that
      # block. Alternatively, you can create a module separately and pass it
      # directly to this directive.
      #
      # ## Example
      #
      # The following example creates a named mixin and uses it in a tool.
      #
      #     mixin "error-reporter" do
      #       def error message
      #         logger.error "An error occurred: #{message}"
      #         exit 1
      #       end
      #     end
      #
      #     tool "build" do
      #       include "error-reporter"
      #       def run
      #         puts "Building..."
      #         error "Build failed!"
      #       end
      #     end
      #
      # @param name [String] Name of the mixin
      # @param mixin_module [Module] Module to use as the mixin. Optional.
      #     Either pass a module here, *or* provide a block and define the
      #     mixin within the block.
      # @param block [Proc] Defines the mixin module.
      # @return [self]
      #
      def mixin(name, mixin_module = nil, &block)
        cur_tool = DSL::Tool.current_tool(self, false)
        cur_tool&.add_mixin(name, mixin_module, &block)
        self
      end

      ##
      # Create a named template that can be expanded by name from this tool
      # or its subtools.
      #
      # A template is an object that generates DSL directives. You can use it
      # to build "prefabricated" tools, and then instantiate them in your Toys
      # files. Generally, a template is a class with an associated `expansion`
      # procedure. The class defines parameters for the template expansion,
      # and `expansion` includes DSL directives that should be run based on
      # those parameters.
      #
      # Normally, you provide a block and define the template class in that
      # block. Most templates will define an `initialize` method that takes any
      # arguments passed into the template expansion. The template must also
      # provide an `expansion` block showing how to use the template object to
      # produce DSL directives.
      #
      # Alternately, you can create a template class separately and pass it
      # directly. See {Toys::Template} for details on creating a template
      # class.
      #
      # ## Example
      #
      # The following example creates and uses a simple template.
      #
      #     template "hello-generator" do
      #       def initialize(name, message)
      #         @name = name
      #         @message = message
      #       end
      #       attr_reader :name, :message
      #       expansion do |template|
      #         tool template.name do
      #           to_run do
      #             puts template.message
      #           end
      #         end
      #       end
      #     end
      #
      #     expand "hello-generator", "mytool", "mytool is running!"
      #
      # @param name [String] Name of the template
      # @param template_class [Class] Module to use as the mixin. Optional.
      #     Either pass a module here, *or* provide a block and define the
      #     mixin within the block.
      # @param block [Proc] Defines the template class.
      # @return [self]
      #
      def template(name, template_class = nil, &block)
        cur_tool = DSL::Tool.current_tool(self, false)
        return self if cur_tool.nil?
        cur_tool.add_template(name, template_class, &block)
        self
      end

      ##
      # Create a named completion procedure that may be used by name by any
      # flag or positional arg in this tool or any subtool.
      #
      # A completion controls tab completion for the value of a flag or
      # positional argument. In general, it is a Ruby `Proc` that takes a
      # context object (of type {Toys::Completion::Context}) and returns an
      # array of completion candidate strings.
      #
      # Completions can be specified in one of three ways.
      #
      #  *  A Proc object itself, either passed directly to this directive or
      #     provided as a block.
      #  *  A static array of strings, indicating the completion candidates
      #     independent of context.
      #  *  The symbol `:file_system` which indicates that paths in the file
      #     system should serve as completion candidates.
      #
      # ## Example
      #
      # The following example defines a completion that uses only the immediate
      # files in the current directory as candidates. (This is different from
      # the `:file_system` completion which will descend into subdirectories
      # similar to how bash completes most of its file system commands.)
      #
      #     completion "local-files" do |_context|
      #       `/bin/ls`.split("\n")
      #     end
      #     tool "example" do
      #       flag :file, complete_values: "local-files"
      #       def run
      #         puts "selected file #{file}"
      #       end
      #     end
      #
      # @param name [String] Name of the completion
      # @param spec [Object] See the description for recognized values.
      # @param options [Hash] Additional options to pass to the completion.
      # @param block [Proc] See the description for recognized forms.
      # @return [self]
      #
      def completion(name, spec = nil, **options, &block)
        cur_tool = DSL::Tool.current_tool(self, false)
        return self if cur_tool.nil?
        cur_tool.add_completion(name, spec, **options, &block)
        self
      end

      ##
      # Create a subtool. You must provide a block defining the subtool.
      #
      # ## Example
      #
      # The following example defines a tool and two subtools within it.
      #
      #     tool "build" do
      #       tool "staging" do
      #         def run
      #           puts "Building staging"
      #         end
      #       end
      #       tool "production" do
      #         def run
      #           puts "Building production"
      #         end
      #       end
      #     end
      #
      # The following example defines a tool that runs one of its subtools.
      #
      #     tool "test", runs: ["test", "unit"] do
      #       tool "unit" do
      #         def run
      #           puts "Running unit tests"
      #         end
      #       end
      #     end
      #
      # @param words [String,Array<String>] The name of the subtool
      # @param if_defined [:combine,:reset,:ignore] What to do if a definition
      #     already exists for this tool. Possible values are `:combine` (the
      #     default) indicating the definition should be combined with the
      #     existing definition, `:reset` indicating the earlier definition
      #     should be reset and the new definition applied instead, or
      #     `:ignore` indicating the new definition should be ignored.
      # @param delegate_to [String,Array<String>] Optional. This tool should
      #     delegate to another tool, specified by the full path. This path may
      #     be given as an array of strings, or a single string possibly
      #     delimited by path separators.
      # @param block [Proc] Defines the subtool.
      # @return [self]
      #
      def tool(words, if_defined: :combine, delegate_to: nil, &block)
        subtool_words = @__words.dup
        next_remaining = @__remaining_words
        @__loader.split_path(words).each do |word|
          word = word.to_s
          subtool_words << word
          next_remaining = Loader.next_remaining_words(next_remaining, word)
        end
        subtool = @__loader.get_tool(subtool_words, @__priority)
        if subtool.includes_definition?
          case if_defined
          when :ignore
            return self
          when :reset
            subtool.reset_definition(@__loader)
          end
        end
        if delegate_to
          delegator = proc { self.delegate_to(delegate_to) }
          @__loader.load_block(source_info, delegator, subtool_words, next_remaining, @__priority)
        end
        if block
          @__loader.load_block(source_info, block, subtool_words, next_remaining, @__priority)
        end
        self
      end
      alias name tool

      ##
      # Create an alias, representing an "alternate name" for a tool.
      #
      # This is functionally equivalent to creating a subtool with the
      # `delegate_to` option, except that `alias_tool` takes a _relative_ name
      # for the delegate.
      #
      # ## Example
      #
      # This example defines a tool and an alias pointing to it. Both the tool
      # name `test` and the alias `t` will then refer to the same tool.
      #
      #     tool "test" do
      #       def run
      #         puts "Running tests..."
      #       end
      #     end
      #     alias_tool "t", "test"
      #
      # @param word [String] The name of the alias
      # @param target [String,Array<String>] Relative path to the target of the
      #     alias. This path may be given as an array of strings, or a single
      #     string possibly delimited by path separators.
      # @return [self]
      #
      def alias_tool(word, target)
        tool(word, delegate_to: @__words + @__loader.split_path(target))
        self
      end

      ##
      # Causes the current tool to delegate to another tool. When run, it
      # simply invokes the target tool with the same arguments.
      #
      # ## Example
      #
      # This example defines a tool that runs one of its subtools. Running the
      # `test` tool will have the same effect (and recognize the same args) as
      # the subtool `test unit`.
      #
      #     tool "test" do
      #       tool "unit" do
      #         flag :faster
      #         def run
      #           puts "running tests..."
      #         end
      #       end
      #       delegate_to "test:unit"
      #     end
      #
      # @param target [String,Array<String>] The full path to the delegate
      #     tool. This path may be given as an array of strings, or a single
      #     string possibly delimited by path separators.
      # @return [self]
      #
      def delegate_to(target)
        cur_tool = DSL::Tool.current_tool(self, true)
        return self if cur_tool.nil?
        cur_tool.delegate_to(@__loader.split_path(target))
        self
      end

      ##
      # Load another config file or directory, as if its contents were inserted
      # at the current location.
      #
      # @param path [String] The file or directory to load.
      # @return [self]
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
      # ## Example
      #
      # The following example creates and uses a simple template.
      #
      #     template "hello-generator" do
      #       def initialize(name, message)
      #         @name = name
      #         @message = message
      #       end
      #       attr_reader :name, :message
      #       expansion do |template|
      #         tool template.name do
      #           to_run do
      #             puts template.message
      #           end
      #         end
      #       end
      #     end
      #
      #     expand "hello-generator", "mytool", "mytool is running!"
      #
      # @param template_class [Class,String,Symbol] The template, either as a
      #     class or a well-known name.
      # @param args [Object...] Template arguments
      # @return [self]
      #
      def expand(template_class, *args, **kwargs)
        cur_tool = DSL::Tool.current_tool(self, false)
        return self if cur_tool.nil?
        name = template_class.to_s
        if template_class.is_a?(::String)
          template_class = cur_tool.lookup_template(template_class)
        elsif template_class.is_a?(::Symbol)
          template_class = @__loader.resolve_standard_template(name)
        end
        if template_class.nil?
          raise ToolDefinitionError, "Template not found: #{name.inspect}"
        end
        template = Compat.instantiate(template_class, args, kwargs, nil)
        yield template if block_given?
        class_exec(template, &template_class.expansion)
        self
      end

      ##
      # Set the short description for the current tool. The short description
      # is displayed with the tool in a subtool list. You may also use the
      # equivalent method `short_desc`.
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
      # @param str [Toys::WrappableString,String,Array<String>]
      # @return [self]
      #
      def desc(str)
        cur_tool = DSL::Tool.current_tool(self, true)
        return self if cur_tool.nil?
        cur_tool.desc = str
        self
      end
      alias short_desc desc

      ##
      # Add to the long description for the current tool. The long description
      # is displayed in the usage documentation for the tool itself. This
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
      # @param strs [Toys::WrappableString,String,Array<String>...]
      # @param file [String] Optional. Read the description from the given file
      #     provided relative to the current toys file. The file must be a
      #     plain text file whose suffix is `.txt`.
      # @param data [String] Optional. Read the description from the given data
      #     file. The file must be a plain text file whose suffix is `.txt`.
      # @return [self]
      #
      def long_desc(*strs, file: nil, data: nil)
        cur_tool = DSL::Tool.current_tool(self, true)
        return self if cur_tool.nil?
        if file
          unless source_info.source_path
            raise ::Toys::ToolDefinitionError,
                  "Cannot set long_desc from a file because the tool is not defined in a file"
          end
          file = ::File.join(::File.dirname(source_info.source_path), file)
        elsif data
          file = source_info.find_data(data, type: :file)
        end
        strs += DSL::Tool.load_long_desc_file(file) if file
        cur_tool.append_long_desc(strs)
        self
      end

      ##
      # Create a flag group. If a block is given, flags defined in the block
      # belong to the group. The flags in the group are listed together in
      # help screens.
      #
      # ## Example
      #
      # The following example creates a flag group in which all flags are
      # optional.
      #
      #     tool "execute" do
      #       flag_group desc: "Debug Flags" do
      #         flag :debug, "-D", desc: "Enable debugger"
      #         flag :warnings, "-W[VAL]", desc: "Enable warnings"
      #       end
      #       # ...
      #     end
      #
      # @param type [Symbol] The type of group. Allowed values: `:required`,
      #     `:optional`, `:exactly_one`, `:at_most_one`, `:at_least_one`.
      #     Default is `:optional`.
      # @param desc [String,Array<String>,Toys::WrappableString] Short
      #     description for the group. See {Toys::Tool#desc=} for a description
      #     of allowed formats. Defaults to `"Flags"`.
      # @param long_desc [Array<String,Array<String>,Toys::WrappableString>]
      #     Long description for the flag group. See
      #     {Toys::Tool#long_desc=} for a description of allowed formats.
      #     Defaults to the empty array.
      # @param name [String,Symbol,nil] The name of the group, or nil for no
      #     name.
      # @param report_collisions [Boolean] If `true`, raise an exception if a
      #     the given name is already taken. If `false`, ignore. Default is
      #     `true`.
      # @param prepend [Boolean] If `true`, prepend rather than append the
      #     group to the list. Default is `false`.
      # @param block [Proc] Adds flags to the group. See {Toys::DSL::FlagGroup}
      #     for the directives that can be called in this block.
      # @return [self]
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
      # ## Example
      #
      # The following example creates a group of required flags.
      #
      #     tool "login" do
      #       all_required do
      #         flag :username, "--username=VAL", desc: "Set username (required)"
      #         flag :password, "--password=VAL", desc: "Set password (required)"
      #       end
      #       # ...
      #     end
      #
      # @param desc [String,Array<String>,Toys::WrappableString] Short
      #     description for the group. See {Toys::Tool#desc=} for a description
      #     of allowed formats. Defaults to `"Flags"`.
      # @param long_desc [Array<String,Array<String>,Toys::WrappableString>]
      #     Long description for the flag group. See
      #     {Toys::Tool#long_desc=} for a description of allowed formats.
      #     Defaults to the empty array.
      # @param name [String,Symbol,nil] The name of the group, or nil for no
      #     name.
      # @param report_collisions [Boolean] If `true`, raise an exception if a
      #     the given name is already taken. If `false`, ignore. Default is
      #     `true`.
      # @param prepend [Boolean] If `true`, prepend rather than append the
      #     group to the list. Default is `false`.
      # @param block [Proc] Adds flags to the group. See {Toys::DSL::FlagGroup}
      #     for the directives that can be called in this block.
      # @return [self]
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
      # ## Example
      #
      # The following example creates a group of flags in which either one or
      # none may be set, but not more than one.
      #
      #     tool "provision-server" do
      #       at_most_one do
      #         flag :restore_from_backup, "--restore-from-backup=VAL"
      #         flag :restore_from_image, "--restore-from-image=VAL"
      #         flag :clone_existing, "--clone-existing=VAL"
      #       end
      #       # ...
      #     end
      #
      # @param desc [String,Array<String>,Toys::WrappableString] Short
      #     description for the group. See {Toys::Tool#desc=} for a description
      #     of allowed formats. Defaults to `"Flags"`.
      # @param long_desc [Array<String,Array<String>,Toys::WrappableString>]
      #     Long description for the flag group. See
      #     {Toys::Tool#long_desc=} for a description of allowed formats.
      #     Defaults to the empty array.
      # @param name [String,Symbol,nil] The name of the group, or nil for no
      #     name.
      # @param report_collisions [Boolean] If `true`, raise an exception if a
      #     the given name is already taken. If `false`, ignore. Default is
      #     `true`.
      # @param prepend [Boolean] If `true`, prepend rather than append the
      #     group to the list. Default is `false`.
      # @param block [Proc] Adds flags to the group. See {Toys::DSL::FlagGroup}
      #     for the directives that can be called in this block.
      # @return [self]
      #
      def at_most_one(desc: nil, long_desc: nil, name: nil, report_collisions: true,
                      prepend: false, &block)
        flag_group(type: :at_most_one, desc: desc, long_desc: long_desc,
                   name: name, report_collisions: report_collisions, prepend: prepend, &block)
      end
      alias at_most_one_required at_most_one

      ##
      # Create a flag group of type `:at_least_one`. If a block is given, flags
      # defined in the block belong to the group. At least one flag in this
      # group must be provided on the command line.
      #
      # ## Example
      #
      # The following example creates a group of flags in which one or more
      # may be set.
      #
      #     tool "run-tests" do
      #       at_least_one do
      #         flag :unit, desc: "Run unit tests"
      #         flag :integration, desc: "Run integration tests"
      #         flag :performance, desc: "Run performance tests"
      #       end
      #       # ...
      #     end
      #
      # @param desc [String,Array<String>,Toys::WrappableString] Short
      #     description for the group. See {Toys::Tool#desc=} for a description
      #     of allowed formats. Defaults to `"Flags"`.
      # @param long_desc [Array<String,Array<String>,Toys::WrappableString>]
      #     Long description for the flag group. See
      #     {Toys::Tool#long_desc=} for a description of allowed formats.
      #     Defaults to the empty array.
      # @param name [String,Symbol,nil] The name of the group, or nil for no
      #     name.
      # @param report_collisions [Boolean] If `true`, raise an exception if a
      #     the given name is already taken. If `false`, ignore. Default is
      #     `true`.
      # @param prepend [Boolean] If `true`, prepend rather than append the
      #     group to the list. Default is `false`.
      # @param block [Proc] Adds flags to the group. See {Toys::DSL::FlagGroup}
      #     for the directives that can be called in this block.
      # @return [self]
      #
      def at_least_one(desc: nil, long_desc: nil, name: nil, report_collisions: true,
                       prepend: false, &block)
        flag_group(type: :at_least_one, desc: desc, long_desc: long_desc,
                   name: name, report_collisions: report_collisions, prepend: prepend, &block)
      end
      alias at_least_one_required at_least_one

      ##
      # Create a flag group of type `:exactly_one`. If a block is given, flags
      # defined in the block belong to the group. Exactly one flag in this
      # group must be provided on the command line.
      #
      # ## Example
      #
      # The following example creates a group of flags in which exactly one
      # must be set.
      #
      #     tool "deploy" do
      #       exactly_one do
      #         flag :server, "--server=IP_ADDR", desc: "Deploy to server"
      #         flag :vm, "--vm=ID", desc: "Deploy to a VM"
      #         flag :container, "--container=ID", desc: "Deploy to a container"
      #       end
      #       # ...
      #     end
      #
      # @param desc [String,Array<String>,Toys::WrappableString] Short
      #     description for the group. See {Toys::Tool#desc=} for a description
      #     of allowed formats. Defaults to `"Flags"`.
      # @param long_desc [Array<String,Array<String>,Toys::WrappableString>]
      #     Long description for the flag group. See
      #     {Toys::Tool#long_desc=} for a description of allowed formats.
      #     Defaults to the empty array.
      # @param name [String,Symbol,nil] The name of the group, or nil for no
      #     name.
      # @param report_collisions [Boolean] If `true`, raise an exception if a
      #     the given name is already taken. If `false`, ignore. Default is
      #     `true`.
      # @param prepend [Boolean] If `true`, prepend rather than append the
      #     group to the list. Default is `false`.
      # @param block [Proc] Adds flags to the group. See {Toys::DSL::FlagGroup}
      #     for the directives that can be called in this block.
      # @return [self]
      #
      def exactly_one(desc: nil, long_desc: nil, name: nil, report_collisions: true,
                      prepend: false, &block)
        flag_group(type: :exactly_one, desc: desc, long_desc: long_desc,
                   name: name, report_collisions: report_collisions, prepend: prepend, &block)
      end
      alias exactly_one_required exactly_one

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
      # ## Flag syntax
      #
      # The flags themselves should be provided in OptionParser form. Following
      # are examples of valid syntax.
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
      #     value even if it looks like a flag (e.g. `--abc --abc` causes the
      #     string `"--abc"` to be taken as the value.)
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
      # @param group [Toys::FlagGroup,String,Symbol,nil] Group for this flag.
      #     You may provide a group name, a FlagGroup object, or `nil` which
      #     denotes the default group.
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
               accept: nil, default: nil, handler: nil,
               complete_flags: nil, complete_values: nil,
               report_collisions: true, group: nil,
               desc: nil, long_desc: nil, display_name: nil,
               &block)
        cur_tool = DSL::Tool.current_tool(self, true)
        return self if cur_tool.nil?
        flag_dsl = DSL::Flag.new(
          flags.flatten, accept, default, handler, complete_flags, complete_values,
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
      # use directives in {Toys::DSL::PositionalArg} within the block.
      #
      # ## Example
      #
      # This tool "moves" something from a source to destination, and takes two
      # required arguments:
      #
      #     tool "mv" do
      #       required_arg :source
      #       required_arg :dest
      #       def run
      #         puts "moving from #{source} to #{dest}..."
      #       end
      #     end
      #
      # @param key [String,Symbol] The key to use to retrieve the value from
      #     the execution context.
      # @param accept [Object] An acceptor that validates and/or converts the
      #     value. You may provide either the name of an acceptor you have
      #     defined, or one of the default acceptors provided by OptionParser.
      #     Optional. If not specified, accepts any value as a string.
      # @param complete [Object] A specifier for shell tab completion for
      #     values of this arg. This is the empty completion by default. To
      #     customize completion, set this to the name of a previously defined
      #     completion, or any spec recognized by {Toys::Completion.create}.
      # @param display_name [String] A name to use for display (in help text and
      #     error reports). Defaults to the key in upper case.
      # @param desc [String,Array<String>,Toys::WrappableString] Short
      #     description for the flag. See {Toys::DSL::Tool#desc} for a
      #     description of the allowed formats. Defaults to the empty string.
      # @param long_desc [Array<String,Array<String>,Toys::WrappableString>]
      #     Long description for the flag. See {Toys::DSL::Tool#long_desc} for
      #     a description of the allowed formats. (But note that this param
      #     takes an Array of description lines, rather than a series of
      #     arguments.) Defaults to the empty array.
      # @param block [Proc] Configures the positional argument. See
      #     {Toys::DSL::PositionalArg} for the directives that can be called in
      #     this block.
      # @return [self]
      #
      def required_arg(key,
                       accept: nil, complete: nil, display_name: nil,
                       desc: nil, long_desc: nil,
                       &block)
        cur_tool = DSL::Tool.current_tool(self, true)
        return self if cur_tool.nil?
        arg_dsl = DSL::PositionalArg.new(accept, nil, complete, display_name, desc, long_desc)
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
      # use directives in {Toys::DSL::PositionalArg} within the block.
      #
      # ## Example
      #
      # This tool creates a "link" to a given target. The link location is
      # optional; if it is not given, it is inferred from the target.
      #
      #     tool "ln" do
      #       required_arg :target
      #       optional_arg :location
      #       def run
      #         loc = location || File.basename(target)
      #         puts "linking to #{target} from #{loc}..."
      #       end
      #     end
      #
      # @param key [String,Symbol] The key to use to retrieve the value from
      #     the execution context.
      # @param default [Object] The default value. This is the value that will
      #     be set in the context if this argument is not provided on the command
      #     line. Defaults to `nil`.
      # @param accept [Object] An acceptor that validates and/or converts the
      #     value. You may provide either the name of an acceptor you have
      #     defined, or one of the default acceptors provided by OptionParser.
      #     Optional. If not specified, accepts any value as a string.
      # @param complete [Object] A specifier for shell tab completion for
      #     values of this arg. This is the empty completion by default. To
      #     customize completion, set this to the name of a previously defined
      #     completion, or any spec recognized by {Toys::Completion.create}.
      # @param display_name [String] A name to use for display (in help text and
      #     error reports). Defaults to the key in upper case.
      # @param desc [String,Array<String>,Toys::WrappableString] Short
      #     description for the flag. See {Toys::DSL::Tool#desc} for a
      #     description of the allowed formats. Defaults to the empty string.
      # @param long_desc [Array<String,Array<String>,Toys::WrappableString>]
      #     Long description for the flag. See {Toys::DSL::Tool#long_desc} for
      #     a description of the allowed formats. (But note that this param
      #     takes an Array of description lines, rather than a series of
      #     arguments.) Defaults to the empty array.
      # @param block [Proc] Configures the positional argument. See
      #     {Toys::DSL::PositionalArg} for the directives that can be called in
      #     this block.
      # @return [self]
      #
      def optional_arg(key,
                       default: nil, accept: nil, complete: nil, display_name: nil,
                       desc: nil, long_desc: nil,
                       &block)
        cur_tool = DSL::Tool.current_tool(self, true)
        return self if cur_tool.nil?
        arg_dsl = DSL::PositionalArg.new(accept, default, complete, display_name, desc, long_desc)
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
      # use directives in {Toys::DSL::PositionalArg} within the block.
      #
      # ## Example
      #
      # This tool displays a "list" of the given directories. If no directories
      # ar given, lists the current directory.
      #
      #     tool "ln" do
      #       remaining_args :directories
      #       def run
      #         dirs = directories.empty? ? [Dir.pwd] : directories
      #         dirs.each do |dir|
      #           puts "Listing directory #{dir}..."
      #         end
      #       end
      #     end
      #
      # @param key [String,Symbol] The key to use to retrieve the value from
      #     the execution context.
      # @param default [Object] The default value. This is the value that will
      #     be set in the context if no unmatched arguments are provided on the
      #     command line. Defaults to the empty array `[]`.
      # @param accept [Object] An acceptor that validates and/or converts the
      #     value. You may provide either the name of an acceptor you have
      #     defined, or one of the default acceptors provided by OptionParser.
      #     Optional. If not specified, accepts any value as a string.
      # @param complete [Object] A specifier for shell tab completion for
      #     values of this arg. This is the empty completion by default. To
      #     customize completion, set this to the name of a previously defined
      #     completion, or any spec recognized by {Toys::Completion.create}.
      # @param display_name [String] A name to use for display (in help text and
      #     error reports). Defaults to the key in upper case.
      # @param desc [String,Array<String>,Toys::WrappableString] Short
      #     description for the flag. See {Toys::DSL::Tool#desc} for a
      #     description of the allowed formats. Defaults to the empty string.
      # @param long_desc [Array<String,Array<String>,Toys::WrappableString>]
      #     Long description for the flag. See {Toys::DSL::Tool#long_desc} for
      #     a description of the allowed formats. (But note that this param
      #     takes an Array of description lines, rather than a series of
      #     arguments.) Defaults to the empty array.
      # @param block [Proc] Configures the positional argument. See
      #     {Toys::DSL::PositionalArg} for the directives that can be called in
      #     this block.
      # @return [self]
      #
      def remaining_args(key,
                         default: [], accept: nil, complete: nil, display_name: nil,
                         desc: nil, long_desc: nil,
                         &block)
        cur_tool = DSL::Tool.current_tool(self, true)
        return self if cur_tool.nil?
        arg_dsl = DSL::PositionalArg.new(accept, default, complete, display_name, desc, long_desc)
        arg_dsl.instance_exec(arg_dsl, &block) if block
        arg_dsl._set_remaining_on(cur_tool, key)
        DSL::Tool.maybe_add_getter(self, key)
        self
      end
      alias remaining remaining_args

      ##
      # Set a option values statically and create a helper method.
      #
      # If any given key is a symbol representing a valid method name, then a
      # helper method is automatically added to retrieve the value. Otherwise,
      # if the key is a string or does not represent a valid method name, the
      # tool can retrieve the value by calling {Toys::Context#get}.
      #
      # ## Example
      #
      #     tool "hello" do
      #       static :greeting, "Hi there"
      #       def run
      #         puts "#{greeting}, world!"
      #       end
      #     end
      #
      # @overload static(key, value)
      #   Set a single value by key.
      #   @param key [String,Symbol] The key to use to retrieve the value from
      #       the execution context.
      #   @param value [Object] The value to set.
      #   @return [self]
      #
      # @overload static(hash)
      #   Set multiple keys and values
      #   @param hash [Hash] The keys and values to set
      #   @return [self]
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
      # Set a option values statically without creating helper methods.
      #
      # ## Example
      #
      #     tool "hello" do
      #       set :greeting, "Hi there"
      #       def run
      #         puts "#{get(:greeting)}, world!"
      #       end
      #     end
      #
      # @overload set(key, value)
      #   Set a single value by key.
      #   @param key [String,Symbol] The key to use to retrieve the value from
      #       the execution context.
      #   @param value [Object] The value to set.
      #   @return [self]
      #
      # @overload set(hash)
      #   Set multiple keys and values
      #   @param hash [Hash] The keys and values to set
      #   @return [self]
      #
      def set(key, value = nil)
        cur_tool = DSL::Tool.current_tool(self, true)
        return self if cur_tool.nil?
        if key.is_a?(::Hash)
          cur_tool.default_data.merge!(key)
        else
          cur_tool.default_data[key] = value
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
      # @param state [Boolean]
      # @return [self]
      #
      def enforce_flags_before_args(state = true)
        DSL::Tool.current_tool(self, true)&.enforce_flags_before_args(state)
        self
      end

      ##
      # Require that flags must match exactly. That is, flags must appear in
      # their entirety on the command line. (If false, substrings of flags are
      # accepted as long as they are unambiguous.)
      #
      # Issuing this directive by itself turns on exact match. You may turn it
      # off by passsing `false` as the parameter.
      #
      # @param state [Boolean]
      # @return [self]
      #
      def require_exact_flag_match(state = true)
        DSL::Tool.current_tool(self, true)&.require_exact_flag_match(state)
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
      # @return [self]
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
      # ## Example
      #
      # This tool does not support the `-v` and `-q` short forms for the two
      # verbosity flags (although it still supports the long forms `--verbose`
      # and `--quiet`.)
      #
      #     tool "mytool" do
      #       disable_flag "-v", "-q"
      #       def run
      #         # ...
      #       end
      #     end
      #
      # @param flags [String...] The flags to disable
      # @return [self]
      #
      def disable_flag(*flags)
        DSL::Tool.current_tool(self, true)&.disable_flag(*flags)
        self
      end

      ##
      # Set the shell completion strategy for this tool's arguments.
      # You can pass one of the following:
      #
      #  *  The string name of a completion defined in this tool or any of its
      #     its ancestors.
      #  *  A hash of options to pass to the constructor of
      #     {Toys::Tool::DefaultCompletion}.
      #  *  `nil` or `:default` to select the standard completion strategy
      #     (which is {Toys::Tool::DefaultCompletion} with no extra options).
      #  *  Any other specification recognized by {Toys::Completion.create}.
      #
      # ## Example
      #
      # The namespace "foo" supports completion only of subtool names. It does
      # not complete the standard flags (like --help).
      #
      #     tool "foo" do
      #       complete_tool_args complete_args: false, complete_flags: false,
      #                          complete_flag_values: false
      #       tool "bar" do
      #         def run
      #           puts "in foo bar"
      #         end
      #       end
      #     end
      #
      # @param spec [Object]
      # @param options [Hash]
      # @param block [Proc]
      # @return [self]
      #
      def complete_tool_args(spec = nil, **options, &block)
        cur_tool = DSL::Tool.current_tool(self, true)
        return self if cur_tool.nil?
        cur_tool.completion = Completion.scalarize_spec(spec, options, block)
        self
      end

      ##
      # Specify how to run this tool. Typically you do this by defining a
      # method namd `run`. Alternatively, however, you can pass a block to the
      # `to_run` method.
      #
      # You may want to do this if your method needs access to local variables
      # in the lexical scope. However, it is often more convenient to use
      # {#static} to set the value in the context.)
      #
      # ## Example
      #
      #     tool "foo" do
      #       cur_time = Time.new
      #       to_run do
      #         puts "The time at tool definition was #{cur_time}"
      #       end
      #     end
      #
      # @param block [Proc] The run method.
      # @return [self]
      #
      def to_run(&block)
        define_method(:run, &block)
        self
      end
      alias on_run to_run

      ##
      # Specify how to handle interrupts.
      #
      # You may pass a block to be called, or the name of a method to call. In
      # either case, the block or method should take one argument, the
      # Interrupt exception that was raised.
      #
      # ## Example
      #
      #     tool "foo" do
      #       def run
      #         sleep 10
      #       end
      #       on_interrupt do |e|
      #         puts "I was interrupted."
      #       end
      #     end
      #
      # @param handler [Proc,Symbol,nil] The interrupt callback proc or method
      #     name. Pass nil to disable interrupt handling.
      # @param block [Proc] The interrupt callback as a block.
      # @return [self]
      #
      def on_interrupt(handler = nil, &block)
        cur_tool = DSL::Tool.current_tool(self, true)
        return self if cur_tool.nil?
        cur_tool.interrupt_handler = handler || block
        self
      end

      ##
      # Specify how to handle usage errors.
      #
      # You may pass a block to be called, or the name of a method to call. In
      # either case, the block or method should take one argument, the array of
      # usage errors reported.
      #
      # ## Example
      #
      # This tool runs even if a usage error is encountered. You can find info
      # on the errors from {Toys::Context::Key::USAGE_ERRORS},
      # {Toys::Context::Key::UNMATCHED_ARGS}, and similar keys.
      #
      #     tool "foo" do
      #       def run
      #         puts "Errors: #{usage_errors.join("\n")}"
      #       end
      #       on_usage_error :run
      #     end
      #
      # @param handler [Proc,Symbol,nil] The interrupt callback proc or method
      #     name. Pass nil to disable interrupt handling.
      # @param block [Proc] The interrupt callback as a block.
      # @return [self]
      #
      def on_usage_error(handler = nil, &block)
        cur_tool = DSL::Tool.current_tool(self, true)
        return self if cur_tool.nil?
        cur_tool.usage_error_handler = handler || block
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
      # ## Example
      #
      # Include the well-known mixin `:terminal` and perform some terminal
      # magic.
      #
      #     tool "spin" do
      #       include :terminal
      #       def run
      #         # The spinner method is defined by the :terminal mixin.
      #         spinner(leading_text: "Waiting...", final_text: "\n") do
      #           sleep 5
      #         end
      #       end
      #     end
      #
      # @param mod [Module,Symbol,String] Module or module name.
      # @param args [Object...] Arguments to pass to the initializer
      # @param kwargs [keywords] Keyword arguments to pass to the initializer
      # @return [self]
      #
      def include(mod, *args, **kwargs)
        cur_tool = DSL::Tool.current_tool(self, true)
        return self if cur_tool.nil?
        mod = DSL::Tool.resolve_mixin(mod, cur_tool, @__loader)
        if included_modules.include?(mod)
          raise ToolDefinitionError, "Mixin already included: #{mod.name}"
        end
        cur_tool.mark_includes_modules
        super(mod)
        if mod.respond_to?(:initializer)
          callback = mod.initializer
          cur_tool.add_initializer(callback, *args, **kwargs) if callback
        end
        if mod.respond_to?(:inclusion)
          callback = mod.inclusion
          class_exec(*args, **kwargs, &callback) if callback
        end
        self
      end

      ##
      # Determine if the given module/mixin has already been included.
      #
      # You may provide either a module, the string name of a mixin that you
      # have defined in this tool or one of its ancestors, or the symbol name
      # of a well-known mixin.
      #
      # @param mod [Module,Symbol,String] Module or module name.
      #
      # @return [Boolean] Whether the mixin is included
      # @return [nil] if the current tool is not active.
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
      # Find the given data path (file or directory).
      #
      # Data directories are a convenient place to put images, archives, keys,
      # or other such static data needed by your tools. Data files are located
      # in a directory called `.data` inside a Toys directory. This directive
      # locates a data file during tool definition.
      #
      # ## Example
      #
      # This tool reads its description from a text file in the `.data`
      # directory.
      #
      #     tool "mytool" do
      #       path = find_data("mytool-desc.txt", type: :file)
      #       desc IO.read(path) if path
      #       def run
      #         # ...
      #       end
      #     end
      #
      # @param path [String] The path to find
      # @param type [nil,:file,:directory] Type of file system object to find.
      #     Default is `nil`, indicating any type.
      #
      # @return [String] Absolute path of the data.
      # @return [nil] if the given data path is not found.
      #
      def find_data(path, type: nil)
        source_info.find_data(path, type: type)
      end

      ##
      # Return the context directory for this tool. Generally, this defaults
      # to the directory containing the toys config directory structure being
      # read, but it may be changed by setting a different context directory
      # for the tool.
      #
      # @return [String] Context directory path
      # @return [nil] if there is no context.
      #
      def context_directory
        DSL::Tool.current_tool(self, false)&.context_directory || source_info.context_directory
      end

      ##
      # Return the current tool object. This object can be queried to determine
      # such information as the name, but it should not be altered.
      #
      # @return [Toys::Tool]
      #
      def current_tool
        DSL::Tool.current_tool(self, false)
      end

      ##
      # Set a custom context directory for this tool.
      #
      # @param dir [String] Context directory
      # @return [self]
      #
      def set_context_directory(dir) # rubocop:disable Naming/AccessorMethodName
        cur_tool = DSL::Tool.current_tool(self, false)
        return self if cur_tool.nil?
        cur_tool.custom_context_directory = dir
        self
      end

      ##
      # Applies the given block to all subtools, recursively. Effectively, the
      # given block is run at the *end* of every tool block. This can be used,
      # for example, to provide some shared configuration for all tools.
      #
      # The block is applied only to subtools defined *after* the block
      # appears. Subtools defined before the block appears are not affected.
      #
      # ## Example
      #
      # It is common for tools to use the `:exec` mixin to invoke external
      # programs. This example automatically includes the exec mixin in all
      # subtools, recursively, so you do not have to repeat the `include`
      # directive in every tool.
      #
      #     # .toys.rb
      #
      #     subtool_apply do
      #       # Include the mixin only if the tool hasn't already done so
      #       unless include?(:exec)
      #         include :exec, exit_on_nonzero_status: true
      #       end
      #     end
      #
      #     tool "foo" do
      #       def run
      #         # This tool has access to methods defined by the :exec mixin
      #         # because the above block is applied to the tool.
      #         sh "echo hello"
      #       end
      #     end
      #
      def subtool_apply(&block)
        cur_tool = DSL::Tool.current_tool(self, false)
        return self if cur_tool.nil?
        cur_tool.subtool_middleware_stack.add(:apply_config,
                                              parent_source: source_info, &block)
        self
      end

      ##
      # Determines whether the current Toys version satisfies the given
      # requirements.
      #
      # @return [Boolean] whether or not the requirements are satisfied
      #
      def toys_version?(*requirements)
        require "rubygems"
        version = ::Gem::Version.new(Core::VERSION)
        requirement = ::Gem::Requirement.new(*requirements)
        requirement.satisfied_by?(version)
      end

      ##
      # Asserts that the current Toys version against the given requirements,
      # raising an exception if not.
      #
      # @return [self]
      #
      # @raise [Toys::ToolDefinitionError] if the current Toys version does not
      #     satisfy the requirements.
      #
      def toys_version!(*requirements)
        require "rubygems"
        version = ::Gem::Version.new(Core::VERSION)
        requirement = ::Gem::Requirement.new(*requirements)
        unless requirement.satisfied_by?(version)
          raise Toys::ToolDefinitionError,
                "Toys version requirements #{requirement} not satisfied by {version}"
        end
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
          tool_class.instance_variable_get(memoize_var)
        else
          loader = tool_class.instance_variable_get(:@__loader)
          words = tool_class.instance_variable_get(:@__words)
          priority = tool_class.instance_variable_get(:@__priority)
          cur_tool =
            if activate
              loader.activate_tool(words, priority)
            else
              loader.get_tool(words, priority)
            end
          if cur_tool && activate
            source = tool_class.instance_variable_get(:@__source).last
            cur_tool.lock_source(source)
          end
          tool_class.instance_variable_set(memoize_var, cur_tool)
        end
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
        if key.is_a?(::Symbol) && key.to_s =~ /^[_a-zA-Z]\w*[!\?]?$/ && key != :run
          unless tool_class.public_method_defined?(key)
            tool_class.class_eval do
              define_method(key) do
                self[key]
              end
            end
          end
        end
      end

      ## @private
      def self.resolve_mixin(mod, cur_tool, loader)
        name = mod.to_s
        if mod.is_a?(::String)
          mod = cur_tool.lookup_mixin(mod)
        elsif mod.is_a?(::Symbol)
          mod = loader.resolve_standard_mixin(name)
        end
        unless mod.is_a?(::Module)
          raise ToolDefinitionError, "Module not found: #{name.inspect}"
        end
        mod
      end

      ## @private
      def self.load_long_desc_file(path)
        if ::File.extname(path) == ".txt"
          begin
            ::File.readlines(path).map do |line|
              line = line.chomp
              line =~ /^\s/ ? [line] : line
            end
          rescue ::SystemCallError => e
            raise Toys::ToolDefinitionError, e.to_s
          end
        else
          raise Toys::ToolDefinitionError, "Cannot load long desc from file type: #{path}"
        end
      end
    end
  end
end
