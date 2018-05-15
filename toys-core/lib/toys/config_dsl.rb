# Copyright 2018 Daniel Azuma
#
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice,
#   this list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# * Neither the name of the copyright holder, nor the names of any other
#   contributors to this software, may be used to endorse or promote products
#   derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
;

module Toys
  ##
  # This class defines the DSL for a toys configuration file.
  #
  # A toys configuration defines one or more named tools. It provides syntax
  # for setting the description, defining flags and arguments, specifying
  # how to execute the tool, and requesting helper modules and other services.
  # It also lets you define subtools, nested arbitrarily deep, using blocks.
  #
  # Generally ConfigDSL is invoked from the {Loader}. Applications should not
  # need to create instances of ConfigDSL directly.
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
  #       execute do
  #         puts "Hello, #{self[:recipient]}!"
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
  class ConfigDSL
    ##
    # Create an instance of the DSL.
    # @private
    #
    # @param [Array<String>] words Full name of the current tool.
    # @param [Array<String>,nil] remaining_words Arguments remaining in the
    #     current lookup.
    # @param [Integer] priority Priority of this configuration
    # @param [Toys::Loader] loader Current active loader
    # @param [String] path The path to the config file being evaluated
    #
    # @return [Toys::ConfigDSL]
    #
    def initialize(words, remaining_words, priority, loader, path)
      @words = words
      @remaining_words = remaining_words
      @priority = priority
      @loader = loader
      @path = path
    end

    ##
    # Create a subtool. You must provide a block defining the subtool.
    #
    # If the subtool is already defined (either as a tool or a group), the old
    # definition is discarded and replaced with the new definition. If the old
    # tool was a group, all its descendants are also discarded, recursively.
    #
    # @param [String] word The name of the subtool
    #
    def tool(word, &block)
      word = word.to_s
      subtool_words = @words + [word]
      next_remaining = Loader.next_remaining_words(@remaining_words, word)
      ConfigDSL.evaluate(subtool_words, next_remaining, @priority, @loader, @path, block)
      self
    end
    alias name tool

    ##
    # Create an alias in the current group.
    #
    # @param [String] word The name of the alias
    # @param [String] target The target of the alias
    #
    def alias_tool(word, target)
      @loader.make_alias(@words + [word.to_s], @words + [target.to_s], @priority)
      self
    end

    ##
    # Create an alias of the current tool.
    #
    # @param [String] word The name of the alias
    #
    def alias_as(word)
      if @words.empty?
        raise ToolDefinitionError, "Cannot make an alias of the root."
      end
      @loader.make_alias(@words[0..-2] + [word.to_s], @words, @priority)
      self
    end

    ##
    # Include another config file or directory at the current location.
    #
    # @param [String] path The file or directory to include.
    #
    def include(path)
      @loader.include_path(path, @words, @remaining_words, @priority)
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
    #
    def expand(template_class, *args)
      unless template_class.is_a?(::Class)
        name = template_class.to_s
        template_class = Templates.lookup(name)
        if template_class.nil?
          raise ToolDefinitionError, "Template not found: #{name.inspect}"
        end
      end
      template = template_class.new(*args)
      yield template if block_given?
      instance_exec(template, &template_class.expander)
      self
    end

    ##
    # Set the short description for the current tool. The short description is
    # displayed with the tool in a subtool list. You may also use the
    # equivalent method `short_desc`.
    #
    # The description is a {Toys::Utils::WrappableString}, which may be word-
    # wrapped when displayed in a help screen. You may pass a
    # {Toys::Utils::WrappableString} directly to this method, or you may pass
    # any input that can be used to construct a wrappable string:
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
    # @param [Toys::Utils::WrappableString,String,Array<String>] str
    #
    def desc(str)
      return self if _cur_tool.nil?
      _cur_tool.lock_definition_path(@path)
      _cur_tool.desc = str
      self
    end
    alias short_desc desc

    ##
    # Set the long description for the current tool. The long description is
    # displayed in the usage documentation for the tool itself.
    #
    # A long description is a series of descriptions, which are generally
    # displayed in a series of lines/paragraphs. Each individual description
    # uses the form described in the {Toys::ConfigDSL#desc} documentation, and
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
    # @param [Toys::Utils::WrappableString,String,Array<String>...] strs
    #
    def long_desc(*strs)
      return self if _cur_tool.nil?
      _cur_tool.lock_definition_path(@path)
      _cur_tool.long_desc = strs
      self
    end

    ##
    # Add a flag to the current tool. Each flag must specify a key which
    # the executor may use to obtain the flag value from the context.
    # You may then provide the flags themselves in `OptionParser` form.
    #
    # Attributes of the flag may be passed in as arguments to this method, or
    # set in a block passed to this method.
    #
    # @param [Symbol] key The key to use to retrieve the value from the
    #     execution context.
    # @param [String...] flags The flags in OptionParser format.
    # @param [Object,nil] accept An OptionParser acceptor. Optional.
    # @param [Object] default The default value. This is the value that will
    #     be set in the context if this flag is not provided on the command
    #     line. Defaults to `nil`.
    # @param [Proc,nil] handler An optional handler for setting/updating the
    #     value. If given, it should take two arguments, the new given value
    #     and the previous value, and it should return the new value that
    #     should be set. The default handler simply replaces the previous
    #     value. i.e. the default is effectively `-> (val, _prev) { val }`.
    # @param [String,Array<String>,Toys::Utils::WrappableString] desc Short
    #     description for the flag. See {Toys::ConfigDSL#desc} for a description
    #     of the allowed formats. Defaults to the empty string.
    # @param [Array<String,Array<String>,Toys::Utils::WrappableString>] long_desc
    #     Long description for the flag. See {Toys::ConfigDSL#long_desc} for a
    #     description of the allowed formats. (But note that this param takes
    #     an Array of description lines, rather than a series of arguments.)
    #     Defaults to the empty array.
    # @param [Boolean] only_unique If true, any flags that are already
    #     defined in this tool are removed from this flag. For example, if
    #     an earlier flag uses `-a`, and this flag wants to use both
    #     `-a` and `-b`, then only `-b` will be assigned to this flag.
    #     Defaults to false.
    # @yieldparam flag_dsl [Toys::ConfigDSL::FlagDSL] An object that lets you
    #     configure this flag in a block.
    #
    def flag(key, *flags,
             accept: nil, default: nil, handler: nil, desc: nil, long_desc: nil,
             only_unique: false)
      return self if _cur_tool.nil?
      flag_dsl = FlagDSL.new(flags, accept, default, handler, desc, long_desc)
      yield flag_dsl if block_given?
      _cur_tool.lock_definition_path(@path)
      flag_dsl._add_to(_cur_tool, key, only_unique)
      self
    end

    ##
    # Add a required positional argument to the current tool. You must specify
    # a key which the executor may use to obtain the argument value from the
    # context.
    #
    # @param [Symbol] key The key to use to retrieve the value from the
    #     execution context.
    # @param [Object,nil] accept An OptionParser acceptor. Optional.
    # @param [String] display_name A name to use for display (in help text and
    #     error reports). Defaults to the key in upper case.
    # @param [String,Array<String>,Toys::Utils::WrappableString] desc Short
    #     description for the flag. See {Toys::ConfigDSL#desc} for a description
    #     of the allowed formats. Defaults to the empty string.
    # @param [Array<String,Array<String>,Toys::Utils::WrappableString>] long_desc
    #     Long description for the flag. See {Toys::ConfigDSL#long_desc} for a
    #     description of the allowed formats. (But note that this param takes
    #     an Array of description lines, rather than a series of arguments.)
    #     Defaults to the empty array.
    # @yieldparam arg_dsl [Toys::ConfigDSL::ArgDSL] An object that lets you
    #     configure this argument in a block.
    #
    def required_arg(key, accept: nil, display_name: nil, desc: nil, long_desc: nil)
      return self if _cur_tool.nil?
      arg_dsl = ArgDSL.new(accept, nil, display_name, desc, long_desc)
      yield arg_dsl if block_given?
      _cur_tool.lock_definition_path(@path)
      arg_dsl._add_required_to(_cur_tool, key)
      self
    end
    alias required required_arg

    ##
    # Add an optional positional argument to the current tool. You must specify
    # a key which the executor may use to obtain the argument value from the
    # context. If an optional argument is not given on the command line, the
    # value is set to the given default.
    #
    # @param [Symbol] key The key to use to retrieve the value from the
    #     execution context.
    # @param [Object] default The default value. This is the value that will
    #     be set in the context if this argument is not provided on the command
    #     line. Defaults to `nil`.
    # @param [Object,nil] accept An OptionParser acceptor. Optional.
    # @param [String] display_name A name to use for display (in help text and
    #     error reports). Defaults to the key in upper case.
    # @param [String,Array<String>,Toys::Utils::WrappableString] desc Short
    #     description for the flag. See {Toys::ConfigDSL#desc} for a description
    #     of the allowed formats. Defaults to the empty string.
    # @param [Array<String,Array<String>,Toys::Utils::WrappableString>] long_desc
    #     Long description for the flag. See {Toys::ConfigDSL#long_desc} for a
    #     description of the allowed formats. (But note that this param takes
    #     an Array of description lines, rather than a series of arguments.)
    #     Defaults to the empty array.
    # @yieldparam arg_dsl [Toys::ConfigDSL::ArgDSL] An object that lets you
    #     configure this argument in a block.
    #
    def optional_arg(key, default: nil, accept: nil, display_name: nil,
                     desc: nil, long_desc: nil)
      return self if _cur_tool.nil?
      arg_dsl = ArgDSL.new(accept, default, display_name, desc, long_desc)
      yield arg_dsl if block_given?
      _cur_tool.lock_definition_path(@path)
      arg_dsl._add_optional_to(_cur_tool, key)
      self
    end
    alias optional optional_arg

    ##
    # Specify what should be done with unmatched positional arguments. You must
    # specify a key which the executor may use to obtain the remaining args
    # from the context.
    #
    # @param [Symbol] key The key to use to retrieve the value from the
    #     execution context.
    # @param [Object] default The default value. This is the value that will
    #     be set in the context if no unmatched arguments are provided on the
    #     command line. Defaults to the empty array `[]`.
    # @param [Object,nil] accept An OptionParser acceptor. Optional.
    # @param [String] display_name A name to use for display (in help text and
    #     error reports). Defaults to the key in upper case.
    # @param [String,Array<String>,Toys::Utils::WrappableString] desc Short
    #     description for the flag. See {Toys::ConfigDSL#desc} for a description
    #     of the allowed formats. Defaults to the empty string.
    # @param [Array<String,Array<String>,Toys::Utils::WrappableString>] long_desc
    #     Long description for the flag. See {Toys::ConfigDSL#long_desc} for a
    #     description of the allowed formats. (But note that this param takes
    #     an Array of description lines, rather than a series of arguments.)
    #     Defaults to the empty array.
    # @yieldparam arg_dsl [Toys::ConfigDSL::ArgDSL] An object that lets you
    #     configure this argument in a block.
    #
    def remaining_args(key, default: [], accept: nil, display_name: nil,
                       desc: nil, long_desc: nil)
      return self if _cur_tool.nil?
      arg_dsl = ArgDSL.new(accept, default, display_name, desc, long_desc)
      yield arg_dsl if block_given?
      _cur_tool.lock_definition_path(@path)
      arg_dsl._set_remaining_on(_cur_tool, key)
      self
    end
    alias remaining remaining_args

    ##
    # Specify the executor for this tool. This is a block that will be called,
    # with `self` set to a {Toys::Context}.
    #
    def execute(&block)
      return self if _cur_tool.nil?
      _cur_tool.lock_definition_path(@path)
      _cur_tool.executor = block
      self
    end

    ##
    # Define a helper method that may be called from this tool's executor.
    # You must provide a name for the method, and a block for the method
    # definition.
    #
    # @param [String,Symbol] name Name of the method. May not begin with an
    #     underscore.
    #
    def helper(name, &block)
      return self if _cur_tool.nil?
      _cur_tool.lock_definition_path(@path)
      _cur_tool.add_helper(name, &block)
      self
    end

    ##
    # Specify that the given module should be mixed in to this tool's executor.
    # Effectively, the module is added to the {Toys::Context} object.
    # You may either provide a module directly, or specify the name of a
    # well-known module.
    #
    # @param [Module,Symbol] mod Module or name of well-known module.
    #
    def use(mod)
      return self if _cur_tool.nil?
      _cur_tool.lock_definition_path(@path)
      _cur_tool.use_module(mod)
      self
    end

    ##
    # DSL for a flag definition block. Lets you set flag attributes in a block
    # instead of a long series of keyword arguments.
    #
    class FlagDSL
      ## @private
      def initialize(flags, accept, default, handler, desc, long_desc)
        @flags = flags
        @accept = accept
        @default = default
        @handler = handler
        @desc = desc
        @long_desc = long_desc
      end

      ##
      # Add flags in OptionParser format. This may be called multiple times,
      # and the results are cumulative.
      # @param [String...] flags
      #
      def flags(*flags)
        @flags += flags
        self
      end

      ##
      # Set the OptionParser acceptor.
      # @param [Object] accept
      #
      def accept(accept)
        @accept = accept
        self
      end

      ##
      # Set the default value.
      # @param [Object] default
      #
      def default(default)
        @default = default
        self
      end

      ##
      # Set the optional handler for setting/updating the value when a flag is
      # parsed. It should be a Proc taking two arguments, the new given value
      # and the previous value, and it should return the new value that should
      # be set.
      # @param [Proc] handler
      #
      def handler(handler)
        @handler = handler
        self
      end

      ##
      # Set the short description. See {Toys::ConfigDSL#desc} for the allowed
      # formats.
      # @param [String,Array<String>,Toys::Utils::WrappableString] desc
      #
      def desc(desc)
        @desc = desc
        self
      end

      ##
      # Adds to the long description. This may be called multiple times, and
      # the results are cumulative. See {Toys::ConfigDSL#long_desc} for the
      # allowed formats.
      # @param [String,Array<String>,Toys::Utils::WrappableString...] long_desc
      #
      def long_desc(*long_desc)
        @long_desc += long_desc
        self
      end

      ## @private
      def _add_to(tool, key, only_unique)
        tool.add_flag(key, @flags,
                      accept: @accept, default: @default, handler: @handler,
                      desc: @desc, long_desc: @long_desc,
                      only_unique: only_unique)
      end
    end

    ##
    # DSL for an arg definition block. Lets you set arg attributes in a block
    # instead of a long series of keyword arguments.
    #
    class ArgDSL
      ## @private
      def initialize(accept, default, display_name, desc, long_desc)
        @accept = accept
        @default = default
        @display_name = display_name
        @desc = desc
        @long_desc = long_desc
      end

      ##
      # Set the OptionParser acceptor.
      # @param [Object] accept
      #
      def accept(accept)
        @accept = accept
        self
      end

      ##
      # Set the default value.
      # @param [Object] default
      #
      def default(default)
        @default = default
        self
      end

      ##
      # Set the name of this arg as it appears in help screens.
      # @param [String] display_name
      #
      def display_name(display_name)
        @handler = display_name
        self
      end

      ##
      # Set the short description. See {Toys::ConfigDSL#desc} for the allowed
      # formats.
      # @param [String,Array<String>,Toys::Utils::WrappableString] desc
      #
      def desc(desc)
        @desc = desc
        self
      end

      ##
      # Adds to the long description. This may be called multiple times, and
      # the results are cumulative. See {Toys::ConfigDSL#long_desc} for the
      # allowed formats.
      # @param [String,Array<String>,Toys::Utils::WrappableString...] long_desc
      #
      def long_desc(*long_desc)
        @long_desc += long_desc
        self
      end

      ## @private
      def _add_required_to(tool, key)
        tool.add_required_arg(key,
                              accept: @accept, display_name: @display_name,
                              desc: @desc, long_desc: @long_desc)
      end

      ## @private
      def _add_optional_to(tool, key)
        tool.add_optional_arg(key,
                              accept: @accept, default: @default, display_name: @display_name,
                              desc: @desc, long_desc: @long_desc)
      end

      ## @private
      def _set_remaining_on(tool, key)
        tool.set_remaining_args(key,
                                accept: @accept, default: @default, display_name: @display_name,
                                desc: @desc, long_desc: @long_desc)
      end
    end

    ## @private
    def _binding
      binding
    end

    ## @private
    def _cur_tool
      unless defined? @_cur_tool
        @_cur_tool = @loader.get_or_create_tool(@words, priority: @priority)
      end
      @_cur_tool
    end

    ## @private
    def self.evaluate(words, remaining_words, priority, loader, path, source)
      dsl = new(words, remaining_words, priority, loader, path)
      case source
      when String
        ContextualError.capture_path("Error while loading Toys config!", path) do
          # rubocop:disable Security/Eval
          eval(source, dsl._binding, path, 1)
          # rubocop:enable Security/Eval
        end
      when ::Proc
        dsl.instance_eval(&source)
      end
      nil
    end
  end
end
