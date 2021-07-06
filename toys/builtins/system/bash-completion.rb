# frozen_string_literal: true

desc "Bash tab completion for Toys"

long_desc \
  "Tools that manage tab completion for Toys in the bash shell.",
  "",
  "To install tab completion for Toys, execute the following line in a bash shell, or" \
    " include it in an init file such as your .bashrc:",
  ["  $(toys system bash-completion install)"],
  "",
  "To remove tab completion, execute:",
  ["  $(toys system bash-completion remove)"],
  "",
  "It is also possible to install completions for different executable names if you have" \
    " aliases for Toys. See the help for the \"install\" and \"remove\" tools for details.",
  "",
  "The \"eval\" tool is the actual completion command invoked by bash when it needs to" \
    " complete a toys command line. You shouldn't need to invoke it directly."

tool "eval" do
  desc "Tab completion command (executed by bash)"

  long_desc \
    "Completion command invoked by bash to compete a toys command line. Generally you do not" \
      " need to invoke this directly. It reads the command line context from the COMP_LINE" \
      " and COMP_POINT environment variables, and outputs completion candidates to stdout."

  disable_argument_parsing

  def run
    require "toys/utils/completion_engine"
    result = ::Toys::Utils::CompletionEngine::Bash.new(cli).run
    if result > 1
      logger.fatal("This tool must be invoked as a bash completion command.")
    end
    exit(result)
  end
end

tool "install" do
  desc "Install bash tab completion"

  long_desc \
    "Outputs a command to set up Toys tab completion in the current bash shell.",
    "",
    "To use, execute the following line in a bash shell, or include it in an init file" \
      " such as your .bashrc:",
    ["  $(toys system bash-completion install)"],
    "",
    "This will associate the toys tab completion logic with the `toys` executable by default." \
      " If you have aliases for the toys executable, pass them as arguments. e.g.",
    ["  $(toys system bash-completion install my-toys-alias another-alias)"]

  remaining_args :executable_names,
                 desc: "Names of executables for which to set up tab completion" \
                       " (default: #{::Toys::StandardCLI::EXECUTABLE_NAME})"

  def run
    require "shellwords"
    path = ::File.join(::File.dirname(__dir__), "share", "bash-completion.sh")
    exes = executable_names.empty? ? [::Toys::StandardCLI::EXECUTABLE_NAME] : executable_names
    puts Shellwords.join(["source", path] + exes)
  end
end

tool "remove" do
  desc "Remove bash tab completion"

  long_desc \
    "Outputs a command to remove Toys tab completion from the current bash shell.",
    "",
    "To use, execute the following line in a bash shell:",
    ["  $(toys system bash-completion remove)"],
    "",
    "If you have other names or aliases for the toys executable, pass them as arguments. e.g.",
    ["  $(toys system bash-completion remove my-toys-alias another-alias)"]

  remaining_args :executable_names,
                 desc: "Names of executables for which to set up tab completion" \
                       " (default: #{::Toys::StandardCLI::EXECUTABLE_NAME})"

  def run
    require "shellwords"
    path = ::File.join(::File.dirname(__dir__), "share", "bash-completion-remove.sh")
    exes = executable_names.empty? ? [::Toys::StandardCLI::EXECUTABLE_NAME] : executable_names
    puts Shellwords.join(["source", path] + exes)
  end
end
