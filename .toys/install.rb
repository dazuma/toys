# frozen_string_literal: true

desc "Build and install the current gems"

include :terminal
include :exec, exit_on_nonzero_status: true

def run
  ::Dir.chdir(context_directory)

  puts("**** Installing toys-core from local build...", :bold, :cyan)
  exec_separate_tool(["install", "-y"], chdir: "toys-core")

  puts("**** Installing toys from local build...", :bold, :cyan)
  exec_separate_tool(["install", "-y"], chdir: "toys")
end
