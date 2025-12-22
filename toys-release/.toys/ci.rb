# frozen_string_literal: true

load "#{__dir__}/../../common-tools/ci"

desc "Run all CI checks for the toys-release gem"

flag :integration_tests, "--integration-tests", "--integration", desc: "Enable integration tests"

expand("toys-ci") do |toys_ci|
  toys_ci.only_flag = true
  toys_ci.fail_fast_flag = true
  toys_ci.on_prerun do
    ::ENV["TOYS_TEST_INTEGRATION"] = "true" if integration_tests
  end
  toys_ci.job("Bundle", flag: :bundle,
              exec: ["bundle", "update", "--all"])
  toys_ci.job("Rubocop", flag: :rubocop,
              tool: ["rubocop"])
  toys_ci.job("Tests", flag: :test,
              tool: ["system", "test", "-d", "toys", "--minitest-focus", "--minitest-rg"])
  toys_ci.job("Yardoc generation", flag: :yard,
              tool: ["yardoc-test"])
  toys_ci.job("Gem build", flag: :build,
              tool: ["build"])
end
