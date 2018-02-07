require "logger"
require "optparse"

module Toys
  class Tool

    def initialize(parent, name)
      @parent = parent
      @simple_name = name
      @full_name = name ? [name] : []
      @full_name = parent.full_name + @full_name if parent
      @cur_priority = 0
      @defined_modules = {}
      clear_fields
    end

    attr_reader :simple_name
    attr_reader :full_name

    attr_accessor :short_desc
    attr_accessor :long_desc
    attr_accessor :executor

    def check_priority(priority)
      return false if @cur_priority > priority
      if @cur_priority < priority
        clear_fields
        @cur_priority = priority
      end
      true
    end

    def add_helper(name, &block)
      @helpers[name.to_sym] = block
    end

    def define_helper_module(name, &block)
      unless name.is_a?(String)
        raise "Helper module name #{name.inspect} is not a string"
      end
      if @defined_modules.key?(name)
        raise "Helper module #{name.inspect} is already defined"
      end
      @defined_modules[name] = Module.new(&block)
    end

    def use_helper_module(mod)
      case mod
      when Module
        @modules << mod
      when Symbol
        mod = mod.to_s
        file_name = mod.gsub(/([a-zA-Z])([A-Z])/){ |m| "#{$1}_#{$2.downcase}" }.downcase
        require "toys/helpers/#{file_name}"
        const_name = mod.gsub(/_([a-zA-Z0-9])/){ |m| $1.upcase }.capitalize
        @modules << Toys::Helpers.const_get(const_name)
      when String
        @modules << mod
      else
        raise "Illegal helper module name: #{mod.inspect}"
      end
    end

    def add_switch(key, *switches, accept: nil, default: nil, doc: nil)
      @default_data[key] = default
      switches << "--#{canonical_switch(key)}=VALUE" if switches.empty?
      switches << accept unless accept.nil?
      switches += Array(doc)
      @switches << [key, switches]
    end

    def add_required_arg(key, accept: nil, doc: nil)
      @default_data[key] = nil
      @required_args << [key, accept, Array(doc)]
    end

    def add_optional_arg(key, accept: nil, default: nil, doc: nil)
      @default_data[key] = default
      @optional_args << [key, accept, Array(doc)]
    end

    def set_remaining_args(key, accept: nil, default: [], doc: nil)
      @default_data[key] = default
      @remaining_args = [key, accept, Array(doc)]
    end

    def execute(context, args)
      execution_data = parse_args(args, context.binary_name)
      context = create_child_context(context, args, execution_data)
      if execution_data[:usage_error]
        puts(execution_data[:usage_error])
        puts("")
        show_usage(context, execution_data[:optparse])
        -1
      elsif execution_data[:show_help]
        show_usage(context, execution_data[:optparse], recursive: execution_data[:recursive])
        0
      else
        process_result(context.instance_eval(&@executor))
      end
    end

    protected

    def default_desc
      @executor ? "(No description available)" : "(A collection of commands)"
    end

    def find_module_named(name)
      return @defined_modules[name] if @defined_modules.key?(name)
      return @parent.find_module_named(name) if @parent
      nil
    end

    private

    SPECIAL_FLAGS = ["-q", "--quiet", "-v", "--verbose", "-?", "-h", "--help"]

    def clear_fields
      @long_desc = nil
      @short_desc = nil
      @default_data = {}
      @switches = []
      @required_args = []
      @optional_args = []
      @remaining_args = nil
      @executor = nil
      @helpers = {}
      @modules = []
    end

    def leaf_option_parser(execution_data, binary_name)
      optparse = OptionParser.new
      banner = ["Usage:", binary_name] + full_name
      banner << "[<options...>]" unless @switches.empty?
      @required_args.each do |key, opts|
        banner << "<#{canonical_switch(key)}>"
      end
      @optional_args.each do |key, opts|
        banner << "[<#{canonical_switch(key)}>]"
      end
      if @remaining_args
        banner << "[<#{canonical_switch(@remaining_args.first)}...>]"
      end
      optparse.banner = banner.join(" ")
      desc = long_desc || short_desc || default_desc
      unless desc.empty?
        optparse.separator("")
        optparse.separator(desc)
      end
      optparse.separator("")
      optparse.separator("Options:")
      found_special_flags = []
      @switches.each do |key, opts|
        found_special_flags |= (opts & SPECIAL_FLAGS)
        optparse.on(*opts) do |val|
          execution_data[:options][key] = val
        end
      end
      flags = ["-v", "--verbose"] - found_special_flags
      unless flags.empty?
        optparse.on(*(flags + ["Increase verbosity"])) do
          execution_data[:delta_severity] -= 1
        end
      end
      flags = ["-q", "--quiet"] - found_special_flags
      unless flags.empty?
        optparse.on(*(flags + ["Decrease verbosity"])) do
          execution_data[:delta_severity] += 1
        end
      end
      flags = ["-?", "-h", "--help"] - found_special_flags
      unless flags.empty?
        optparse.on(*(flags + ["Show help message"])) do
          execution_data[:show_help] = true
        end
      end
      optparse
    end

    def collection_option_parser(execution_data, binary_name)
      optparse = OptionParser.new
      optparse.banner = (["Usage:", binary_name] + full_name + ["<command>", "[<options...>]"]).join(" ")
      desc = long_desc || short_desc || default_desc
      unless desc.empty?
        optparse.separator("")
        optparse.separator(desc)
      end
      optparse.separator("")
      optparse.separator("Options:")
      optparse.on("-?", "--help", "Show help message")
      optparse.on("-r", "--[no-]recursive", "Show all subcommands recursively") do |val|
        execution_data[:recursive] = val
      end
      execution_data[:show_help] = true
      optparse
    end

    def parse_args(args, binary_name)
      optdata = @default_data.dup
      execution_data = {
        show_help: false,
        usage_error: nil,
        delta_severity: 0,
        recursive: false,
        options: optdata
      }
      begin
        binary_name ||= File.basename($0)
        option_parser = @executor ?
          leaf_option_parser(execution_data, binary_name) :
          collection_option_parser(execution_data, binary_name)
        execution_data[:optparse] = option_parser
        remaining = option_parser.parse(args)
        @required_args.each do |key, accept, doc|
          if !execution_data[:show_help] && remaining.empty?
            error = OptionParser::ParseError.new(*args)
            error.reason = "No value given for required argument <#{canonical_switch(key)}>"
            raise error
          end
          optdata[key] = process_value(key, remaining.shift, accept)
        end
        @optional_args.each do |key, accept, doc|
          break if remaining.empty?
          optdata[key] = process_value(key, remaining.shift, accept)
        end
        unless remaining.empty?
          if !@remaining_args
            if @executor
              error = OptionParser::ParseError.new(*remaining)
              error.reason = "Extra arguments provided"
              raise error
            else
              error = OptionParser::ParseError.new(*(full_name + args))
              error.reason = "Tool not found"
              raise error
            end
          end
          key = @remaining_args[0]
          accept = @remaining_args[1]
          optdata[key] = remaining.map{ |arg| process_value(key, arg, accept) }
        end
      rescue OptionParser::ParseError => e
        execution_data[:usage_error] = e
      end
      execution_data
    end

    def create_child_context(parent_context, args, execution_data)
      context = parent_context._create_child(full_name, args, execution_data[:options])
      context.logger.level += execution_data[:delta_severity]
      @modules.each do |mod|
        unless Module === mod
          found = find_module_named(mod)
          raise "Unable to find module #{mod}" unless found
          mod = found
        end
        context.extend(mod)
      end
      @helpers.each do |name, block|
        context.define_singleton_method(name, &block)
      end
      context
    end

    def show_usage(context, optparse, recursive: false)
      puts(optparse.to_s)
      if @executor
        if !@required_args.empty? || !@optional_args.empty? || @remaining_args
          puts("")
          puts("Positional arguments:")
          args_to_display = @required_args + @optional_args
          args_to_display << @remaining_args if @remaining_args
          args_to_display.each do |key, accept, doc|
            puts("    #{canonical_switch(key).ljust(31)}  #{doc.first}")
            doc[1..-1].each do |d|
              puts("                                     #{d}")
            end
          end
        end
      else
        puts("")
        puts("Commands:")
        name_len = full_name.length
        context._lookup.list_subtools(full_name, recursive).each do |tool|
          desc = tool.short_desc || tool.default_desc
          tool_name = tool.full_name.slice(name_len..-1).join(' ').ljust(31)
          puts("    #{tool_name}  #{desc}")
        end
      end
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

    def canonical_switch(name)
      name.to_s.downcase.gsub("_", "-").gsub(/[^a-z0-9-]/, "")
    end

    def process_value(key, val, accept)
      return val unless accept
      n = canonical_switch(key)
      result = val
      optparse = OptionParser.new
      optparse.on("--#{n}=VALUE", accept){ |v| result = v }
      optparse.parse(["--#{n}", val])
      result
    end

    def process_result(result)
      return result if result.is_a?(Integer)
      return 0 if result == true
      return 1 if result == false
      0
    end
  end
end
