# frozen_string_literal: true

mixin "tool-methods" do
  def format_tool(tool, namespace, detailed: false)
    output = {
      "name" => tool.full_name[namespace.length..-1].join(" "),
      "desc" => tool.desc.to_s,
      "runnable" => tool.runnable?,
    }
    if detailed
      output["exists"] = true
      output["long_desc"] = tool.long_desc.map(&:to_s)
    end
    output
  end

  def choose_loader(local, from_dir)
    return cli.loader unless local || from_dir
    special_cli = if local
                    cli.child.add_search_path(from_dir || ::Dir.getwd)
                  else
                    ::Toys::StandardCLI.new(cur_dir: from_dir)
                  end
    special_cli.loader
  end
end

desc "Tools that introspect available tools"

long_desc \
  "Tools that introspect the available tools."

tool "list" do
  desc "Output a list of the tools under the given namespace."

  long_desc \
    "Outputs a list of the tools under the given namespace, in YAML format, to the standard " \
      "output stream."

  remaining_args :namespace

  flag :local do
    desc "List only tools defined locally in the current directory."
  end
  flag :recursive, "--[no-]recursive" do
    desc "Recursively list subtools"
  end
  flag :flatten, "--[no-]flatten" do
    desc "Display a flattened list of tools"
  end
  flag :from_dir, "--dir=PATH" do
    desc "List tools from the given directory."
  end
  flag :show_all, "--all" do
    desc "Show all tools, including hidden tools and non-runnable namespaces"
  end

  include "tool-methods"
  include "output-tools"

  def run
    loader = choose_loader(local, from_dir)
    words = namespace
    words = loader.split_path(words.first) if words.size == 1
    tool_list = loader.list_subtools(words,
                                     recursive: recursive,
                                     include_hidden: show_all,
                                     include_namespaces: show_all || !flatten,
                                     include_non_runnable: show_all)
    output = {
      "namespace" => words.join(" "),
      "tools" => [],
    }
    if flatten
      output["tools"] = tool_list.map { |tool| format_tool(tool, words) }
    else
      format_tool_list(tool_list, output, words)
    end
    puts(generate_output(output))
  end

  def format_tool_list(tool_list, toplevel, cur_ns)
    stack = [toplevel]
    tool_list.each do |tool|
      tool_name_size = tool.full_name.size
      while cur_ns.size >= tool_name_size
        stack.pop
        cur_ns.pop
      end
      formatted = format_tool(tool, cur_ns)
      (stack.last["tools"] ||= []) << formatted
      stack.push(formatted)
      cur_ns.push(tool.full_name.last)
    end
  end
end

tool "show" do
  desc "Show detailed information about a single tool"

  long_desc \
    "Outputs details about the given tool, in YAML format, to the standard output stream."

  remaining_args :name

  flag :local do
    desc "Show only tools defined locally in the current directory."
  end
  flag :from_dir, "--dir=PATH" do
    desc "Show a tool accessible from the given directory."
  end

  include "tool-methods"
  include "output-tools"

  def run
    loader = choose_loader(local, from_dir)
    words = name
    words = loader.split_path(words.first) if words.size == 1
    tool = loader.lookup_specific(words)
    output =
      if tool.nil?
        {
          "name" => words.join(" "),
          "exists" => false,
        }
      else
        format_tool(tool, [], detailed: true)
      end
    puts(generate_output(output))
    exit(tool.nil? ? 1 : 0)
  end
end
