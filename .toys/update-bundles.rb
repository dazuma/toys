# frozen_string_literal: true

load "#{__dir__}/../common-tools/ci"

desc "Update bundles in both gems"

expand("toys-ci") do |toys_ci|
  toys_ci.all_flag = :all
  toys_ci.fail_fast_flag = :fail_fast
  toys_ci.job("Bundle for the root directory", enable_flag: :root,
              exec: ["bundle", "update"])
  toys_ci.job("Bundle for toys-core", enable_flag: :core,
              exec: ["bundle", "update"], chdir: "toys-core")
  toys_ci.job("Bundle for toys", enable_flag: :toys,
              exec: ["bundle", "update"], chdir: "toys")
end
