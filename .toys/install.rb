# frozen_string_literal: true

desc "Build and install the current gems"

include :terminal
include :exec, exit_on_nonzero_status: true

def handle_gem(gem_name)
  puts("**** Installing #{gem_name} from local build...", :bold, :cyan)
  ::Dir.chdir(::File.join(context_directory, gem_name)) do
    exec_separate_tool(["install", "-y"])
  end
end

def run
  handle_gem("toys-core")
  handle_gem("toys")
end
