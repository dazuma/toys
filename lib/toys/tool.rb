require "logger"
require "optparse"

module Toys
  class Tool
    def initialize(lookup, parent, name)
      @lookup = lookup
      @parent = parent
      @simple_name = name
      @full_name = parent ? parent.full_name + [name] : []

      @definition_path = nil
      @cur_path = nil

      @alias_target = nil

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

    def includes_description?
      !@long_desc.nil? || !@short_desc.nil?
    end

    def includes_definition?
      !@default_data.empty? || !@switches.empty? ||
        !@required_args.empty? || !@optional_args.empty? ||
        !@remaining_args.nil? || @executor.respond_to?(:call) ||
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
        @definition_path = @cur_path if includes_description? || includes_definition?
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

    def make_alias_of_word(target_word)
      if root?
        raise Toys::ToysDefinitionError, "Cannot make the root tool an alias"
      end
      target_name = full_name.slice(0..-2) + [target_word]
      target_tool = @lookup.lookup(target_name)
      unless target_tool.full_name == target_name
        raise Toys::ToysDefinitionError, "Alias target #{target.inspect} not found"
      end
      make_alias_of_tool(target_tool)
    end

    def make_alias_of_tool(target_tool)
      if only_collection?
        raise ToolDefinitionError, "Tool #{display_name.inspect} is already" \
          " a collection and cannot be made an alias"
      end
      if includes_description? || includes_definition?
        raise ToolDefinitionError, "Tool #{display_name.inspect} already has" \
          " a definition and cannot be made an alias"
      end
      if @executor == false
        raise ToolDefinitionError, "Cannot make tool #{display_name.inspect}" \
          " an alias because a descendant is already executable"
      end
      @parent.ensure_collection_only(full_name) if @parent
      @alias_target = target_tool
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
        file_name =
          mod
          .gsub(/([a-zA-Z])([A-Z])/) { |_m| "#{$1}_#{$2.downcase}" }
          .downcase
        require "toys/helpers/#{file_name}"
        const_name = mod.gsub(/(^|_)([a-zA-Z0-9])/) { |_m| $2.upcase }
        @modules << Toys::Helpers.const_get(const_name)
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
        show_usage(execution_data[:optparse])
        -1
      elsif execution_data[:show_help]
        show_usage(execution_data[:optparse], recursive: execution_data[:recursive])
        0
      else
        catch(:result) do
          context.instance_eval(&@executor)
          0
        end
      end
    end

    protected

    def ensure_collection_only(source_name)
      if includes_definition?
        raise ToolDefinitionError, "Cannot create tool #{source_name.inspect}" \
          " because #{display_name.inspect} is already a tool."
      end
      if @executor != false
        @executor = false
        @parent.ensure_collection_only(source_name) if @parent
      end
    end

    private

    SPECIAL_FLAGS = %w[
      -q
      --quiet
      -v
      --verbose
      -?
      -h
      --help
    ].freeze

    def default_desc
      if @alias_target
        "(Alias of #{@alias_target.display_name.inspect})"
      elsif @executor
        "(No description available)"
      else
        "(A collection of commands)"
      end
    end

    def check_definition_state(execution_field = false)
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
                "Cannot make tool #{display_name.inspect} executable because" \
                " a descendant is already executable"
        end
        @parent.ensure_collection_only(full_name) if @parent
      end
    end

    def leaf_option_parser(execution_data, binary_name)
      optparse = OptionParser.new
      optparse.banner = compute_leaf_banner(binary_name)
      desc = @long_desc || @short_desc || default_desc
      unless desc.empty?
        optparse.separator("")
        optparse.separator(desc)
      end
      optparse.separator("")
      optparse.separator("Options:")
      found_special_flags = []
      configure_normal_switches(optparse, execution_data, found_special_flags)
      configure_verbose_switch(optparse, execution_data, found_special_flags)
      configure_quiet_switch(optparse, execution_data, found_special_flags)
      configure_help_switch(optparse, execution_data, found_special_flags)
      optparse
    end

    def compute_leaf_banner(binary_name)
      banner = ["Usage:", binary_name] + full_name
      banner << "[<options...>]" unless @switches.empty?
      @required_args.each do |key, _opts|
        banner << "<#{canonical_switch(key)}>"
      end
      @optional_args.each do |key, _opts|
        banner << "[<#{canonical_switch(key)}>]"
      end
      if @remaining_args
        banner << "[<#{canonical_switch(@remaining_args.first)}...>]"
      end
      banner.join(" ")
    end

    def configure_normal_switches(optparse, execution_data, found_special_flags)
      @switches.each do |key, opts|
        found_special_flags |= (opts & SPECIAL_FLAGS)
        optparse.on(*opts) do |val|
          execution_data[:options][key] = val
        end
      end
    end

    def configure_verbose_switch(optparse, execution_data, found_special_flags)
      flags = ["-v", "--verbose"] - found_special_flags
      return if flags.empty?
      optparse.on(*(flags + ["Increase verbosity"])) do
        execution_data[:delta_severity] -= 1
      end
    end

    def configure_quiet_switch(optparse, execution_data, found_special_flags)
      flags = ["-q", "--quiet"] - found_special_flags
      return if flags.empty?
      optparse.on(*(flags + ["Decrease verbosity"])) do
        execution_data[:delta_severity] += 1
      end
    end

    def configure_help_switch(optparse, execution_data, found_special_flags)
      flags = ["-?", "-h", "--help"] - found_special_flags
      return if flags.empty?
      optparse.on(*(flags + ["Show help message"])) do
        execution_data[:show_help] = true
      end
    end

    def collection_option_parser(execution_data, binary_name)
      optparse = OptionParser.new
      optparse.banner =
        (["Usage:", binary_name] + full_name + ["<command>", "[<options...>]"]).join(" ")
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

    def create_option_parser(execution_data, binary_name)
      option_parser =
        if @executor
          leaf_option_parser(execution_data, binary_name)
        else
          collection_option_parser(execution_data, binary_name)
        end
      execution_data[:optparse] = option_parser
      option_parser
    end

    def parse_required_args(remaining, execution_data, args)
      @required_args.each do |key, accept, _doc|
        if !execution_data[:show_help] && remaining.empty?
          reason = "No value given for required argument named <#{canonical_switch(key)}>"
          raise create_parse_error(args, reason)
        end
        execution_data[:options][key] = process_value(key, remaining.shift, accept)
      end
      remaining
    end

    def parse_optional_args(remaining, execution_data)
      @optional_args.each do |key, accept, _doc|
        break if remaining.empty?
        execution_data[:options][key] = process_value(key, remaining.shift, accept)
      end
      remaining
    end

    def parse_remaining_args(remaining, execution_data, args)
      return if remaining.empty?
      unless @remaining_args
        if @executor
          raise create_parse_error(remaining, "Extra arguments provided")
        else
          raise create_parse_error(full_name + args, "Tool not found")
        end
      end
      key = @remaining_args[0]
      accept = @remaining_args[1]
      execution_data[:options][key] = remaining.map { |arg| process_value(key, arg, accept) }
    end

    def parse_args(args, binary_name)
      binary_name ||= File.basename($PROGRAM_NAME)
      execution_data = {
        show_help: false,
        usage_error: nil,
        delta_severity: 0,
        recursive: false,
        options: @default_data.dup
      }
      begin
        option_parser = create_option_parser(execution_data, binary_name)
        remaining = option_parser.parse(args)
        remaining = parse_required_args(remaining, execution_data, args)
        remaining = parse_optional_args(remaining, execution_data)
        parse_remaining_args(remaining, execution_data, args)
      rescue OptionParser::ParseError => e
        execution_data[:usage_error] = e
      end
      execution_data
    end

    def create_child_context(parent_context, args, execution_data)
      context = parent_context._create_child(full_name, args, execution_data[:options])
      context.logger.level += execution_data[:delta_severity]
      @modules.each do |mod|
        context.extend(mod)
      end
      @helpers.each do |name, block|
        context.define_singleton_method(name, &block)
      end
      context
    end

    def show_usage(optparse, recursive: false)
      puts(optparse.to_s)
      if @executor
        if !@required_args.empty? || !@optional_args.empty? || @remaining_args
          show_positional_arguments
        end
      else
        show_command_list(recursive)
      end
    end

    def show_positional_arguments
      puts("")
      puts("Positional arguments:")
      args_to_display = @required_args + @optional_args
      args_to_display << @remaining_args if @remaining_args
      args_to_display.each do |key, _accept, doc|
        puts("    #{canonical_switch(key).ljust(31)}  #{doc.first}")
        next if doc.empty?
        doc[1..-1].each do |d|
          puts("                                     #{d}")
        end
      end
    end

    def show_command_list(recursive)
      puts("")
      puts("Commands:")
      name_len = full_name.length
      @lookup.list_subtools(full_name, recursive).each do |tool|
        desc = tool.effective_short_desc
        tool_name = tool.full_name.slice(name_len..-1).join(" ").ljust(31)
        puts("    #{tool_name}  #{desc}")
      end
    end

    def canonical_switch(name)
      name.to_s.downcase.tr("_", "-").gsub(/[^a-z0-9-]/, "")
    end

    def process_value(key, val, accept)
      return val unless accept
      n = canonical_switch(key)
      result = val
      optparse = OptionParser.new
      optparse.on("--#{n}=VALUE", accept) { |v| result = v }
      optparse.parse(["--#{n}", val])
      result
    end

    def create_parse_error(path, reason)
      OptionParser::ParseError.new(*path).tap do |e|
        e.reason = reason
      end
    end
  end
end
