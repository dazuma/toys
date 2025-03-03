# frozen_string_literal: true

load "#{__dir__}/../../common-tools/ci"

desc "Run all CI checks for the toys-core gem"

flag :integration_tests, desc: "Enable integration tests"
flag :fail_fast, "--[no-]fail-fast", desc: "Terminate CI as soon as a job fails"

include "toys-ci"

def run
  ENV["TOYS_TEST_INTEGRATION"] = "true" if integration_tests
  ci_init
  ci_job("Rubocop", ["rubocop"])
  ci_job("Tests", ["test"])
  ci_job("Docs generation", ["yardoc-test"])
  ci_job("Gem build", ["build"])
  ci_report_results
end
