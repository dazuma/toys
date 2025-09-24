# frozen_string_literal: true

load "#{__dir__}/../../common-tools/ci"

desc "Run all CI checks for the toys-core gem"

flag :integration_tests, "--integration-tests", "--integration", desc: "Enable integration tests"

expand("toys-ci") do |toys_ci|
  toys_ci.all_flag = :all
  toys_ci.fail_fast_flag = :fail_fast
  toys_ci.on_prerun do
    ::ENV["TOYS_TEST_INTEGRATION"] = "true" if integration_tests
  end
  toys_ci.job("Bundle", enable_flag: :bundle,
              exec: ["bundle", "update"])
  toys_ci.job("Rubocop", enable_flag: :rubocop,
              tool: ["rubocop"],)
  toys_ci.job("Tests", enable_flag: :test,
              tool: ["test"])
  toys_ci.job("Yardoc generation", enable_flag: :yard,
              tool: ["yardoc-test"])
  toys_ci.job("Gem build", enable_flag: :build,
              tool: ["build"])
end
