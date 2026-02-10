# frozen_string_literal: true

load "#{__dir__}/../common-tools/ci"

desc "Checks build for both gems"

expand("toys-ci") do |toys_ci|
  toys_ci.only_flag = true
  toys_ci.fail_fast_flag = true
  toys_ci.job("Build toys-core gem", flag: :core,
              tool: ["build"], chdir: "toys-core")
  toys_ci.job("Build toys gem", flag: :toys,
              tool: ["build"], chdir: "toys")
  toys_ci.job("Build toys-release gem", flag: :release,
              tool: ["build"], chdir: "toys-release")
end
