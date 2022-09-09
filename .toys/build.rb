# frozen_string_literal: true

desc "Checks build for both gems"

include :terminal
include :exec, exit_on_nonzero_status: true

def run
  ::Dir.chdir(context_directory)

  puts("**** Building toys-core...", :bold, :cyan)
  exec_separate_tool(["build"], chdir: "toys-core")

  puts("**** Building toys...", :bold, :cyan)
  exec_separate_tool(["build"], chdir: "toys")
end
