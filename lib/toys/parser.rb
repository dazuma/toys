module Toys
  class Parser
    def initialize(lookup, tool, remaining_words, priority)
      @lookup = lookup
      @tool = tool
      @remaining_words = remaining_words
      @priority = priority
    end

    def name(word, &block)
      word = word.to_s
      subtool = @lookup.get_tool(@tool.full_name + [word])
      next_remaining = @remaining_words
      if next_remaining && !next_remaining.empty?
        if next_remaining.first == word
          next_remaining = next_remaining.slice(1..-1)
        else
          next_remaining = nil
        end
      end
      parser = Parser.new(@lookup, subtool, next_remaining, @priority)
      parser.instance_eval(&block)
    end

    def include(path)
      @lookup.include_path(path, @tool.full_name, @remaining_words, @priority + 1)
      self
    end

    def long_desc(desc)
      if @tool.check_priority(@priority)
        @tool.long_desc = desc
      end
      self
    end

    def short_desc(desc)
      if @tool.check_priority(@priority)
        @tool.short_desc = desc
      end
      self
    end

    def switch(key, *switches, accept: nil, default: nil, doc: nil)
      if @tool.check_priority(@priority)
        @tool.add_switch(key, *switches, accept: accept, default: default, doc: doc)
      end
      self
    end

    def required_arg(key, accept: nil, doc: nil)
      if @tool.check_priority(@priority)
        @tool.add_required_arg(key, accept: accept, doc: doc)
      end
      self
    end

    def optional_arg(key, accept: nil, default: nil, doc: nil)
      if @tool.check_priority(@priority)
        @tool.add_optional_arg(key, accept: accept, default: default, doc: doc)
      end
      self
    end

    def remaining_args(key, accept: nil, default: [], doc: nil)
      if @tool.check_priority(@priority)
        @tool.set_remaining_args(key, accept: accept, default: default, doc: doc)
      end
      self
    end

    def execute(&block)
      if @tool.check_priority(@priority)
        @tool.executor = block
      end
      self
    end

    def helper(name, &block)
      if @tool.check_priority(@priority)
        @tool.add_helper(name, &block)
      end
    end

    def helper_module(mod, &block)
      if block
        @tool.define_helper_module(mod, &block)
      else
        if @tool.check_priority(@priority)
          @tool.use_helper_module(mod)
        end
      end
    end

    def _binding
      binding
    end
  end
end
