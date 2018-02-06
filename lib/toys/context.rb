module Toys
  class Context
    def initialize(lookup, logger: nil, verbosity: 0)
      @lookup = lookup
      @logger = logger || Logger.new(STDERR)
      @tool_name = []
      @args = []
      @options = {}
      @verbosity = verbosity
    end

    attr_reader :lookup
    attr_reader :logger
    attr_accessor :tool_name
    attr_accessor :args
    attr_accessor :options
    attr_accessor :verbosity

    def [](key)
      @options[key]
    end

    def run(*args)
      args = args.flatten
      tool = @lookup.lookup(args)
      context = Context.new(@lookup, logger: @logger, verbosity: @verbosity)
      tool.execute(context, args.slice(tool.full_name.length..-1))
    end
  end
end
