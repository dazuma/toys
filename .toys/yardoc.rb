# frozen_string_literal: true

desc "Generates yardoc for both gems"

flag :full

include :terminal
include :exec, exit_on_nonzero_status: true

def handle_gem(gem_name)
  puts("**** Generating Yardoc for #{gem_name}...", :bold, :cyan)
  ::Dir.chdir(::File.join(context_directory, gem_name)) do
    exec_separate_tool(full ? "yardoc-full" : "yardoc")
  end
end

def run
  handle_gem("toys-core")
  handle_gem("toys")
end
