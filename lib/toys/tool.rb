require "logger"
require "optparse"

module Toys
  class Tool
    DEFAULT_DESCRIPTION = "(No description available for this tool)"

    class Context
      def initialize(options:, name:, raw_args:, logger:, verbosity:)
        @_name_ = name
        @_raw_args_ = raw_args
        @_options_ = options
        @_logger_ = logger
        @_verbosity_ = verbosity
      end

      attr_reader :_name_
      attr_reader :_raw_args_
      attr_reader :_logger_
      attr_reader :_verbosity_
      attr_reader :_options_

      def [](key)
        @_options_[key]
      end
    end

    def initialize(name)
      @name = name.dup.freeze
      @long_desc = ""
      @short_desc = DEFAULT_DESCRIPTION
      @default_data = {}
      @switches = []
      @required_args = []
      @optional_args = []
      @remaining_args = nil
      @executor = nil
      @helpers = []
    end

    attr_reader :name

    attr_accessor :short_desc
    attr_accessor :long_desc
    attr_accessor :executor

    def helper_methods(name, &block)
      @helpers << block
    end

    def add_switch(key, default, *opts)
      key = Util.canonicalize_key(key)
      @default_data[key] = default
      @switches << [key, opts]
    end

    def add_required_arg(key, *opts)
      key = Util.canonicalize_key(key)
      @default_data[key] = nil
      @required_args << [key, build_arg_data(opts)]
    end

    def add_optional_arg(key, default, *opts)
      key = Util.canonicalize_key(key)
      @default_data[key] = default
      @optional_args << [key, build_arg_data(opts)]
    end

    def set_remaining_args(key, *opts)
      key = Util.canonicalize_key(key)
      @default_data[key] = []
      @remaining_args = [key, build_arg_data(opts)]
    end

    def execute(args)
      options, extras = parse_args(args)
      if extras[:show_help]
        puts extras[:show_help]
      else
        verbosity = extras[:verbosity]
        logger = Logger.new(STDERR)
        logger.level =
          if verbosity <= -2
            Logger::UNKNOWN
          elsif verbosity == -1
            Logger::FATAL
          elsif verbosity == 0
            Logger::WARN
          elsif verbosity == 1
            Logger::INFO
          elsif verbosity >= 2
            Logger::DEBUG
          end
        context = Context.new(options: options, name: name, raw_args: args,
          logger: logger, verbosity: verbosity)
        @helpers.each do |helper|
          context.instance_eval(&helper)
        end
        context.instance_eval(&@executor)
      end
    end

    private

    SPECIAL_FLAGS = ["-q", "--quiet", "-v", "--verbose", "-?", "-h", "--help"]

    def option_parser(option_data, extra_data)
      optparse = OptionParser.new
      banner = ["Usage:", Util::TOYS_BINARY] + @name
      banner << "[<options...>]" unless @switches.empty?
      @required_args.each do |key, opts|
        banner << "<#{Util.canonicalize_name(key)}>"
      end
      @optional_args.each do |key, opts|
        banner << "[<#{Util.canonicalize_name(key)}>]"
      end
      if @remaining_args
        banner << "[<#{Util.canonicalize_name(@remaining_args.first)}...>]"
      end
      optparse.banner = banner.join(" ")
      unless long_desc.empty?
        optparse.separator("")
        optparse.separator(long_desc)
      end
      optparse.separator("")
      optparse.separator("Options:")
      found_special_flags = []
      @switches.each do |key, opts|
        found_special_flags |= (opts & SPECIAL_FLAGS)
        optparse.on(*opts){ |val| option_data[key] = val }
      end
      flags = ["-v", "--verbose"] - found_special_flags
      unless flags.empty?
        optparse.on(*(flags + ["Increase verbosity"])) do
          extra_data[:verbosity] += 1
        end
      end
      flags = ["-q", "--quiet"] - found_special_flags
      unless flags.empty?
        optparse.on(*(flags + ["Decrease verbosity"])) do
          extra_data[:verbosity] -= 1
        end
      end
      flags = ["-?", "-h", "--help"] - found_special_flags
      unless flags.empty?
        optparse.on(*(flags + ["Show help message"])) do
          extra_data[:show_help] = optparse.to_s
        end
      end
      if !@required_args.empty? || !@optional_args.empty? || !@remaining_args
        optparse.separator("")
        optparse.separator("Positional arguments:")
        args_to_display = @required_args + @optional_args
        args_to_display << @remaining_args if @remaining_args
        args_to_display.each do |key, desc|
          optparse.separator("    #{Util.canonicalize_name(key).ljust(31)}  #{desc.first}")
          desc[1..-1].each do |d|
            optparse.separator("                                     #{d}")
          end
        end
      end
      optparse
    end

    def parse_args(args)
      optdata = @default_data.dup
      extra_data = {verbosity: 0}
      remaining = option_parser(optdata, extra_data).parse(args)
      @required_args.each do |key, _opts|
        if !extra_data[:show_help] && remaining.empty?
          raise UsageError, "No value given for required argument #{Util.canonicalize_name(key)}"
        end
        optdata[key] = remaining.shift
      end
      @optional_args.each do |key, _opts|
        break if remaining.empty?
        optdata[key] = remaining.shift
      end
      if !extra_data[:show_help] && !remaining.empty? && !@remaining_args
        raise UsageError, "Too many arguments provided"
      end
      optdata[@remaining_args[0]] = remaining if @remaining_args
      [optdata, extra_data]
    end

    def build_arg_data(opts)
      descriptions = []
      opts.each do |opt|
        case opt
        when String
          descriptions << opt
        else
          raise ArgumentError, "Unexpected argument: #{opt.inspect}"
        end
      end
      descriptions
    end

  end
end
