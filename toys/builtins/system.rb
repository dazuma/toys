# frozen_string_literal: true

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
