# frozen_string_literal: true

desc "Run multiple tools in order"

long_desc \
  "The \"toys do\" builtin provides a convenient interface for running multiple tools in" \
    " sequence. Provide the tools to run as arguments, separated by a delimiter (which is" \
    " the string \",\" by default). Toys will run them in order, stopping if any tool" \
    " returns a nonzero exit code.",
  "",
  "Example: Suppose you have a \"rails build\" tool and a \"deploy\" tool. You could run them" \
    " in order like this:",
  ["    toys do rails build --staging , deploy --migrate"],
  "",
  "You may change the delimiter using the --delim flag. For example:",
  ["    toys do --delim=/ rails build --staging / deploy --migrate"],
  "The --delim flag must appear first before the tools to run. Any flags that appear later in" \
    " the command line will be passed to the tools themselves.",
  "",
  "You may also make the tools from a gem available to the tools you run, by passing the" \
    " --gem flag. For example:",
  ["    toys do --gem=my-tools deploy --migrate"],
  "The tools from the gem take priority over the tools that would otherwise be found."

flag :delim do
  flags "-d", "--delim=VALUE"
  default ","
  desc "Set the delimiter"
  long_desc "Sets the delimiter that separates tool invocations. The default value is \",\"."
end

flag :gems do
  flags "--gem=NAME"
  handler :push
  default []
  desc "Make the tools from the given gem available"
  long_desc \
    "Adds the tools from the given gem, installing the gem if necessary. These tools take" \
      " priority over the tools that would otherwise be found. This flag may be provided" \
      " multiple times to add multiple gems; if two gems define the same tool, the gem" \
      " appearing earlier on the command line takes priority."
end

remaining_args :commands do
  complete do |context|
    commands = context.arg_parser.data[:commands]
    last_command = commands.inject([]) { |acc, arg| arg == "," ? [] : (acc << arg) }
    new_context = context.with(previous_words: last_command, disable_flags: commands.empty?)
    new_context.tool.completion.call(new_context)
  end
  desc "A series of tools to run, separated by the delimiter"
end

enforce_flags_before_args

def run
  tool_cli = build_cli
  commands
    .chunk { |arg| arg == delim ? :_separator : true }
    .each do |_, action|
      code = tool_cli.run(action)
      exit(code) unless code.zero?
    end
end

# Returns the CLI used to run the requested tools. Normally this is simply the
# current CLI, but if gems were requested, we need a new CLI because sources
# cannot be added to a loader that has already started loading tools. The new
# CLI copies the current sources and adds the gems on top of them. The gems are
# added in reverse order so that the first gem on the command line ends up with
# the highest priority.
def build_cli
  return cli if gems.empty?
  cli.child(copy_loader_sources: true) do |child_cli|
    gems.reverse_each do |gem_name|
      child_cli.add_config_gem(gem_name, high_priority: true)
    end
  end
end
