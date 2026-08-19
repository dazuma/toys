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
  "The tools from the gem take priority over the tools that would otherwise be found. You may" \
    " also include version requirements for the gem. For example:",
  ["    toys do --gem=\"my-tools, ~> 1.5, >= 1.5.2\" deploy --migrate"],
  "Note that the commas separating the version requirements are part of the --gem flag value," \
    " and are unrelated to the delimiter that separates the tools to run."

flag :delim do
  flags "-d", "--delim=VALUE"
  default ","
  desc "Set the delimiter"
  long_desc "Sets the delimiter that separates tool invocations. The default value is \",\"."
end

# The source flags all share the :sources key, and their handlers append to
# the same array, tagging each value with the kind of source requested. That
# way the array records the order in which the flags appeared on the command
# line, across all of the flags, which is the order that determines priority.
# The handlers store the raw value; parsing happens later, in build_cli,
# because an error raised from a handler would come out of the argument parser
# as a stack trace rather than as a simple message.

flag :sources do
  flags "--gem=GEM"
  handler { |val, prev| prev + [[:gem, val]] }
  default []
  desc "Make the tools from the given gem available"
  long_desc \
    "Adds the tools from the given gem, prompting to install the gem if it is not present." \
      " These tools take priority over the tools that would otherwise be found. This flag" \
      " may be provided multiple times to add multiple gems; if two gems define the same" \
      " tool, the gem appearing earlier on the command line takes priority.",
    "",
    "The value is the gem name, optionally followed by any number of version requirements," \
      " all separated by commas. Whitespace surrounding each element is ignored. The version" \
      " requirements use the same syntax as Rubygems and Bundler. For example:",
    ["    --gem=\"my-tools, ~> 1.5, >= 1.5.2\""]
end

flag :sources do
  flags "--path=PATH"
  handler { |val, prev| prev + [[:path, val]] }
  default []
  complete_values :file_system
  desc "Make the tools from the given path available"
  long_desc \
    "Adds the tools from the given file system path. The path must name either a directory" \
      " of tools, or a single Ruby file defining tools. For example:",
    ["    --path=/path/to/my-tools"]
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
# current CLI, but if any sources were requested, we need a new CLI because
# sources cannot be added to a CLI that has already started loading tools. The
# new CLI copies the current sources and adds the requested ones on top of
# them. The requested sources are added in reverse order so that the first flag
# on the command line ends up with the highest priority.
#
# All the requests are parsed and checked up front, in command line order,
# because adding a source can have side effects such as installing a gem or
# fetching a git repo. That way a malformed request is reported before any of
# those happen, and is reported against the first offending flag rather than
# the last.
def build_cli
  requests = sources.map { |kind, value| [kind, parse_source_request(kind, value)] }
  return cli if requests.empty?
  require "toys/utils/gems" if requests.any? { |kind, _spec| kind == :gem }
  cli.child(copy_sources: true) do |child_cli|
    requests.reverse_each do |kind, spec|
      add_source(child_cli, kind, spec)
    end
  end
end

# Parses and checks a single source request, without adding it to any CLI,
# returning the information needed later to add it.
def parse_source_request(kind, value)
  case kind
  when :gem
    parse_gem_request(value)
  when :path
    parse_path_request(value)
  end
end

# Adds a single parsed source request to the given CLI, at high priority so it
# takes precedence over the sources copied from the current CLI.
def add_source(child_cli, kind, spec)
  case kind
  when :gem
    add_gem(child_cli, *spec)
  when :path
    add_path(child_cli, spec)
  end
end

# Splits a --gem flag value into the gem name and its version requirements,
# and checks that both are valid. The requirements are validated by Rubygems
# itself, but are passed along as the original strings.
def parse_gem_request(gem_request)
  gem_name, *gem_version = gem_request.split(",", -1).map(&:strip)
  if gem_name.nil? || gem_name.empty? || gem_version.any?(&:empty?)
    logger.fatal("Invalid --gem value: #{gem_request.inspect}")
    exit(1)
  end
  begin
    ::Gem::Requirement.create(*gem_version)
  rescue ::Gem::Requirement::BadRequirementError => e
    logger.fatal("Invalid version requirement for gem #{gem_name.inspect}: #{e.message}")
    exit(1)
  end
  [gem_name, gem_version]
end

# Adds a single gem to the given CLI, reporting a failure to activate the gem
# or to find its tools as an error message rather than a stack trace.
def add_gem(child_cli, gem_name, gem_version)
  child_cli.add_source_gem(gem_name, gem_version: gem_version, high_priority: true)
rescue ::Toys::ToolDefinitionError => e
  logger.fatal("Cannot load tools from gem #{gem_name.inspect}: #{e.message}")
  exit(1)
end

# Checks a --path flag value, applying the same rule that adding the path will
# apply, so that a bad path is reported before any other source is resolved.
def parse_path_request(path_request)
  path = path_request.strip
  if path.empty?
    logger.fatal("Invalid --path value: #{path_request.inspect}")
    exit(1)
  end
  begin
    ::Toys::SourceInfo.check_path(path, false)
  rescue ::Toys::ToolDefinitionError => e
    logger.fatal("Cannot load tools from path #{path.inspect}: #{e.message}")
    exit(1)
  end
  path
end

# Adds a single path to the given CLI. Any failure here would already have been
# caught by parse_path_request, which performs the same check. The path is
# added without a context directory, like the gem and git sources, because it
# is injected from the command line rather than found in a project.
def add_path(child_cli, path)
  child_cli.add_source_path(path, high_priority: true, context_directory: nil)
end
