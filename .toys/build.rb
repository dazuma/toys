# frozen_string_literal: true

load "#{__dir__}/../common-tools/ci"

desc "Checks build for both gems"

flag :fail_fast, "--[no-]fail-fast", desc: "Terminate CI as soon as a job fails"

include "toys-ci"

def run
  ci_init
  ci_job("Build toys-core", ["build"], chdir: "toys-core")
  ci_job("Build toys", ["build"], chdir: "toys")
  ci_report_results
end
