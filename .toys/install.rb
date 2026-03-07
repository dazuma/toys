# frozen_string_literal: true

# Normally you would do the following to load the CI framework:
#     load_gem "toys-ci"
# In this repo we want to use the current HEAD instead, so we manually add
# the lib directory to the load path and load the tool directory directly.
toys_ci_path = ::File.join(::File.dirname(__dir__), "toys-ci")
lib_path = ::File.join(toys_ci_path, "lib")
$LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)
load(::File.join(toys_ci_path, "toys"))

desc "Build and install the current gems"

expand(Toys::CI::Template) do |ci|
  ci.only_flag = true
  ci.fail_fast_flag = true
  ci.base_ref_flag = true

  ci.tool_job("Install toys-core from local build",
              ["install", "-y"], chdir: "toys-core",
              flag: :toys_core,
              trigger_paths: ["toys-core/"])
  ci.tool_job("Install toys from local build",
              ["install", "-y"], chdir: "toys",
              flag: :toys,
              trigger_paths: ["toys/"])
  ci.tool_job("Install toys-ci from local build",
              ["install", "-y"], chdir: "toys-ci",
              flag: :toys_ci,
              trigger_paths: ["toys-ci/"])
  ci.tool_job("Install toys-release from local build",
              ["install", "-y"], chdir: "toys-release",
              flag: :toys_release,
              trigger_paths: ["toys-release/"])
end
