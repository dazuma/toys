# frozen_string_literal: true

load "#{__dir__}/../common-tools/ci"

desc "CI target that runs all CI jobs for the entire repo"

flag :integration_tests, "--integration-tests", "--integration", desc: "Enable integration tests"
flag :fail_fast, "--[no-]fail-fast", desc: "Terminate CI as soon as a job fails"

include "toys-ci"

def run
  ::ENV["TOYS_TEST_INTEGRATION"] = "true" if integration_tests
  ci_init
  ci_job("Rubocop for toys-core", ["rubocop"], chdir: "toys-core")
  ci_job("Rubocop for toys", ["rubocop"], chdir: "toys")
  ci_job("Rubocop for the repo tools and common tools", ["rubocop", "_root"])
  ci_job("Tests for toys-core", ["test"], chdir: "toys-core")
  ci_job("Tests for toys", ["test"], chdir: "toys")
  ci_job("Tests for builtin commands", ["test-builtins"], chdir: "toys")
  ci_job("Tests for common-tools", ["system", "test", "-d", "."], chdir: "common-tools")
  ci_job("Yardoc generation for toys-core", ["yardoc-test"], chdir: "toys-core")
  ci_job("Yardoc generation for toys", ["yardoc-test"], chdir: "toys")
  ci_job("Build toys-core", ["build"], chdir: "toys-core")
  ci_job("Build toys", ["build"], chdir: "toys")
  ci_report_results
end

tool "init" do
  desc "Initialize the environment for CI systems"

  include :exec
  include :terminal

  def run
    changed = false
    if exec(["git", "config", "--global", "--get", "user.email"], out: :null).error?
      exec(["git", "config", "--global", "user.email", "hello@example.com"], e: true)
      changed = true
    end
    if exec(["git", "config", "--global", "--get", "user.name"], out: :null).error?
      exec(["git", "config", "--global", "user.name", "Hello Ruby"], e: true)
      changed = true
    end
    if changed
      puts("**** Environment is now set up for CI", :bold, :green)
    else
      puts("**** Environment was already set up for CI", :bold, :yellow)
    end
  end
end
