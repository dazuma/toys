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
  # for setting the description, defining switches and arguments, specifying
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
    # Create an alias.
    #
    # @param [String] word The name of the alias
    # @param [String] target The target of the alias
    #
    def alias_tool(word, target)
      @loader.make_alias(@words + [word.to_s], @words + [target.to_s], @priority)
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
    # Set the long description for the current tool. The long description is
    # displayed in the usage documentation for the tool itself.
    #
    # @param [String] desc The long description string.
    #
    def long_desc(desc)
      return self if _cur_tool.nil?
      _cur_tool.definition_path = @path
      _cur_tool.long_desc = desc
      self
    end

    ##
    # Set the short description for the current tool. The short description is
    # displayed with the tool in a command list. You may also use the
    # equivalent method `short_desc`.
    #
    # @param [String] desc The short description string.
    #
    def desc(desc)
      return self if _cur_tool.nil?
      _cur_tool.definition_path = @path
      _cur_tool.desc = desc
      self
    end
    alias short_desc desc

    ##
    # Add a switch to the current tool. Each switch must specify a key which
    # the executor may use to obtain the switch value from the context.
    # You may then provide the switches themselves in `OptionParser` form.
    #
    # @param [Symbol] key The key to use to retrieve the value from the
    #     execution context.
    # @param [String...] switches The switches in OptionParser format.
    # @param [Object,nil] accept An OptionParser acceptor. Optional.
    # @param [Object] default The default value. This is the value that will
    #     be set in the context if this switch is not provided on the command
    #     line. Defaults to `nil`.
    # @param [String,nil] doc The documentation for the switch, which appears
    #     in the usage documentation. Defaults to `nil` for no documentation.
    # @param [Boolean] only_unique If true, any switches that are already
    #     defined in this tool are removed from this switch. For example, if
    #     an earlier switch uses `-a`, and this switch wants to use both
    #     `-a` and `-b`, then only `-b` will be assigned to this switch.
    #     Defaults to false.
    # @param [Proc,nil] handler An optional handler for setting/updating the
    #     value. If given, it should take two arguments, the new given value
    #     and the previous value, and it should return the new value that
    #     should be set. The default handler simply replaces the previous
    #     value. i.e. the default is effectively `-> (val, _prev) { val }`.
    #
    def switch(key, *switches,
               accept: nil, default: nil, doc: nil, only_unique: false, handler: nil)
      return self if _cur_tool.nil?
      _cur_tool.definition_path = @path
      _cur_tool.add_switch(key, *switches,
                           accept: accept, default: default, doc: doc,
                           only_unique: only_unique, handler: handler)
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
    # @param [String,nil] doc The documentation for the switch, which appears
    #     in the usage documentation. Defaults to `nil` for no documentation.
    #
    def required_arg(key, accept: nil, doc: nil)
      return self if _cur_tool.nil?
      _cur_tool.definition_path = @path
      _cur_tool.add_required_arg(key, accept: accept, doc: doc)
      self
    end

    ##
    # Add an optional positional argument to the current tool. You must specify
    # a key which the executor may use to obtain the argument value from the
    # context. If an optional argument is not given on the command line, the
    # value is set to the given default.
    #
    # @param [Symbol] key The key to use to retrieve the value from the
    #     execution context.
    # @param [Object,nil] accept An OptionParser acceptor. Optional.
    # @param [Object] default The default value. This is the value that will
    #     be set in the context if this argument is not provided on the command
    #     line. Defaults to `nil`.
    # @param [String,nil] doc The documentation for the argument, which appears
    #     in the usage documentation. Defaults to `nil` for no documentation.
    #
    def optional_arg(key, accept: nil, default: nil, doc: nil)
      return self if _cur_tool.nil?
      _cur_tool.definition_path = @path
      _cur_tool.add_optional_arg(key, accept: accept, default: default, doc: doc)
      self
    end

    ##
    # Specify what should be done with unmatched positional arguments. You must
    # specify a key which the executor may use to obtain the remaining args
    # from the context.
    #
    # @param [Symbol] key The key to use to retrieve the value from the
    #     execution context.
    # @param [Object,nil] accept An OptionParser acceptor. Optional.
    # @param [Object] default The default value. This is the value that will
    #     be set in the context if no unmatched arguments are provided on the
    #     command line. Defaults to the empty array `[]`.
    # @param [String,nil] doc The documentation for the remaining arguments,
    #     which appears in the usage documentation. Defaults to `nil` for no
    #     documentation.
    #
    def remaining_args(key, accept: nil, default: [], doc: nil)
      return self if _cur_tool.nil?
      _cur_tool.definition_path = @path
      _cur_tool.set_remaining_args(key, accept: accept, default: default, doc: doc)
      self
    end

    ##
    # Specify the executor for this tool. This is a block that will be called,
    # with `self` set to a {Toys::Context}.
    #
    def execute(&block)
      return self if _cur_tool.nil?
      _cur_tool.definition_path = @path
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
      _cur_tool.definition_path = @path
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
      _cur_tool.definition_path = @path
      _cur_tool.use_module(mod)
      self
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
        # rubocop:disable Security/Eval
        eval(source, dsl._binding, path, 1)
        # rubocop:enable Security/Eval
      when ::Proc
        dsl.instance_eval(&source)
      end
      nil
    end
  end
end
