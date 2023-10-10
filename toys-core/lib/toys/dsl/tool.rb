# frozen_string_literal: true

module Toys
  module DSL
    ##
    # This module defines the DSL for a Toys configuration file.
    #
    # A Toys configuration defines one or more named tools. It provides syntax
    # for setting the description, defining flags and arguments, specifying
    # how to execute the tool, and requesting mixin modules and other services.
    # It also lets you define subtools, nested arbitrarily deep, using blocks.
    #
    # ### Simple example
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
    # The DSL directives `tool`, `desc`, `optional_arg`, and others are defined
    # in this module.
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
      # ### Example
      #
      # The following example creates an acceptor named "hex" that is defined
      # via a regular expression. It uses the acceptor to validate values
      # passed to a flag.
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
        cur_tool = DSL::Internal.current_tool(self, false)
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
      # ### Example
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
        cur_tool = DSL::Internal.current_tool(self, false)
        cur_tool&.add_mixin(name, mixin_module, &block)
        self
      end

      ##
      # Create a named template that can be expanded by name from this tool
      # or its subtools.
      #
      # A template is an object that generates DSL directives. You can use it
      # to build "prefabricated" tools, and then instantiate them in your Toys
      # files.
      #
      # A template is an object that defines an `expansion` procedure. This
      # procedure generates the DSL directives implemented by the template. The
      # template object typically also includes attributes that are used to
      # configure the expansion.
      #
      # The simplest way to define a template is to pass a block to the
      # {#template} directive. In the block, define an `initialize` method that
      # accepts any arguments that may be passed to the template when it is
      # instantiated and are used to configure the template. Define
      # `attr_reader`s or other methods to make this configuration accessible
      # from the object. Then define an `on_expand` block that implements the
      # template's expansion. The template object is passed as an object to the
      # `on_expand` block.
      #
      # Alternately, you can create a template class separately and pass it
      # directly. See {Toys::Template} for details on creating a template
      # class.
      #
      # ### Example
      #
      # The following example creates and uses a simple template. The template
      # defines a tool, with a configurable name, that simply prints out a
      # configurable message.
      #
      #     template "hello-generator" do
      #       def initialize(name, message)
      #         @name = name
      #         @message = message
      #       end
      #       attr_reader :name, :message
      #       on_expand do |template|
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
        cur_tool = DSL::Internal.current_tool(self, false)
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
      # ### Example
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
        cur_tool = DSL::Internal.current_tool(self, false)
        return self if cur_tool.nil?
        cur_tool.add_completion(name, spec, **options, &block)
        self
      end

      ##
      # Create a subtool. You must provide a block defining the subtool.
      #
      # ### Example
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
      # The following example uses `delegate_to` to define a tool that runs one
      # of its subtools.
      #
      #     tool "test", delegate_to: ["test", "unit"] do
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
      # @param delegate_relative [String,Array<String>] Optional. Similar to
      #     delegate_to, but takes a delegate name relative to the context in
      #     which this tool is being defined.
      # @param block [Proc] Defines the subtool.
      # @return [self]
      #
      def tool(words, if_defined: :combine, delegate_to: nil, delegate_relative: nil, &block)
        subtool_words, next_remaining = DSL::Internal.analyze_name(self, words)
        subtool = @__loader.get_tool(subtool_words, @__priority)
        if subtool.includes_definition?
          case if_defined
          when :ignore
            return self
          when :reset
            subtool.reset_definition
          end
        end
        if delegate_to || delegate_relative
          delegate_to2 = @__words + @__loader.split_path(delegate_relative) if delegate_relative
          orig_block = block
          block = proc do
            self.delegate_to(delegate_to) if delegate_to
            self.delegate_to(delegate_to2) if delegate_to2
            instance_eval(&orig_block) if orig_block
          end
        end
        if block
          @__loader.load_block(source_info, block, subtool_words, next_remaining, @__priority)
        end
        self
      end

      ##
      # Create an alias, representing an "alternate name" for a tool.
      #
      # Note: This is functionally equivalent to creating a tool with the
      # `:delegate_relative` option. As such, `alias_tool` is considered
      # deprecated.
      #
      # ### Example
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
      #     # Note: the following is preferred over alias_tool:
      #     # tool "t", delegate_relative: "test"
      #
      # @param word [String] The name of the alias
      # @param target [String,Array<String>] Relative path to the target of the
      #     alias. This path may be given as an array of strings, or a single
      #     string possibly delimited by path separators.
      # @return [self]
      # @deprecated Use {#tool} and pass `:delegate_relative` instead
      #
      def alias_tool(word, target)
        tool(word, delegate_relative: target)
        self
      end

      ##
      # Causes the current tool to delegate to another tool, specified by the
      # full tool name. When run, it simply invokes the target tool with the
      # same arguments.
      #
      # ### Example
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
        cur_tool = DSL::Internal.current_tool(self, true)
        return self if cur_tool.nil?
        cur_tool.delegate_to(@__loader.split_path(target))
        self
      end

      ##
      # Load another config file or directory, as if its contents were inserted
      # at the current location.
      #
      # @param path [String] The file or directory to load.
      # @param as [String] Load into the given tool/namespace. If omitted,
      #     configuration will be loaded into the current namespace.
      #
      # @return [self]
      #
      def load(path, as: nil)
        if as
          tool(as) do
            load(path)
          end
          return self
        end
        @__loader.load_path(source_info, path, @__words, @__remaining_words, @__priority)
        self
      end

      ##
      # Load configuration from a public git repository, as if its contents
      # were inserted at the current location.
      #
      # @param remote [String] The URL of the git repository. Defaults to the
      #     current repository if already loading from git.
      # @param path [String] The path within the repo to the file or directory
      #     to load. Defaults to the root of the repo.
      # @param commit [String] The commit branch, tag, or sha. Defaults to the
      #     current commit if already loading from git, or to `HEAD`.
      # @param as [String] Load into the given tool/namespace. If omitted,
      #     configuration will be loaded into the current namespace.
      # @param update [Boolean] Force-fetch from the remote (unless the commit
      #     is a SHA). This will ensure that symbolic commits, such as branch
      #     names, are up to date. Default is false.
      #
      # @return [self]
      #
      def load_git(remote: nil, path: nil, commit: nil, as: nil, update: false)
        if as
          tool(as) do
            load_git(remote: remote, path: path, commit: commit)
          end
          return self
        end
        remote ||= source_info.git_remote
        raise ToolDefinitionError, "Git remote not specified" unless remote
        path ||= ""
        commit ||= source_info.git_commit || "HEAD"
        @__loader.load_git(source_info, remote, path, commit,
                           @__words, @__remaining_words, @__priority,
                           update: update)
        self
      end

      ##
      # Expand the given template in the current location.
      #
      # The template may be specified as a class or a well-known template name.
      # You may also provide arguments to pass to the template.
      #
      # ### Example
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
        cur_tool = DSL::Internal.current_tool(self, false)
        return self if cur_tool.nil?
        name = template_class.to_s
        case template_class
        when ::String
          template_class = cur_tool.lookup_template(template_class)
        when ::Symbol
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
      # @param str [Toys::WrappableString,String,Array<String>]
      # @return [self]
      #
      def desc(str)
        cur_tool = DSL::Internal.current_tool(self, true)
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
      # ### Example
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
        cur_tool = DSL::Internal.current_tool(self, true)
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
        strs += DSL::Internal.load_long_desc_file(file) if file
        cur_tool.append_long_desc(strs)
        self
      end

      ##
      # Create a flag group. If a block is given, flags defined in the block
      # belong to the group. The flags in the group are listed together in
      # help screens.
      #
      # ### Example
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
      #     description for the group. See {Toys::DSL::Tool#desc} for a
      #     description of allowed formats. Defaults to `"Flags"`.
      # @param long_desc [Array<String,Array<String>,Toys::WrappableString>]
      #     Long description for the flag group. See
      #     {Toys::DSL::Tool#long_desc} for a description of allowed formats.
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
        cur_tool = DSL::Internal.current_tool(self, true)
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
      # ### Example
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
      #     description for the group. See {Toys::DSL::Tool#desc} for a
      #     description of allowed formats. Defaults to `"Flags"`.
      # @param long_desc [Array<String,Array<String>,Toys::WrappableString>]
      #     Long description for the flag group. See
      #     {Toys::DSL::Tool#long_desc} for a description of allowed formats.
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
      # ### Example
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
      #     description for the group. See {Toys::DSL::Tool#desc} for a
      #     description of allowed formats. Defaults to `"Flags"`.
      # @param long_desc [Array<String,Array<String>,Toys::WrappableString>]
      #     Long description for the flag group. See
      #     {Toys::DSL::Tool#long_desc} for a description of allowed formats.
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
      # ### Example
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
      #     description for the group. See {Toys::DSL::Tool#desc} for a
      #     description of allowed formats. Defaults to `"Flags"`.
      # @param long_desc [Array<String,Array<String>,Toys::WrappableString>]
      #     Long description for the flag group. See
      #     {Toys::DSL::Tool#long_desc} for a description of allowed formats.
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
      # ### Example
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
      #     description for the group. See {Toys::DSL::Tool#desc} for a
      #     description of allowed formats. Defaults to `"Flags"`.
      # @param long_desc [Array<String,Array<String>,Toys::WrappableString>]
      #     Long description for the flag group. See
      #     {Toys::DSL::Tool#long_desc} for a description of allowed formats.
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
      # ### Flag syntax
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
      # ### Default flag syntax
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
      # ### More examples
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
      #     defined, one of the default acceptors provided by OptionParser, or
      #     any other specification recognized by {Toys::Acceptor.create}.
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
      # @param add_method [true,false,nil] Whether to add a method for this
      #     flag. If omitted or set to nil, uses the default behavior, which
      #     adds the method if the key is a symbol representing a legal method
      #     name that starts with a letter and does not override any public
      #     method in the Ruby Object class or collide with any method directly
      #     defined in the tool class.
      # @param block [Proc] Configures the flag. See {Toys::DSL::Flag} for the
      #     directives that can be called in this block.
      # @return [self]
      #
      def flag(key, *flags,
               accept: nil, default: nil, handler: nil,
               complete_flags: nil, complete_values: nil,
               report_collisions: true, group: nil,
               desc: nil, long_desc: nil, display_name: nil, add_method: nil,
               &block)
        cur_tool = DSL::Internal.current_tool(self, true)
        return self if cur_tool.nil?
        flag_dsl = DSL::Flag.new(
          flags.flatten, accept, default, handler, complete_flags, complete_values,
          report_collisions, group, desc, long_desc, display_name, add_method
        )
        flag_dsl.instance_exec(flag_dsl, &block) if block
        flag_dsl._add_to(cur_tool, key)
        DSL::Internal.maybe_add_getter(self, key, flag_dsl._get_add_method)
        self
      end

      ##
      # Add a required positional argument to the current tool. You must
      # specify a key which the script may use to obtain the argument value
      # from the context.
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
      # ### Example
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
      #     defined, one of the default acceptors provided by OptionParser, or
      #     any other specification recognized by {Toys::Acceptor.create}.
      #     Optional. If not specified, accepts any value as a string.
      # @param complete [Object] A specifier for shell tab completion for
      #     values of this arg. This is the empty completion by default. To
      #     customize completion, set this to the name of a previously defined
      #     completion, or any spec recognized by {Toys::Completion.create}.
      # @param display_name [String] A name to use for display (in help text
      #     and error reports). Defaults to the key in upper case.
      # @param desc [String,Array<String>,Toys::WrappableString] Short
      #     description for the flag. See {Toys::DSL::Tool#desc} for a
      #     description of the allowed formats. Defaults to the empty string.
      # @param long_desc [Array<String,Array<String>,Toys::WrappableString>]
      #     Long description for the flag. See {Toys::DSL::Tool#long_desc} for
      #     a description of the allowed formats. (But note that this param
      #     takes an Array of description lines, rather than a series of
      #     arguments.) Defaults to the empty array.
      # @param add_method [true,false,nil] Whether to add a method for this
      #     argument. If omitted or set to nil, uses the default behavior,
      #     which adds the method if the key is a symbol representing a legal
      #     method name that starts with a letter and does not override any
      #     public method in the Ruby Object class or collide with any method
      #     directly defined in the tool class.
      # @param block [Proc] Configures the positional argument. See
      #     {Toys::DSL::PositionalArg} for the directives that can be called in
      #     this block.
      # @return [self]
      #
      def required_arg(key,
                       accept: nil, complete: nil, display_name: nil,
                       desc: nil, long_desc: nil, add_method: nil,
                       &block)
        cur_tool = DSL::Internal.current_tool(self, true)
        return self if cur_tool.nil?
        arg_dsl = DSL::PositionalArg.new(accept, nil, complete, display_name,
                                         desc, long_desc, add_method)
        arg_dsl.instance_exec(arg_dsl, &block) if block
        arg_dsl._add_required_to(cur_tool, key)
        DSL::Internal.maybe_add_getter(self, key, arg_dsl._get_add_method)
        self
      end
      alias required required_arg

      ##
      # Add an optional positional argument to the current tool. You must
      # specify a key which the script may use to obtain the argument value
      # from the context. If an optional argument is not given on the command
      # line, the value is set to the given default.
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
      # ### Example
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
      #     be set in the context if this argument is not provided on the
      #     command line. Defaults to `nil`.
      # @param accept [Object] An acceptor that validates and/or converts the
      #     value. You may provide either the name of an acceptor you have
      #     defined, one of the default acceptors provided by OptionParser, or
      #     any other specification recognized by {Toys::Acceptor.create}.
      #     Optional. If not specified, accepts any value as a string.
      # @param complete [Object] A specifier for shell tab completion for
      #     values of this arg. This is the empty completion by default. To
      #     customize completion, set this to the name of a previously defined
      #     completion, or any spec recognized by {Toys::Completion.create}.
      # @param display_name [String] A name to use for display (in help text
      #     and error reports). Defaults to the key in upper case.
      # @param desc [String,Array<String>,Toys::WrappableString] Short
      #     description for the flag. See {Toys::DSL::Tool#desc} for a
      #     description of the allowed formats. Defaults to the empty string.
      # @param long_desc [Array<String,Array<String>,Toys::WrappableString>]
      #     Long description for the flag. See {Toys::DSL::Tool#long_desc} for
      #     a description of the allowed formats. (But note that this param
      #     takes an Array of description lines, rather than a series of
      #     arguments.) Defaults to the empty array.
      # @param add_method [true,false,nil] Whether to add a method for this
      #     argument. If omitted or set to nil, uses the default behavior,
      #     which adds the method if the key is a symbol representing a legal
      #     method name that starts with a letter and does not override any
      #     public method in the Ruby Object class or collide with any method
      #     directly defined in the tool class.
      # @param block [Proc] Configures the positional argument. See
      #     {Toys::DSL::PositionalArg} for the directives that can be called in
      #     this block.
      # @return [self]
      #
      def optional_arg(key,
                       default: nil, accept: nil, complete: nil, display_name: nil,
                       desc: nil, long_desc: nil, add_method: nil,
                       &block)
        cur_tool = DSL::Internal.current_tool(self, true)
        return self if cur_tool.nil?
        arg_dsl = DSL::PositionalArg.new(accept, default, complete, display_name,
                                         desc, long_desc, add_method)
        arg_dsl.instance_exec(arg_dsl, &block) if block
        arg_dsl._add_optional_to(cur_tool, key)
        DSL::Internal.maybe_add_getter(self, key, arg_dsl._get_add_method)
        self
      end
      alias optional optional_arg

      ##
      # Specify what should be done with unmatched positional arguments. You
      # must specify a key which the script may use to obtain the remaining
      # args from the context.
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
      # ### Example
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
      #     defined, one of the default acceptors provided by OptionParser, or
      #     any other specification recognized by {Toys::Acceptor.create}.
      #     Optional. If not specified, accepts any value as a string.
      # @param complete [Object] A specifier for shell tab completion for
      #     values of this arg. This is the empty completion by default. To
      #     customize completion, set this to the name of a previously defined
      #     completion, or any spec recognized by {Toys::Completion.create}.
      # @param display_name [String] A name to use for display (in help text
      #     and error reports). Defaults to the key in upper case.
      # @param desc [String,Array<String>,Toys::WrappableString] Short
      #     description for the flag. See {Toys::DSL::Tool#desc} for a
      #     description of the allowed formats. Defaults to the empty string.
      # @param long_desc [Array<String,Array<String>,Toys::WrappableString>]
      #     Long description for the flag. See {Toys::DSL::Tool#long_desc} for
      #     a description of the allowed formats. (But note that this param
      #     takes an Array of description lines, rather than a series of
      #     arguments.) Defaults to the empty array.
      # @param add_method [true,false,nil] Whether to add a method for these
      #     arguments. If omitted or set to nil, uses the default behavior,
      #     which adds the method if the key is a symbol representing a legal
      #     method name that starts with a letter and does not override any
      #     public method in the Ruby Object class or collide with any method
      #     directly defined in the tool class.
      # @param block [Proc] Configures the positional argument. See
      #     {Toys::DSL::PositionalArg} for the directives that can be called in
      #     this block.
      # @return [self]
      #
      def remaining_args(key,
                         default: [], accept: nil, complete: nil, display_name: nil,
                         desc: nil, long_desc: nil, add_method: nil,
                         &block)
        cur_tool = DSL::Internal.current_tool(self, true)
        return self if cur_tool.nil?
        arg_dsl = DSL::PositionalArg.new(accept, default, complete, display_name,
                                         desc, long_desc, add_method)
        arg_dsl.instance_exec(arg_dsl, &block) if block
        arg_dsl._set_remaining_on(cur_tool, key)
        DSL::Internal.maybe_add_getter(self, key, arg_dsl._get_add_method)
        self
      end
      alias remaining remaining_args

      ##
      # Set option values statically and create helper methods.
      #
      # If any given key is a symbol representing a valid method name, then a
      # helper method is automatically added to retrieve the value. Otherwise,
      # if the key is a string or does not represent a valid method name, the
      # tool can retrieve the value by calling {Toys::Context#get}.
      #
      # ### Example
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
        cur_tool = DSL::Internal.current_tool(self, true)
        return self if cur_tool.nil?
        if key.is_a?(::Hash)
          cur_tool.default_data.merge!(key)
          key.each_key do |k|
            DSL::Internal.maybe_add_getter(self, k, true)
          end
        else
          cur_tool.default_data[key] = value
          DSL::Internal.maybe_add_getter(self, key, true)
        end
        self
      end

      ##
      # Set option values statically without creating helper methods.
      #
      # ### Example
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
        cur_tool = DSL::Internal.current_tool(self, true)
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
        DSL::Internal.current_tool(self, true)&.enforce_flags_before_args(state)
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
        DSL::Internal.current_tool(self, true)&.require_exact_flag_match(state)
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
      # ### Example
      #
      #     tool "mytool" do
      #       disable_argument_parsing
      #       def run
      #         puts "Arguments passed: #{args}"
      #       end
      #     end
      #
      # @return [self]
      #
      def disable_argument_parsing
        DSL::Internal.current_tool(self, true)&.disable_argument_parsing
        self
      end

      ##
      # Mark one or more flags as disabled, preventing their use by any
      # subsequent flag definition. This can be used to prevent middleware from
      # defining a particular flag.
      #
      # ### Example
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
        DSL::Internal.current_tool(self, true)&.disable_flag(*flags)
        self
      end

      ##
      # Set the shell completion strategy for this tool's arguments.
      # You can pass one of the following:
      #
      #  *  The string name of a completion defined in this tool or any of its
      #     its ancestors.
      #  *  A hash of options to pass to the constructor of
      #     {Toys::ToolDefinition::DefaultCompletion}.
      #  *  `nil` or `:default` to select the standard completion strategy
      #     (which is {Toys::ToolDefinition::DefaultCompletion} with no extra
      #     options).
      #  *  Any other specification recognized by {Toys::Completion.create}.
      #
      # ### Example
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
        cur_tool = DSL::Internal.current_tool(self, true)
        return self if cur_tool.nil?
        cur_tool.completion = Completion.scalarize_spec(spec, options, block)
        self
      end

      ##
      # Specify how to run this tool.
      #
      # Typically the entrypoint for a tool is a method named `run`. However,
      # you can change this by passing a different method name, as a symbol, to
      # {#to_run}.
      #
      # You can also alternatively pass a block to {#to_run}. You might do this
      # if your method needs access to local variables in the lexical scope.
      # However, it is often more convenient to use {#static} to set those
      # values in the context.
      #
      # ### Examples
      #
      #     # Set a different method name as the entrypoint:
      #
      #     tool "foo" do
      #       to_run :foo
      #       def foo
      #         puts "The fool tool ran!"
      #       end
      #     end
      #
      #     # Use a block to retain access to the enclosing lexical scope from
      #     # the run method:
      #
      #     tool "foo" do
      #       cur_time = Time.now
      #       to_run do
      #         puts "The time at tool definition was #{cur_time}"
      #       end
      #     end
      #
      #     # But the following is approximately equivalent:
      #
      #     tool "foo" do
      #       static :cur_time, Time.now
      #       def run
      #         puts "The time at tool definition was #{cur_time}"
      #       end
      #     end
      #
      # @param handler [Proc,Symbol,nil] The run handler as a method name
      #     symbol or a proc, or nil to explicitly set as non-runnable.
      # @param block [Proc] The run handler as a block.
      # @return [self]
      #
      def to_run(handler = nil, &block)
        DSL::Internal.current_tool(self, true)&.run_handler = handler || block
        self
      end
      alias on_run to_run

      ##
      # Specify how to handle interrupts.
      #
      # You can provide either a block to be called, a Proc to be called, or
      # the name of a method to be called. In each case, the block, Proc, or
      # method can optionally take one argument, the Interrupt exception that
      # was raised.
      #
      # Note: this is equivalent to `on_signal("SIGINT")`.
      #
      # ### Example
      #
      #     tool "foo" do
      #       def run
      #         sleep 10
      #       end
      #       on_interrupt do
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
        DSL::Internal.current_tool(self, true)&.interrupt_handler = handler || block
        self
      end

      ##
      # Specify how to handle the given signal.
      #
      # You can provide either a block to be called, a Proc to be called, or
      # the name of a method to be called. In each case, the block, Proc, or
      # method can optionally take one argument, the SignalException that was
      # raised.
      #
      # ### Example
      #
      #     tool "foo" do
      #       def run
      #         sleep 10
      #       end
      #       on_signal("QUIT") do |e|
      #         puts "Signal caught: #{e.signm}."
      #       end
      #     end
      #
      # @param signal [Integer,String,Symbol] The signal name or number
      # @param handler [Proc,Symbol,nil] The signal callback proc or method
      #     name. Pass nil to disable signal handling.
      # @param block [Proc] The signal callback as a block.
      # @return [self]
      #
      def on_signal(signal, handler = nil, &block)
        DSL::Internal.current_tool(self, true)&.set_signal_handler(signal, handler || block)
        self
      end

      ##
      # Specify how to handle usage errors.
      #
      # You can provide either a block to be called, a Proc to be called, or
      # the name of a method to be called. In each case, the block, Proc, or
      # method can optionally take one argument, the array of usage errors
      # reported.
      #
      # ### Example
      #
      # This tool runs even if a usage error is encountered, by setting the
      # `run` method as the usage error handler.
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
        DSL::Internal.current_tool(self, true)&.usage_error_handler = handler || block
        self
      end

      ##
      # Specify that the given module should be mixed into this tool, and its
      # methods made available when running the tool.
      #
      # You can provide either a module, the string name of a mixin that you
      # have defined in this tool or one of its ancestors, or the symbol name
      # of a well-known mixin.
      #
      # ### Example
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
      # @param mixin [Module,Symbol,String] Module or module name.
      # @param args [Object...] Arguments to pass to the initializer
      # @param kwargs [keywords] Keyword arguments to pass to the initializer
      # @return [self]
      #
      def include(mixin, *args, **kwargs)
        cur_tool = DSL::Internal.current_tool(self, true)
        return self if cur_tool.nil?
        mod = DSL::Internal.resolve_mixin(mixin, cur_tool, @__loader)
        cur_tool.include_mixin(mod, *args, **kwargs)
        self
      end

      ##
      # Determine if the given module/mixin has already been included.
      #
      # You can provide either a module, the string name of a mixin that you
      # have defined in this tool or one of its ancestors, or the symbol name
      # of a well-known mixin.
      #
      # @param mod [Module,Symbol,String] Module or module name.
      #
      # @return [Boolean] Whether the mixin is included
      # @return [nil] if the current tool is not active.
      #
      def include?(mod)
        cur_tool = DSL::Internal.current_tool(self, false)
        return if cur_tool.nil?
        super(DSL::Internal.resolve_mixin(mod, cur_tool, @__loader))
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
      # ### Example
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
        DSL::Internal.current_tool(self, false)&.context_directory || source_info.context_directory
      end

      ##
      # Return the current tool config. This object can be queried to determine
      # such information as the name, but it should not be altered.
      #
      # @return [Toys::ToolDefinition]
      #
      def current_tool
        DSL::Internal.current_tool(self, false)
      end

      ##
      # Set a custom context directory for this tool.
      #
      # @param dir [String] Context directory
      # @return [self]
      #
      def set_context_directory(dir) # rubocop:disable Naming/AccessorMethodName
        cur_tool = DSL::Internal.current_tool(self, false)
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
      # ### Example
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
        cur_tool = DSL::Internal.current_tool(self, false)
        return self if cur_tool.nil?
        cur_tool.subtool_middleware_stack.add(:apply_config,
                                              parent_source: source_info, &block)
        self
      end

      ##
      # Remove lower-priority sources from the load path. This prevents lower-
      # priority sources (such as Toys files from parent or global directories)
      # from executing or defining tools.
      #
      # This works only if no such sources have already loaded yet.
      #
      # @raise [Toys::ToolDefinitionError] if any lower-priority tools have
      #     already been loaded.
      #
      def truncate_load_path!
        unless @__loader.stop_loading_at_priority(@__priority)
          raise ToolDefinitionError,
                "Cannot truncate load path because tools have already been loaded"
        end
      end

      ##
      # Get the settings for this tool.
      #
      # @return [Toys::ToolDefinition::Settings] Tool-specific settings.
      #
      def settings
        DSL::Internal.current_tool(self, false)&.settings
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

      ##
      # Notify the tool definition when a method is defined in this tool class.
      #
      # @private
      #
      def method_added(_meth)
        super
        DSL::Internal.current_tool(self, true)&.check_definition_state(is_method: true)
      end

      ##
      # Include the tool name in the class inspection dump.
      #
      # @private
      #
      def inspect
        return super unless defined? @__words
        name = @__words.empty? ? "(root)" : @__words.join(" ").inspect
        id = object_id.to_s(16)
        "#<Class id=0x#{id} tool=#{name}>"
      end
    end
  end
end
