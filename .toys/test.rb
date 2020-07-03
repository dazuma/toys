# frozen_string_literal: true

desc "Runs tests in both gems"

include :terminal
include :exec

def handle_gem(gem_name)
  $stderr.puts "to stderr"
  puts("**** Testing #{gem_name}...", :bold, :cyan)
  ::Dir.chdir(::File.join(context_directory, gem_name)) do
    result = exec_separate_tool("test")
    exit(result.exit_code) unless result.success?
  end
end

def run
  handle_gem("toys-core")
  handle_gem("toys")
end
