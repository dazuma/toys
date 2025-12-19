# frozen_string_literal: true

load "#{__dir__}/../common-tools/ci"

desc "Update bundles in both gems"

expand("toys-ci") do |toys_ci|
  toys_ci.only_flag = true
  toys_ci.fail_fast_flag = true
  toys_ci.job("Bundle for the root directory", flag: :root,
              exec: ["bundle", "update", "--all"])
  toys_ci.job("Bundle for toys-core", flag: :core,
              exec: ["bundle", "update", "--all"], chdir: "toys-core")
  toys_ci.job("Bundle for toys", flag: :toys,
              exec: ["bundle", "update", "--all"], chdir: "toys")
end
