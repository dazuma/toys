require "logger"
require "optparse"

module Toys
  class Tool

    def initialize(parent, name)
      @parent = parent
      @simple_name = name
      @full_name = name ? [name] : []
      @full_name = parent.full_name + @full_name if parent

      @definition_path = nil
      @cur_path = nil

      @alias_target = nil
      @alias_target_args = nil

      @long_desc = nil
      @short_desc = nil

      @default_data = {}
      @switches = []
      @required_args = []
      @optional_args = []
      @remaining_args = nil
      @helpers = {}
      @modules = []
      @executor = nil

      @defined_modules = {}
    end

    attr_reader :simple_name
    attr_reader :full_name

    def root?
      @parent.nil?
    end

    def display_name
      full_name.join(" ")
    end

    def effective_short_desc
      @short_desc || default_desc
    end

    def effective_long_desc
      @long_desc || @short_desc || default_desc
    end

    def has_description?
      !@long_desc.nil? || !@short_desc.nil?
    end

    def has_definition?
      !@default_data.empty? || !@switches.empty? ||
        !@required_args.empty? || !@optional_args.empty? ||
        !@remaining_args.nil? || !!@executor ||
        !@helpers.empty? || !@modules.empty?
    end

    def only_collection?
      @executor == false
    end

    def defining_from(path)
      raise ToolDefinitionError, "Already being defined" if @cur_path
      @cur_path = path
      begin
        yield
      ensure
        @definition_path = @cur_path if has_description? || has_definition?
        @cur_path = nil
      end
    end

    def yield_definition
      saved_path = @cur_path
      @cur_path = nil
      begin
        yield
      ensure
        @cur_path = saved_path
      end
    end

    def set_alias_target(target_tool, target_args=[])
      unless target_tool.is_a?(Toys::Tool)
        raise ArgumentError, "Illegal target type"
      end
      if only_collection?
        raise ToolDefinitionError, "Tool #{display_name.inspect} is already" \
          " a collection and cannot be made an alias"
      end
      if has_description? || has_definition?
        raise ToolDefinitionError, "Tool #{display_name.inspect} already has" \
          " a definition and cannot be made an alias"
      end
      if @executor == false
        raise ToolDefinitionError, "Cannot make tool #{display_name.inspect}" \
          " an alias because a descendant is already executable"
      end
      @parent.ensure_collection_only(full_name) if @parent
      @alias_target = target_tool
      @alias_target_args = target_args
    end

    def define_helper_module(name, &block)
      if @alias_target
        raise ToolDefinitionError, "Tool #{display_name.inspect} is an alias"
      end
      unless name.is_a?(String)
        raise ToolDefinitionError,
          "Helper module name #{name.inspect} is not a string"
      end
      if @defined_modules.key?(name)
        raise ToolDefinitionError,
          "Helper module #{name.inspect} is already defined"
      end
      mod = Module.new(&block)
      mod.instance_methods.each do |meth|
        name_str = meth.to_s
        unless name_str =~ /^[a-z]\w+$/
          raise ToolDefinitionError,
            "Illegal helper method name: #{name_str.inspect}"
        end
      end
      @defined_modules[name] = mod
    end

    def short_desc=(str)
      check_definition_state
      @short_desc = str
    end

    def long_desc=(str)
      check_definition_state
      @long_desc = str
    end

    def add_helper(name, &block)
      check_definition_state(true)
      name_str = name.to_s
      unless name_str =~ /^[a-z]\w+$/
        raise ToolDefinitionError, "Illegal helper name: #{name_str.inspect}"
      end
      @helpers[name.to_sym] = block
    end

    def use_helper_module(mod)
      check_definition_state(true)
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
        raise ToolDefinitionError, "Illegal helper module name: #{mod.inspect}"
      end
    end

    def add_switch(key, *switches, accept: nil, default: nil, doc: nil)
      check_definition_state(true)
      @default_data[key] = default
      switches << "--#{canonical_switch(key)}=VALUE" if switches.empty?
      switches << accept unless accept.nil?
      switches += Array(doc)
      @switches << [key, switches]
    end

    def add_required_arg(key, accept: nil, doc: nil)
      check_definition_state(true)
      @default_data[key] = nil
      @required_args << [key, accept, Array(doc)]
    end

    def add_optional_arg(key, accept: nil, default: nil, doc: nil)
      check_definition_state(true)
      @default_data[key] = default
      @optional_args << [key, accept, Array(doc)]
    end

    def set_remaining_args(key, accept: nil, default: [], doc: nil)
      check_definition_state(true)
      @default_data[key] = default
      @remaining_args = [key, accept, Array(doc)]
    end

    def executor=(executor)
      check_definition_state(true)
      @executor = executor
    end

    def execute(context, args)
      return @alias_target.execute(context, args) if @alias_target
      execution_data = parse_args(args, context.binary_name)
      context = create_child_context(context, args, execution_data)
      if execution_data[:usage_error]
        puts(execution_data[:usage_error])
        puts("")
        show_usage(context, execution_data[:optparse])
        -1
      elsif execution_data[:show_help]
        show_usage(context, execution_data[:optparse],
                   recursive: execution_data[:recursive])
        0
      else
        catch(:result) do
          context.instance_eval(&@executor)
          0
        end
      end
    end

    protected

    def find_module_named(name)
      return @defined_modules[name] if @defined_modules.key?(name)
      return @parent.find_module_named(name) if @parent
      nil
    end

    def ensure_collection_only(source_name)
      if has_definition?
        raise ToolDefinitionError, "Cannot create tool #{source_name.inspect}" \
          " because #{display_name.inspect} is already a tool."
      end
      if @executor != false
        @executor = false
        @parent.ensure_collection_only(source_name) if @parent
      end
    end

    private

    SPECIAL_FLAGS = ["-q", "--quiet", "-v", "--verbose", "-?", "-h", "--help"]

    def default_desc
      if @alias_target
        "(Alias of #{(@alias_target.full_name + @alias_target_args).join(' ').inspect})"
      elsif @executor
        "(No description available)"
      else
        "(A collection of commands)"
      end
    end

    def check_definition_state(execution_field=false)
      if @alias_target
        raise ToolDefinitionError, "Tool #{display_name.inspect} is an alias"
      end
      if @definition_path
        in_clause = @cur_path ? "in #{@cur_path} " : ""
        raise ToolDefinitionError,
          "Cannot redefine tool #{display_name.inspect} #{in_clause}" \
          "(already defined in #{@definition_path})"
      end
      if execution_field
        if @executor == false
          raise ToolDefinitionError,
            "Cannot make tool #{display_name.inspect} executable because a" \
            " descendant is already executable"
        end
        @parent.ensure_collection_only(full_name) if @parent
      end
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
      desc = @long_desc || @short_desc || default_desc
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
      desc = @long_desc || @short_desc || default_desc
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
            error.reason = "No value given for required argument named <#{canonical_switch(key)}>"
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
      context = parent_context._create_child(
        full_name, args, execution_data[:options])
      context.logger.level += execution_data[:delta_severity]
      @modules.each do |mod|
        unless Module === mod
          found = find_module_named(mod)
          raise StandardError, "Unable to find module #{mod}" unless found
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
            end unless doc.empty?
          end
        end
      else
        puts("")
        puts("Commands:")
        name_len = full_name.length
        context._lookup.list_subtools(full_name, recursive).each do |tool|
          desc = tool.effective_short_desc
          tool_name = tool.full_name.slice(name_len..-1).join(' ').ljust(31)
          puts("    #{tool_name}  #{desc}")
        end
      end
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
  end
end
