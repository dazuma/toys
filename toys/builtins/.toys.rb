# frozen_string_literal: true

# Copyright 2018 Daniel Azuma
#
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice,
#   this list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# * Neither the name of the copyright holder, nor the names of any other
#   contributors to this software, may be used to endorse or promote products
#   derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
;

tool "do" do
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
end

tool "system" do
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
    desc "Set up tab completion in the current bash shell"

    long_desc "Sets up tab completion in the current bash shell.",
              "",
              "To use, include the following line in a bash script or init file:",
              "$(toys system bash-completion [BINARY_NAME])"

    flag :install, "--install FILENAME",
         desc: "Instead of setting up tab completion, install the setup script into the given file."

    remaining_args :binary_names,
                   default: [::Toys::StandardCLI::BINARY_NAME],
                   desc: "Names of binaries for which to set up tab completion" \
                         " (default: #{::Toys::StandardCLI::BINARY_NAME})"

    include :terminal

    def run
      if self[:install]
        do_install(self[:install], binary_names)
      else
        puts "complete -C bash-completion-toys #{binary_names.join(' ')}"
      end
    end

    def do_install(file_path, binary_names)
      if ::File.file?(file_path)
        cur_contents = ::File.read(file_path)
        if cur_contents =~ /\n# Install bash tab completion for toys\n\$\(/
          puts("Bash tab completion for toys is already present in #{file_path}", :yellow, :bold)
          exit(1)
        end
      end
      ::File.open(file_path, "a") do |file|
        file.puts("\n# Install bash tab completion for toys")
        file.puts("$(toys system bash-completion #{binary_names.join(' ')})")
      end
      puts("Installed bash tab completion for toys into #{file_path}", :green, :bold)
    end
  end
end
