# frozen_string_literal: true

desc "Run all CI checks"

long_desc "The CI tool runs all CI checks for the toys gem, including unit" \
            " tests, rubocop, and documentation checks. It is useful for" \
            " running tests in normal development, as well as being the" \
            " entrypoint for CI systems. Any failure will result in a" \
            " nonzero result code."

flag :integration_tests, desc: "Enable integration tests"

include :exec, result_callback: :handle_result
include :terminal

def handle_result(result)
  if result.success?
    puts("** #{result.name} passed\n\n", :green, :bold)
  else
    puts("** CI terminated: #{result.name} failed!", :red, :bold)
    exit(1)
  end
end

def run
  env = {}
  env["TOYS_TEST_INTEGRATION"] = "true" if integration_tests
  exec_tool(["test"], name: "Tests", env: env)
  exec_tool(["system", "test", "-d", File.join(context_directory, "builtins"), "--minitest-rg"],
            name: "Builtins Tests", env: env)
  exec_tool(["rubocop"], name: "Style checker")
  exec_tool(["yardoc-test"], name: "Docs generation")
  exec_tool(["build"], name: "Gem build")
end
