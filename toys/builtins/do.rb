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

flag :gems do
  flags "--gem=GEM"
  handler :push
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
#
# All the requests are parsed and checked up front, in command line order,
# because adding a gem can have side effects such as installing it. That way a
# malformed request is reported before any gem is activated, and is reported
# against the first offending flag rather than the last.
def build_cli
  require "toys/utils/gems"
  gem_requests = gems.map { |gem_request| parse_gem_request(gem_request) }
  return cli if gem_requests.empty?
  cli.child(copy_loader_sources: true) do |child_cli|
    gem_requests.reverse_each do |gem_name, gem_version|
      add_gem(child_cli, gem_name, gem_version)
    end
  end
end

# Splits a --gem flag value into the gem name and its version requirements,
# and checks that both are wellformed. The requirements are validated by
# Rubygems itself, but are passed along as the original strings.
def parse_gem_request(gem_request)
  gem_name, *gem_version = gem_request.split(",", -1).map(&:strip)
  if gem_name.nil? || gem_name.empty? || gem_version.any?(&:empty?)
    logger.fatal("Illformed gem specification: #{gem_request.inspect}")
    exit(1)
  end
  begin
    ::Gem::Requirement.create(*gem_version)
  rescue ::Gem::Requirement::BadRequirementError => e
    logger.fatal("Illformed version requirement for gem #{gem_name.inspect}: #{e.message}")
    exit(1)
  end
  [gem_name, gem_version]
end

# Adds a single gem to the given CLI, reporting a failure to activate the gem
# or to find its tools as an error message rather than a stack trace.
def add_gem(child_cli, gem_name, gem_version)
  child_cli.add_config_gem(gem_name, gem_version: gem_version, high_priority: true)
rescue ::Toys::ToolDefinitionError, ::Toys::Utils::Gems::ActivationFailedError => e
  logger.fatal("Cannot load tools from gem #{gem_name.inspect}: #{e.message}")
  exit(1)
end
