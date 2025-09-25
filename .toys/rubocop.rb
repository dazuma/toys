# frozen_string_literal: true

load "#{__dir__}/../common-tools/ci"

desc "Runs rubocop for the entire repo"

expand("toys-ci") do |toys_ci|
  toys_ci.only_flag = true
  toys_ci.fail_fast_flag = true
  toys_ci.job("Rubocop for toys-core", flag: :core,
              tool: ["rubocop"], chdir: "toys-core")
  toys_ci.job("Rubocop for toys", flag: :toys,
              tool: ["rubocop"], chdir: "toys")
  toys_ci.job("Rubocop for the repo tools and common tools", flag: :root,
              tool: ["rubocop", "_root"])
end

expand :rubocop do |t|
  t.name = "_root"
  t.use_bundler
  t.options = ["--config=.rubocop-root.yml"]
end
