# frozen_string_literal: true

load "#{__dir__}/../common-tools/ci"

desc "Generates yardoc for both gems and tests output for the toys gem"

flag :fail_fast, "--[no-]fail-fast", desc: "Terminate CI as soon as a job fails"

include "toys-ci"

def run
  ci_init
  ci_job("Yardoc generation for toys-core", ["yardoc-test"], chdir: "toys-core")
  ci_job("Yardoc generation for toys", ["yardoc-test"], chdir: "toys")
  ci_report_results
end
