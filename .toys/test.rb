# frozen_string_literal: true

load "#{__dir__}/../common-tools/ci"

desc "Runs all tests"

flag :integration_tests, "--integration-tests", "--integration", desc: "Enable integration tests"
flag :fail_fast, "--[no-]fail-fast", desc: "Terminate CI as soon as a job fails"

include "toys-ci"

def run
  ::ENV["TOYS_TEST_INTEGRATION"] = "true" if integration_tests
  ci_init
  ci_job("Tests for toys-core", ["test"], chdir: "toys-core")
  ci_job("Tests for toys", ["test"], chdir: "toys")
  ci_job("Tests for builtin commands", ["test-builtins"], chdir: "toys")
  ci_job("Tests for common-tools",
         ["system", "test", "-d", ".", "--minitest-focus", "--minitest-rg"],
         chdir: "common-tools")
  ci_report_results
end
