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
  "You may also load tools from additional sources, by passing the --gem, --git, and --path" \
    " flags. Any number of these flags can be added; each adds a source of tools, with earlier" \
    " flags taking priority over later. For example:",
  ["    toys do --gem=my-tools --git=https://github.com/dazuma/example deploy --migrate"]

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
    "Adds the tools from the given gem. If the specified gem is not currently installed," \
      " follows the policy set by the --on-missing-gem flag, which is normally to prompt" \
      " whether to install.",
    "",
    "The value is the gem name, optionally followed by any number of version requirements," \
      " all separated by commas. Whitespace surrounding each element is ignored. The version" \
      " requirements use the same syntax as Rubygems and Bundler. For example:",
    ["    --gem=\"my-tools, ~> 1.5, >= 1.5.2\""]
end

flag :sources do
  flags "--git=SPEC"
  handler { |val, prev| prev + [[:git, val]] }
  default []
  desc "Make the tools from the given git repository available"
  long_desc \
    "Adds the tools from the given git repository, fetching the repository into a local cache" \
      " if it is not already there.",
    "",
    "The value is the git remote (i.e. the repository URL or path), optionally followed by any" \
      " number of \"key=value\" elements, all separated by commas. There is no way to escape" \
      " a comma appearing within the value. Whitespace surrounding each element, and surrounding" \
      " each equals sign, is ignored. For example:",
    ["    --git=\"https://github.com/dazuma/example, path=toys, commit=main\""],
    "",
    "The recognized keys are:",
    "* \"path\" : The file or directory within the repository to load. By default, the entire" \
      " repository is loaded.",
    "* \"commit\" : The SHA, tag, or branch to load. By default, the repository head is used.",
    "* \"update\" : Whether to refresh a previously cached repository. Pass \"true\" or" \
      " \"false\", or a number of seconds, to refresh only if the cache is at least that old." \
      " The default is \"false\"."
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

flag :on_missing_gem do
  flags "--on-missing-gem=WHAT"
  accept [:confirm, :install, :error]
  complete_values ["confirm", "install", "error"]
  desc "Specify what to do if a gem is not installed"
  long_desc \
    "Specifies what to do if a gem referenced by the --gem flag is not installed." \
      " Possible values are:",
    "* \"confirm\" : Prompt for what to do.",
    "* \"install\" : Do not prompt, but just install the needed gem.",
    "* \"error\" : Display an error and abort.",
    "",
    "Defaults to the existing CLI configuration, normally \"confirm\". Note this does not affect" \
      " any other gem references such as via the \"gem\" or \"load_gem\" directives."
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
# current CLI, but if any sources were requested, we need a new CLI with those
# sources added. Any new sources are added in reverse order so that the first
# flag on the command line ends up with the highest priority.
#
# All the flag values are parsed up front, in command line order, so that a
# malformed value is reported before any source is added, and is reported
# against the first offending flag rather than the last. All added sources are
# then proactively resolved and failures reported.
def build_cli
  specs = sources.map { |kind, value| parse_source_request(kind, value) }
  return cli if specs.empty?
  tool_cli = cli.child(copy_sources: true)
  specs.reverse_each { |spec| tool_cli.add_source(spec, high_priority: true) }
  begin
    tool_cli.loader.resolve_sources
  rescue ::Toys::ToolSourceError => e
    logger.error("Unable to resolve the given tool sources: #{e.message}")
    exit(1)
  end
  tool_cli
end

# Parses and checks a single source request, returning the source spec to add
# to the CLI later.
def parse_source_request(kind, value)
  case kind
  when :gem
    parse_gem_request(value)
  when :git
    parse_git_request(value)
  when :path
    parse_path_request(value)
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
  ::Toys::SourceSpec.gem(gem_name, version: gem_version, on_missing: on_missing_gem)
end

# Splits a --git flag value into the git remote and the options that follow it,
# and checks that all of them are valid. Unrecognized and duplicate keys are
# errors rather than being ignored or resolved as last-wins, because a mistyped
# key would otherwise silently load something other than what was asked for.
def parse_git_request(git_request)
  git_remote, *elements = git_request.split(",", -1).map(&:strip)
  git_error(git_request, "the git remote is required") if git_remote.nil? || git_remote.empty?
  opts = { path: nil, commit: nil, update: false }
  seen_keys = []
  elements.each do |element|
    key, value = parse_git_element(git_request, element, seen_keys)
    case key
    when "path"
      opts[:path] = value
    when "commit"
      opts[:commit] = value
    when "update"
      opts[:update] = parse_git_update(git_request, value)
    else
      git_error(git_request, "unrecognized key #{key.inspect}")
    end
  end
  ::Toys::SourceSpec.git(git_remote, **opts)
end

# Splits one element following the git remote into its key and value, and
# checks that it is well-formed and does not repeat an earlier key.
def parse_git_element(git_request, element, seen_keys)
  key, value = element.split("=", 2).map(&:strip)
  if value.nil? || key.empty?
    git_error(git_request, "expected \"key=value\" but got #{element.inspect}")
  end
  git_error(git_request, "empty value for key #{key.inspect}") if value.empty?
  git_error(git_request, "duplicate key #{key.inspect}") if seen_keys.include?(key)
  seen_keys << key
  [key, value]
end

# Interprets the value of the "update" key in a --git flag value, which is
# either a boolean or a number of seconds.
def parse_git_update(git_request, value)
  case value
  when "true"
    true
  when "false"
    false
  when /\A\d+\z/
    value.to_i
  else
    git_error(git_request, "invalid update value #{value.inspect}")
  end
end

# Reports a malformed --git flag value, naming the part of the value that was
# not understood.
def git_error(git_request, message)
  logger.fatal("Invalid --git value: #{git_request.inspect}: #{message}")
  exit(1)
end

# Checks that a --path flag value is present. Whether the path actually names
# tools is left to the loader to determine, so that this tool does not have to
# duplicate that rule. The spec carries no context directory, like the gem and
# git sources, because it is injected from the command line rather than found
# in a project.
def parse_path_request(path_request)
  path = path_request.strip
  if path.empty?
    logger.fatal("Invalid --path value: #{path_request.inspect}")
    exit(1)
  end
  ::Toys::SourceSpec.path(path)
end
