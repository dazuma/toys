# frozen_string_literal: true

load "#{__dir__}/../common-tools/ci"

desc "Build and install the current gems"

expand("toys-ci") do |toys_ci|
  toys_ci.only_flag = true
  toys_ci.fail_fast_flag = true
  toys_ci.job("Install toys-core from local build", flag: :core,
              tool: ["install", "-y"], chdir: "toys-core")
  toys_ci.job("Install toys from local build", flag: :toys,
              tool: ["install", "-y"], chdir: "toys")
  toys_ci.job("Install toys-release from local build", flag: :release,
              tool: ["install", "-y"], chdir: "toys-release")
end
