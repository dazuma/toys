# frozen_string_literal: true

desc "Generates yardoc for both gems"

include :terminal
include :exec

def handle_gem(gem_name)
  puts("**** Generating Yardoc for #{gem_name}...", :bold, :cyan)
  ::Dir.chdir(::File.join(context_directory, gem_name)) do
    result = exec_separate_tool("yardoc")
    exit(result.exit_code) unless result.success?
  end
end

def run
  handle_gem("toys-core")
  handle_gem("toys")
end
