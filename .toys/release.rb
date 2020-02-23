# frozen_string_literal: true

desc "Releases both gems"

include :exec, exit_on_nonzero_status: true
include :terminal

def handle_gem(gem_name)
  puts("**** Releasing #{gem_name}...", :bold, :cyan)
  ::Dir.chdir(gem_name) do
    status = cli.child.add_config_path(".toys.rb").run("release", "-y")
    exit(status) unless status.zero?
  end
end

def run
  ::Dir.chdir(context_directory) do
    version = capture(["./toys-dev", "system", "version"]).strip
    exit(1) unless confirm("Release toys #{version}? ")
    handle_gem("toys-core")
    handle_gem("toys")
    puts("**** Tagging v#{version}...", :bold, :cyan)
    exec(["git", "tag", "v#{version}"])
    exec(["git", "push", "origin", "v#{version}"])
    puts("**** Release complete!", :bold, :green)
  end
end
