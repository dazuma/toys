# frozen_string_literal: true

load "#{__dir__}/../common-tools/ci"

desc "Build and install the current gems"

flag :fail_fast, "--[no-]fail-fast", desc: "Terminate CI as soon as a job fails"

include "toys-ci"

def run
  ci_init
  ci_job("Install toys-core from local build", ["install", "-y"], chdir: "toys-core")
  ci_job("Install toys from local build", ["install", "-y"], chdir: "toys")
  ci_report_results
end
