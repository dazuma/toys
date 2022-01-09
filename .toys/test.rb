# frozen_string_literal: true

desc "Runs tests in both gems"

flag :integration_tests, "--integration-tests", "--integration", desc: "Enable integration tests"

include :terminal
include :exec, exit_on_nonzero_status: true

def handle_gem(gem_name)
  puts("**** Testing #{gem_name}...", :bold, :cyan)
  ::Dir.chdir(::File.join(context_directory, gem_name)) do
    exec_separate_tool("test")
  end
end

def run
  ::ENV["TOYS_TEST_INTEGRATION"] = "true" if integration_tests
  handle_gem("toys-core")
  handle_gem("toys")
end
