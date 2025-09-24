# frozen_string_literal: true

load "#{__dir__}/../common-tools/ci"

desc "Build and install the current gems"

expand("toys-ci") do |toys_ci|
  toys_ci.all_flag = :all
  toys_ci.fail_fast_flag = :fail_fast
  toys_ci.job("Install toys-core from local build", enable_flag: :core,
              tool: ["install", "-y"], chdir: "toys-core")
  toys_ci.job("Install toys from local build", enable_flag: :toys,
              tool: ["install", "-y"], chdir: "toys")
end
