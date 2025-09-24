# frozen_string_literal: true

load "#{__dir__}/../common-tools/ci"

desc "Checks build for both gems"

expand("toys-ci") do |toys_ci|
  toys_ci.all_flag = :all
  toys_ci.fail_fast_flag = :fail_fast
  toys_ci.job("Build toys-core", enable_flag: :core,
              tool: ["build"], chdir: "toys-core")
  toys_ci.job("Build toys", enable_flag: :toys,
              tool: ["build"], chdir: "toys")
end
