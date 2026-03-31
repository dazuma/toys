# frozen_string_literal: true

# Normally you would do the following to load the CI framework:
#     load_gem "toys-ci"
# In this repo we want to use the current HEAD instead, so we manually add
# the lib directory to the load path and load the tool directory directly.
toys_ci_path = ::File.join(::File.dirname(__dir__), "toys-ci")
lib_path = ::File.join(toys_ci_path, "lib")
$LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)
load(::File.join(toys_ci_path, "toys"))

desc "Runs rubocop for the entire repo"

expand(Toys::CI::Template) do |ci|
  ci.only_flag = true
  ci.fail_fast_flag = true
  ci.base_ref_flag = true
  ci.use_github_base_ref_flag = true

  ci.tool_job("Rubocop for the repo tools and common tools",
              ["rubocop-root"],
              flag: :root,
              trigger_paths: [".toys/", "common-tools/"])
  ci.tool_job("Rubocop for toys-core",
              ["rubocop"], chdir: "toys-core",
              flag: :toys_core,
              trigger_paths: ["toys-core/"])
  ci.tool_job("Rubocop for toys",
              ["rubocop"], chdir: "toys",
              flag: :toys,
              trigger_paths: ["toys/"])
  ci.tool_job("Rubocop for toys-ci",
              ["rubocop"], chdir: "toys-ci",
              flag: :toys_ci,
              trigger_paths: ["toys-ci/"])
  ci.tool_job("Rubocop for toys-release",
              ["rubocop"], chdir: "toys-release",
              flag: :toys_release,
              trigger_paths: ["toys-release/"])
end
