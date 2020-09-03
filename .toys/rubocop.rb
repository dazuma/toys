# frozen_string_literal: true

desc "Runs rubocop in both gems"

include :terminal
include :exec, exit_on_nonzero_status: true

def handle_gem(gem_name)
  puts("**** Running rubocop on #{gem_name}...", :bold, :cyan)
  ::Dir.chdir(::File.join(context_directory, gem_name)) do
    exec_separate_tool("rubocop")
  end
end

def run
  ::Dir.chdir(context_directory)
  puts("**** Running rubocop on repo root...", :bold, :cyan)
  exec_separate_tool(["rubocop", "_root"])
  handle_gem("toys-core")
  handle_gem("toys")
end

expand :rubocop do |t|
  t.name = "_root"
  t.use_bundler
  t.options = ["--config=.root-rubocop.yml"]
end
