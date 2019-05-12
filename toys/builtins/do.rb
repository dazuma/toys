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
  ["    toys do rails build , deploy"],
  "",
  "However, if you want to pass flags to the tools to run, you need to preface the arguments" \
    " with \"--\" in order to prevent \"do\" from trying to use them as its own flags. That" \
    " might look something like this:",
  ["    toys do -- rails build --staging , deploy --migrate"],
  "",
  "You may change the delimiter using the --delim flag. For example:",
  ["    toys do --delim=/ -- rails build --staging / deploy --migrate"]

flag :delim, "-d", "--delim=VALUE",
     default: ",",
     desc: "Set the delimiter",
     long_desc: "Sets the delimiter that separates tool invocations. The default value is \",\"."

remaining_args :args, desc: "A series of tools to run, separated by the delimiter"

def run
  args
    .chunk { |arg| arg == delim ? :_separator : true }
    .each do |_, action|
      code = cli.run(action)
      exit(code) unless code.zero?
    end
end
