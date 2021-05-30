# frozen_string_literal: true

desc "Update Toys if a newer version is available"

long_desc "Checks rubygems for a newer version of Toys. If one is available, downloads" \
          " and installs it."

flag :yes, "-y", "--yes", desc: "Do not ask for interactive confirmation"

include :exec
include :terminal

def run
  require "rubygems"
  configure_exec(exit_on_nonzero_status: true)
  version_info = spinner(leading_text: "Checking rubygems for the latest release... ",
                         final_text: "Done.\n") do
    capture(["gem", "list", "-q", "-r", "-e", "toys"])
  end
  if version_info =~ /toys\s\((.+)\)/
    latest_version = ::Gem::Version.new(::Regexp.last_match(1))
    cur_version = ::Gem::Version.new(::Toys::VERSION)
    if latest_version > cur_version
      prompt = "Update Toys from #{cur_version} to #{latest_version}? "
      exit(1) unless yes || confirm(prompt, default: true)
      result = spinner(leading_text: "Installing Toys version #{latest_version}... ",
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
