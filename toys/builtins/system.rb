# frozen_string_literal: true

# Copyright 2019 Daniel Azuma
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.

desc "A set of system commands for Toys"

long_desc "Contains tools that inspect, configure, and update Toys itself."

tool "version" do
  desc "Print the current Toys version"

  def run
    puts ::Toys::VERSION
  end
end

tool "update" do
  desc "Update Toys if a newer version is available"

  long_desc "Checks rubygems for a newer version of Toys. If one is available, downloads" \
            " and installs it."

  flag :yes, "-y", "--yes", desc: "Do not ask for interactive confirmation"

  include :exec
  include :terminal

  def run
    configure_exec(exit_on_nonzero_status: true)
    version_info = terminal.spinner(leading_text: "Checking rubygems for the latest release... ",
                                    final_text: "Done.\n") do
      capture(["gem", "query", "-q", "-r", "-e", "toys"])
    end
    if version_info =~ /toys\s\((.+)\)/
      latest_version = ::Gem::Version.new($1)
      cur_version = ::Gem::Version.new(::Toys::VERSION)
      if latest_version > cur_version
        prompt = "Update Toys from #{cur_version} to #{latest_version}? "
        exit(1) unless yes || confirm(prompt, default: true)
        result = terminal.spinner(leading_text: "Installing Toys version #{latest_version}... ",
                                  final_text: "Done.\n") do
          exec(["gem", "install", "toys", "--version", latest_version.to_s],
               out: :capture, err: :capture)
        end
        if result.error?
          puts(result.captured_out + result.captured_err)
          puts("Toys failed to install version #{latest_version}", :red, :bold)
          exit(1)
        end
        puts("Toys successfully installed version #{latest_version}", :green, :bold)
      elsif latest_version < cur_version
        puts("Toys is already at experimental version #{cur_version}, which is later than" \
             " the latest released version #{latest_version}",
             :yellow, :bold)
      else
        puts("Toys is already at the latest version: #{latest_version}", :green, :bold)
      end
    else
      puts("Could not get latest Toys version", :red, :bold)
      exit(1)
    end
  end
end

tool "bash-completion" do
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
    "It is also possible to install completions for different binary names if you have" \
      " aliases for Toys. See the help for the \"install\" and \"remove\" tools for details.",
    "",
    "The \"eval\" tool is the actual completion command invoked by bash via `complete -C`." \
      " You shouldn't need to invoke it directly. See the bash manual for details."

  tool "eval" do
    desc "Tab completion command (executed by bash)"

    disable_argument_parsing

    def run
      require "toys/utils/bash_completion"
      result = ::Toys::Utils::BashCompletion.new(cli).run
      if result.negative?
        logger.error("This tool must be invoked as a bash completion command.")
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
      "This will associate the toys tab completion logic with the `toys` binary by default." \
        " If you have other names or aliases for the toys binary, pass them as arguments. e.g.",
      ["  $(toys system bash-completion install my-toys-alias another-alias)"]

    remaining_args :binary_names,
                   desc: "Names of binaries for which to set up tab completion" \
                         " (default: #{::Toys::StandardCLI::BINARY_NAME})"

    def run
      require "shellwords"
      path = ::File.join(::File.dirname(__dir__), "share", "bash-completion.sh")
      binaries = binary_names.empty? ? [::Toys::StandardCLI::BINARY_NAME] : binary_names
      puts Shellwords.join(["source", path] + binaries)
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
      "If you have other names or aliases for the toys binary, pass them as arguments. e.g.",
      ["  $(toys system bash-completion remove my-toys-alias another-alias)"]

    remaining_args :binary_names,
                   desc: "Names of binaries for which to set up tab completion" \
                         " (default: #{::Toys::StandardCLI::BINARY_NAME})"

    def run
      require "shellwords"
      path = ::File.join(::File.dirname(__dir__), "share", "bash-completion-remove.sh")
      binaries = binary_names.empty? ? [::Toys::StandardCLI::BINARY_NAME] : binary_names
      puts Shellwords.join(["source", path] + binaries)
    end
  end
end
