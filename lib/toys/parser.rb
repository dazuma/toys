module Toys
  class Parser
    def initialize(lookup, tool, remaining_words, allow_toplevel)
      @lookup = lookup
      @tool = tool
      @remaining_words = remaining_words
      @allow_toplevel = allow_toplevel
    end

    def name(word, &block)
      word = word.to_s
      tool = @lookup.get_tool(@tool.full_name + [word])
      remaining = @remaining_words.first == word ? @remaining_words[1..-1] : []
      parser = Parser.new(@lookup, tool, remaining, true)
      parser.instance_eval(&block)
    end

    def include(path)
      @lookup.lookup_dir(path, @tool.full_name, @remaining_words)
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
      raise "Cannot define a tool here" unless @allow_toplevel
      @tool.add_switch(key, *switches, accept: accept, default: default, doc: doc)
      self
    end

    def required_arg(key, accept: nil, doc: nil)
      raise "Cannot define a tool here" unless @allow_toplevel
      @tool.add_required_arg(key, accept: accept, doc: doc)
      self
    end

    def optional_arg(key, accept: nil, default: nil, doc: nil)
      raise "Cannot define a tool here" unless @allow_toplevel
      @tool.add_optional_arg(key, accept: accept, default: default, doc: doc)
      self
    end

    def remaining_args(key, accept: nil, default: nil, doc: nil)
      raise "Cannot define a tool here" unless @allow_toplevel
      @tool.set_remaining_args(key, accept: accept, default: default, doc: doc)
      self
    end

    def execute(&block)
      raise "Cannot define a tool here" unless @allow_toplevel
      @tool.executor = block
      self
    end

    def helper(name, shared: false, &block)
      @tool.add_helper(name, shared: shared, &block)
    end

    def helper_module(mod, shared: false)
      @tool.add_helper_module(mod, shared: shared)
    end

    def _binding
      binding
    end
  end
end
