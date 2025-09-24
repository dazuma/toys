# frozen_string_literal: true

load "#{__dir__}/../common-tools/ci"

desc "CI target that runs all CI jobs for the entire repo"

flag :integration_tests, "--integration-tests", "--integration", desc: "Enable integration tests"

expand("toys-ci") do |toys_ci|
  toys_ci.all_flag = :all
  toys_ci.fail_fast_flag = :fail_fast
  toys_ci.on_prerun do
    ::ENV["TOYS_TEST_INTEGRATION"] = "true" if integration_tests
  end
  toys_ci.job("Bundle for the root directory", enable_flag: :bundle_root,
              exec: ["bundle", "update"])
  toys_ci.job("Bundle for toys-core", enable_flag: :bundle_core,
              exec: ["bundle", "update"], chdir: "toys-core")
  toys_ci.job("Bundle for toys", enable_flag: :bundle_toys,
              exec: ["bundle", "update"], chdir: "toys")
  toys_ci.job("Rubocop for toys-core", enable_flag: :core_rubocop,
              tool: ["rubocop"], chdir: "toys-core")
  toys_ci.job("Rubocop for toys", enable_flag: :toys_rubocop,
              tool: ["rubocop"], chdir: "toys")
  toys_ci.job("Rubocop for the repo tools and common tools", enable_flag: :root_rubocop,
              tool: ["rubocop", "_root"])
  toys_ci.job("Tests for toys-core", enable_flag: :core_test,
              tool: ["test"], chdir: "toys-core")
  toys_ci.job("Tests for toys", enable_flag: :toys_test,
              tool: ["test"], chdir: "toys")
  toys_ci.job("Tests for builtin commands", enable_flag: :builtins_test,
              tool: ["test-builtins"], chdir: "toys")
  toys_ci.job("Tests for common-tools", enable_flag: :tools_test,
              tool: ["system", "test", "-d", ".", "--minitest-focus", "--minitest-rg"],
              chdir: "common-tools")
  toys_ci.job("Yardoc generation for toys-core", enable_flag: :core_yard,
              tool: ["yardoc-test"], chdir: "toys-core")
  toys_ci.job("Yardoc generation for toys", enable_flag: :toys_yard,
              tool: ["yardoc-test"], chdir: "toys")
  toys_ci.job("Build toys-core", enable_flag: :core_build,
              tool: ["build"], chdir: "toys-core")
  toys_ci.job("Build toys", enable_flag: :toys_build,
              tool: ["build"], chdir: "toys")
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
