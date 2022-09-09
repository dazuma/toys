# frozen_string_literal: true

desc "Runs rubocop in both gems"

include :terminal
include :exec, exit_on_nonzero_status: true

def run
  ::Dir.chdir(context_directory)

  puts("**** Running rubocop on repo root...", :bold, :cyan)
  exec_separate_tool(["rubocop", "_root"])

  puts("**** Running rubocop on toys-core...", :bold, :cyan)
  exec_separate_tool(["rubocop"], chdir: "toys-core")

  puts("**** Running rubocop on toys...", :bold, :cyan)
  exec_separate_tool(["rubocop"], chdir: "toys")
end

expand :rubocop do |t|
  t.name = "_root"
  t.use_bundler
  t.options = ["--config=.rubocop-root.yml"]
end
