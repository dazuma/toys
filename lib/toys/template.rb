module Toys
  class Template
    def initialize
      @opts_initializer = ->(opts){opts}
      @expander = ->(opts){}
    end

    def to_init_opts(&block)
      @opts_initializer = block
      self
    end

    def to_expand(&block)
      @expander = block
      self
    end

    attr_reader :opts_initializer
    attr_reader :expander
  end
end
