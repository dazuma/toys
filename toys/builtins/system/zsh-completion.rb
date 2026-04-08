# frozen_string_literal: true

desc "Zsh tab completion for Toys"

long_desc \
  "Tools that manage tab completion for Toys in the zsh shell.",
  "",
  "To install tab completion for Toys, execute the following line in a zsh shell, or" \
    " include it in an init file such as your .zshrc (after the line that calls compinit):",
  ["  $(toys system zsh-completion install)"],
  "",
  "To remove tab completion, execute:",
  ["  $(toys system zsh-completion remove)"],
  "",
  "It is also possible to install completions for different executable names if you have" \
    " aliases for Toys. See the help for the \"install\" and \"remove\" tools for details.",
  "",
  "The \"eval\" tool is the actual completion command invoked by zsh when it needs to" \
    " complete a toys command line. You shouldn't need to invoke it directly."

tool "eval" do
  desc "Tab completion command (executed by zsh)"

  long_desc \
    "Completion command invoked by zsh to complete a toys command line. Generally you do not" \
      " need to invoke this directly. It reads the command line context from the COMP_LINE" \
      " and COMP_POINT environment variables, and outputs completion candidates to stdout in" \
      " two sections separated by a blank line: final completions first, then partial" \
      " completions (such as directory paths)."

  disable_argument_parsing

  def run
    require "toys/utils/completion_engine"
    result = ::Toys::Utils::CompletionEngine::Zsh.new(cli).run
    if result > 1
      logger.fatal("This tool must be invoked as a zsh completion command.")
    end
    exit(result)
  end
end

tool "install" do
  desc "Install zsh tab completion"

  long_desc \
    "Outputs a command to set up Toys tab completion in the current zsh shell.",
    "",
    "To use, execute the following line in a zsh shell, or include it in an init file" \
      " such as your .zshrc (after the line that calls compinit):",
    ["  $(toys system zsh-completion install)"],
    "",
    "This will associate the toys tab completion logic with the `toys` executable by default." \
      " If you have aliases for the toys executable, pass them as arguments. e.g.",
    ["  $(toys system zsh-completion install my-toys-alias another-alias)"]

  remaining_args :executable_names,
                 desc: "Names of executables for which to set up tab completion" \
                       " (default: #{::Toys::StandardCLI::EXECUTABLE_NAME})"

  def run
    require "shellwords"
    path = ::File.join(::File.dirname(::File.dirname(__dir__)), "share", "zsh-completion.sh")
    exes = executable_names.empty? ? [::Toys::StandardCLI::EXECUTABLE_NAME] : executable_names
    puts ::Shellwords.join(["source", path] + exes)
  end
end

tool "remove" do
  desc "Remove zsh tab completion"

  long_desc \
    "Outputs a command to remove Toys tab completion from the current zsh shell.",
    "",
    "To use, execute the following line in a zsh shell:",
    ["  $(toys system zsh-completion remove)"],
    "",
    "If you have other names or aliases for the toys executable, pass them as arguments. e.g.",
    ["  $(toys system zsh-completion remove my-toys-alias another-alias)"]

  remaining_args :executable_names,
                 desc: "Names of executables for which to remove tab completion" \
                       " (default: #{::Toys::StandardCLI::EXECUTABLE_NAME})"

  def run
    require "shellwords"
    path = ::File.join(::File.dirname(::File.dirname(__dir__)), "share", "zsh-completion-remove.sh")
    exes = executable_names.empty? ? [::Toys::StandardCLI::EXECUTABLE_NAME] : executable_names
    puts ::Shellwords.join(["source", path] + exes)
  end
end
