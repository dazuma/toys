# frozen_string_literal: true

desc "Runs tests in both gems"

flag :integration_tests, "--integration-tests", "--integration", desc: "Enable integration tests"

include :terminal
include :exec, exit_on_nonzero_status: true

def run
  ::ENV["TOYS_TEST_INTEGRATION"] = "true" if integration_tests
  ::Dir.chdir(context_directory)

  puts("**** Testing toys-core...", :bold, :cyan)
  exec_separate_tool(["test"], chdir: "toys-core")

  puts("**** Testing toys...", :bold, :cyan)
  exec_separate_tool(["test"], chdir: "toys")

  puts("**** Testing builtins...", :bold, :cyan)
  exec_separate_tool(["test-builtins"], chdir: "toys")
end
