# frozen_string_literal: true

load "#{__dir__}/../common-tools/ci"

desc "Runs rubocop for the entire repo"

flag :fail_fast, "--[no-]fail-fast", desc: "Terminate CI as soon as a job fails"

include "toys-ci"

def run
  ci_init
  ci_job("Rubocop for toys-core", ["rubocop"], chdir: "toys-core")
  ci_job("Rubocop for toys", ["rubocop"], chdir: "toys")
  ci_job("Rubocop for the repo tools and common tools", ["rubocop", "_root"])
  ci_report_results
end

expand :rubocop do |t|
  t.name = "_root"
  t.use_bundler
  t.options = ["--config=.rubocop-root.yml"]
end
