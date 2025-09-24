# frozen_string_literal: true

load "#{__dir__}/../common-tools/ci"

desc "Generates yardoc for both gems"

expand("toys-ci") do |toys_ci|
  toys_ci.all_flag = :all
  toys_ci.fail_fast_flag = :fail_fast
  toys_ci.job("Yardoc generation for toys-core", enable_flag: :core,
              tool: ["yardoc"], chdir: "toys-core")
  toys_ci.job("Yardoc generation for toys", enable_flag: :toys,
              tool: ["yardoc"], chdir: "toys")
end
