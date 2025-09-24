# frozen_string_literal: true

load "#{__dir__}/../common-tools/ci"

desc "Runs all tests"

flag :integration_tests, "--integration-tests", "--integration", desc: "Enable integration tests"

expand("toys-ci") do |toys_ci|
  toys_ci.all_flag = :all
  toys_ci.fail_fast_flag = :fail_fast
  toys_ci.on_prerun do
    ::ENV["TOYS_TEST_INTEGRATION"] = "true" if integration_tests
  end
  toys_ci.job("Tests for toys-core", enable_flag: :core,
              tool: ["test"], chdir: "toys-core")
  toys_ci.job("Tests for toys", enable_flag: :toys,
              tool: ["test"], chdir: "toys")
  toys_ci.job("Tests for builtin commands", enable_flag: :builtins,
              tool: ["test-builtins"], chdir: "toys")
  toys_ci.job("Tests for common-tools", enable_flag: :tools,
              tool: ["system", "test", "-d", ".", "--minitest-focus", "--minitest-rg"],
              chdir: "common-tools")
end
