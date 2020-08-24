# frozen_string_literal: true

desc "Runs tests in both gems"

include :terminal
include :exec, exit_on_nonzero_status: true

def handle_gem(gem_name)
  puts("**** Testing #{gem_name}...", :bold, :cyan)
  ::Dir.chdir(::File.join(context_directory, gem_name)) do
    exec_separate_tool("test")
  end
end

def run
  handle_gem("toys-core")
  handle_gem("toys")
end
