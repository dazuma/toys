# frozen_string_literal: true

desc "Runs tests in both gems"

include :terminal
include :exec

def handle_gem(gem_name)
  puts("**** Testing #{gem_name}...", :bold, :cyan)
  ::Dir.chdir(::File.join(context_directory, gem_name)) do
    $stderr.puts "executing"
    result = exec_separate_tool("test")
    $stderr.puts result.status.inspect
    $stderr.puts result.exception.inspect
    exit(result.exit_code) unless result.success?
  end
end

def run
  handle_gem("toys-core")
  handle_gem("toys")
end
