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
      " two sections separated by a \"--\" line: final completions first, then partial" \
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
