# frozen_string_literal: true

load "#{__dir__}/../common-tools/ci"

desc "Checks build for both gems"

expand("toys-ci") do |toys_ci|
  toys_ci.only_flag = true
  toys_ci.fail_fast_flag = true
  toys_ci.job("Build toys-core", flag: :core,
              tool: ["build"], chdir: "toys-core")
  toys_ci.job("Build toys", flag: :toys,
              tool: ["build"], chdir: "toys")
end
