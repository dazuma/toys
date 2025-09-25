# frozen_string_literal: true

load "#{__dir__}/../common-tools/ci"

desc "Generates yardoc for both gems and tests output for the toys gem"

expand("toys-ci") do |toys_ci|
  toys_ci.only_flag = true
  toys_ci.fail_fast_flag = true
  toys_ci.job("Yardoc generation for toys-core", flag: :core,
              tool: ["yardoc-test"], chdir: "toys-core")
  toys_ci.job("Yardoc generation for toys", flag: :toys,
              tool: ["yardoc-test"], chdir: "toys")
end
