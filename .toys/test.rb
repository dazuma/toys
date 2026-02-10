# frozen_string_literal: true

load "#{__dir__}/../common-tools/ci"

desc "Runs all tests"

flag :integration_tests, "--integration-tests", "--integration", desc: "Enable integration tests"

expand("toys-ci") do |toys_ci|
  toys_ci.only_flag = true
  toys_ci.fail_fast_flag = true
  toys_ci.on_prerun do
    ::ENV["TOYS_TEST_INTEGRATION"] = "true" if integration_tests
  end
  toys_ci.job("Tests for toys-core", flag: :core,
              tool: ["test"], chdir: "toys-core")
  toys_ci.job("Tests for toys", flag: :toys,
              tool: ["test"], chdir: "toys")
  toys_ci.job("Tests for builtin commands", flag: :builtins,
              tool: ["test-builtins"], chdir: "toys")
  toys_ci.job("Tests for toys-release", flag: :release,
              tool: ["system", "test", "-d", "toys", "--minitest-focus", "--minitest-rg"],
              chdir: "toys-release")
  toys_ci.job("Tests for common-tools", flag: :tools,
              tool: ["system", "test", "-d", ".", "--minitest-focus", "--minitest-rg"],
              chdir: "common-tools")
end
