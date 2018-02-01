module Toys
  class Parser
    def initialize(words, saver, allow_toplevel: false, path_adder: nil)
      @words = words
      @tool = Tool.new(words)
      @allow_toplevel = allow_toplevel
      @path_adder = path_adder
      @saver = saver
    end

    def name(word, &block)
      subparser = Parser.new(@words + [word.to_s], @saver, allow_toplevel: true)
      subparser.instance_eval(&block)
      subparser._finish
      self
    end

    def path(path)
      raise "Cannot add a path here" unless @path_adder
      @path_adder.call(path)
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

    def switch(key, default, *opts)
      raise "Cannot define a tool here" unless @allow_toplevel
      @tool.add_switch(key, default, *opts)
      self
    end

    def required_arg(key, *opts)
      raise "Cannot define a tool here" unless @allow_toplevel
      @tool.add_required_arg(key, *opts)
      self
    end

    def optional_arg(key, default, *opts)
      raise "Cannot define a tool here" unless @allow_toplevel
      @tool.add_optional_arg(key, default, *opts)
      self
    end

    def remaining_args(key, *opts)
      raise "Cannot define a tool here" unless @allow_toplevel
      @tool.set_remaining_args(key, *opts)
      self
    end

    def execute(&block)
      raise "Cannot define a tool here" unless @allow_toplevel
      @tool.executor = block
      self
    end

    def _parse(path)
      str = IO.read(path)
      eval(str, binding, path, 1)
      _finish
    end

    def _finish
      @saver.call(@words, @tool)
    end
  end
end
