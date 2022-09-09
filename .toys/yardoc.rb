# frozen_string_literal: true

desc "Generates yardoc for both gems"

flag :test

include :terminal
include :exec, exit_on_nonzero_status: true

def run
  ::Dir.chdir(context_directory)
  tool = [test ? "yardoc-test" : "yardoc"]

  puts("**** Generating Yardoc for toys-core...", :bold, :cyan)
  exec_separate_tool(tool, chdir: "toys-core")

  puts("**** Generating Yardoc for toys...", :bold, :cyan)
  exec_separate_tool(tool, chdir: "toys")
end
