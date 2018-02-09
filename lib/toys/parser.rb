module Toys
  class Parser
    def initialize(path, tool, remaining_words, lookup)
      @path = path
      @tool = tool
      @remaining_words = remaining_words
      @lookup = lookup
    end

    def name(word, alias_of: nil, &block)
      word = word.to_s
      subtool = @lookup.get_tool(@tool.full_name + [word])
      if alias_of
        if block
          raise Toys::ToysDefinitionError, "Cannot take a block with alias_of"
        end
        unless alias_of.is_a?(Array)
          alias_of = @tool.full_name + [alias_of.to_s]
        end
        target = @lookup.lookup(alias_of)
        if target.full_path != alias_of
          raise Toys::ToysDefinitionError,
            "Cannot find alias target #{alias_of.join(' ').inspect}"
        end
        subtool.alias_target = target
        return self
      end
      next_remaining = @remaining_words
      if next_remaining && !next_remaining.empty?
        if next_remaining.first == word
          next_remaining = next_remaining.slice(1..-1)
        else
          next_remaining = nil
        end
      end
      Parser.parse(@path, subtool, next_remaining, @lookup, block)
      self
    end

    def alias_as(word)
      unless @tool.root?
        alias_tool = @lookup.get_tool(@tool.full_name.slice(0..-2) + [word])
        alias_tool.alias_target = @tool
      end
      self
    end

    def include(path)
      @tool.yield_definition do
        @lookup.include_path(path, @tool.full_name, @remaining_words)
      end
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

    def helper_module(mod, &block)
      if block
        @tool.define_helper_module(mod, &block)
      else
        @tool.use_helper_module(mod)
      end
      self
    end

    def _binding
      binding
    end

    def self.parse(path, tool, remaining_words, lookup, source)
      parser = new(path, tool, remaining_words, lookup)
      tool.defining_from(path) do
        if String === source
          eval(source, parser._binding, path, 1)
        elsif Proc === source
          parser.instance_eval(&source)
        end
      end
      tool
    end
  end
end
