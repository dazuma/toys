module Toys
  class Builder
    def initialize(path, tool, remaining_words, priority, lookup)
      @path = path
      @tool = tool
      @remaining_words = remaining_words
      @priority = priority
      @lookup = lookup
    end

    def name(word, alias_of: nil, &block)
      word = word.to_s
      subtool = @lookup.get_tool(@tool.full_name + [word], @priority)
      return self if subtool.nil?
      if alias_of
        if block
          raise Toys::ToysDefinitionError, "Cannot take a block with alias_of"
        end
        target = @tool.full_name + [alias_of.to_s]
        target_tool = @lookup.lookup(target)
        unless target_tool.full_name == target
          raise Toys::ToysDefinitionError, "Alias target #{target.inspect} not found"
        end
        subtool.make_alias_of(target)
        return self
      end
      next_remaining = @remaining_words
      if next_remaining && !next_remaining.empty?
        next_remaining =
          if next_remaining.first == word
            next_remaining.slice(1..-1)
          end
      end
      Builder.build(@path, subtool, next_remaining, @priority, @lookup, block)
      self
    end

    def alias_as(word)
      unless @tool.root?
        alias_tool = @lookup.get_tool(@tool.full_name.slice(0..-2) + [word], @priority)
        alias_tool.make_alias_of(@tool) if alias_tool
      end
      self
    end

    def alias_of(target)
      target_tool = @lookup.lookup(target)
      unless target_tool.full_name == target
        raise Toys::ToysDefinitionError, "Alias target #{target.inspect} not found"
      end
      @tool.make_alias_of(target_tool)
      self
    end

    def include(path)
      @tool.yield_definition do
        @lookup.include_path(path, @tool.full_name, @remaining_words, @priority)
      end
      self
    end

    def expand(template_class, *args)
      unless template_class.is_a?(Class)
        template_class = template_class.to_s
        file_name =
          template_class
          .gsub(/([a-zA-Z])([A-Z])/) { |_m| "#{$1}_#{$2.downcase}" }
          .downcase
        require "toys/templates/#{file_name}"
        const_name = template_class.gsub(/(^|_)([a-zA-Z0-9])/) { |_m| $2.upcase }
        template_class = Toys::Templates.const_get(const_name)
      end
      template = template_class.new(*args)
      yield template if block_given?
      instance_exec(template, &template_class.expander)
      self
    end

    def long_desc(desc)
      @tool.long_desc = desc
      self
    end

    def short_desc(desc)
      @tool.short_desc = desc
      self
    end

    def switch(key, *switches, accept: nil, default: nil, doc: nil)
      @tool.add_switch(key, *switches, accept: accept, default: default, doc: doc)
      self
    end

    def required_arg(key, accept: nil, doc: nil)
      @tool.add_required_arg(key, accept: accept, doc: doc)
      self
    end

    def optional_arg(key, accept: nil, default: nil, doc: nil)
      @tool.add_optional_arg(key, accept: accept, default: default, doc: doc)
      self
    end

    def remaining_args(key, accept: nil, default: [], doc: nil)
      @tool.set_remaining_args(key, accept: accept, default: default, doc: doc)
      self
    end

    def execute(&block)
      @tool.executor = block
      self
    end

    def helper(name, &block)
      @tool.add_helper(name, &block)
      self
    end

    def use(mod)
      @tool.use_helper_module(mod)
      self
    end

    def _binding
      binding
    end

    def self.build(path, tool, remaining_words, priority, lookup, source)
      builder = new(path, tool, remaining_words, priority, lookup)
      tool.defining_from(path) do
        case source
        when String
          # rubocop:disable Security/Eval
          eval(source, builder._binding, path, 1)
          # rubocop:enable Security/Eval
        when Proc
          builder.instance_eval(&source)
        end
      end
      tool
    end
  end
end
