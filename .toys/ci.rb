# frozen_string_literal: true

# Normally you would do the following to load the CI framework:
#     load_gem "toys-ci"
# In this repo we want to use the current HEAD instead, so we manually add
# the lib directory to the load path and load the tool directory directly.
toys_ci_path = ::File.join(::File.dirname(__dir__), "toys-ci")
lib_path = ::File.join(toys_ci_path, "lib")
$LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)
load(::File.join(toys_ci_path, "toys"))

desc "CI target that runs CI jobs in this repo"

flag :integration_tests, "--integration-tests", "--integration", desc: "Enable integration tests"
flag :update, "--update", "--bundle-update", desc: "Update the bundles"

def bundle_cmd_array
  update ? ["bundle", "update", "--all"] : ["bundle", "install"]
end

base_dir = "#{context_directory}/"
working_dir = ::Dir.getwd
local_dir = working_dir.sub(base_dir, "").split("/").first if working_dir.start_with?(base_dir)

expand(Toys::CI::Template) do |ci|
  ci.only_flag = true
  ci.fail_fast_flag = true
  ci.base_ref_flag = true
  ci.use_github_base_ref_flag = true
  ci.before_run do
    ::ENV["TOYS_TEST_INTEGRATION"] = "true" if integration_tests
  end

  ci.job("Bundle for the root directory", flag: :bundle_root) do
    exec(bundle_cmd_array, name: "Bundle for the root directory").success?
  end
  ci.job("Bundle for toys-core", flag: :bundle_toys_core) do
    exec(bundle_cmd_array, name: "Bundle for toys-core", chdir: "toys-core").success?
  end
  ci.job("Bundle for toys", flag: :bundle_toys) do
    exec(bundle_cmd_array, name: "Bundle for toys", chdir: "toys").success?
  end
  ci.job("Bundle for toys-ci", flag: :bundle_toys_ci) do
    exec(bundle_cmd_array, name: "Bundle for toys-ci", chdir: "toys-ci").success?
  end
  ci.job("Bundle for toys-release", flag: :bundle_toys_release) do
    exec(bundle_cmd_array, name: "Bundle for toys-release", chdir: "toys-release").success?
  end

  ci.tool_job("Rubocop for the repo tools and common tools",
              ["rubocop-root"],
              flag: :rubocop_root,
              trigger_paths: [".toys/", "common-tools/"])
  ci.tool_job("Rubocop for toys-core",
              ["rubocop"], chdir: "toys-core",
              flag: :rubocop_toys_core,
              trigger_paths: ["toys-core/"])
  ci.tool_job("Rubocop for toys",
              ["rubocop"], chdir: "toys",
              flag: :rubocop_toys,
              trigger_paths: ["toys/"])
  ci.tool_job("Rubocop for toys-ci",
              ["rubocop"], chdir: "toys-ci",
              flag: :rubocop_toys_ci,
              trigger_paths: ["toys-ci/"])
  ci.tool_job("Rubocop for toys-release",
              ["rubocop"], chdir: "toys-release",
              flag: :rubocop_toys_release,
              trigger_paths: ["toys-release/"])

  ci.tool_job("Tests for toys-core",
              ["test"], chdir: "toys-core",
              flag: :test_toys_core,
              trigger_paths: ["toys-core/"])
  ci.tool_job("Tests for toys",
              ["test"], chdir: "toys",
              flag: :test_toys,
              trigger_paths: ["toys-core/", "toys/"])
  ci.tool_job("Tests for builtin commands",
              ["test-builtins"], chdir: "toys",
              flag: :test_builtins,
              trigger_paths: ["toys-core/", "toys/"])
  ci.tool_job("Tests for toys-ci",
              ["test"], chdir: "toys-ci",
              flag: :test_toys_ci,
              trigger_paths: ["toys-core/", "toys-ci/"])
  ci.tool_job("Tests for toys-release",
              ["system", "test", "-d", "toys", "--minitest-focus", "--minitest-rg"], chdir: "toys-release",
              flag: :test_toys_release,
              trigger_paths: ["toys-core/", "toys-release/"])
  ci.tool_job("Tests for global stuff",
              ["test-root"],
              flag: :test_root,
              trigger_paths: ["toys/docs/", "toys-core/docs/", "toys-release/docs/", "README.md",
                              "toys/README.md", "toys-core/README.md", "toys-ci/README.md", "toys-release/README.md"])

  ci.tool_job("Yardoc generation for toys-core",
              ["yardoc-test"], chdir: "toys-core",
              flag: :yard_toys_core,
              trigger_paths: ["toys-core/"])
  ci.tool_job("Yardoc generation and output test for toys",
              ["yardoc-test"], chdir: "toys",
              flag: :yard_toys,
              trigger_paths: ["toys-core/", "toys/"])
  ci.tool_job("Yardoc generation for toys-ci",
              ["yardoc-test"], chdir: "toys-ci",
              flag: :yard_toys_ci,
              trigger_paths: ["toys-ci/"])
  ci.tool_job("Yardoc generation for toys-release",
              ["yardoc-test"], chdir: "toys-release",
              flag: :yard_toys_release,
              trigger_paths: ["toys-release/"])

  ci.tool_job("Build toys-core gem",
              ["build"], chdir: "toys-core",
              flag: :build_toys_core,
              trigger_paths: ["toys-core/"])
  ci.tool_job("Build toys gem",
              ["build"], chdir: "toys",
              flag: :build_toys,
              trigger_paths: ["toys-core/", "toys/"])
  ci.tool_job("Build toys-ci gem",
              ["build"], chdir: "toys-ci",
              flag: :build_toys_ci,
              trigger_paths: ["toys-ci/"])
  ci.tool_job("Build toys-release gem",
              ["build"], chdir: "toys-release",
              flag: :build_toys_release,
              trigger_paths: ["toys-release/"])

  ci.collection("Bundle jobs", :bundle_all,
                [:bundle_root, :bundle_toys_core, :bundle_toys, :bundle_toys_ci, :bundle_toys_release])
  ci.collection("Rubocop jobs", :rubocop_all,
                [:rubocop_toys_core, :rubocop_toys, :rubocop_toys_ci, :rubocop_toys_release, :rubocop_root])
  ci.collection("Test jobs", :test_all,
                [:test_toys_core, :test_toys, :test_builtins, :test_toys_ci, :test_toys_release, :test_root])
  ci.collection("Yardoc generation jobs", :yard_all,
                [:yard_toys_core, :yard_toys, :yard_toys_ci, :yard_toys_release])
  ci.collection("Gem build jobs", :build_all,
                [:build_toys_core, :build_toys, :build_toys_ci, :build_toys_release])

  ci.collection("Jobs for the repo root", :all_root,
                [:bundle_root, :rubocop_root, :test_root])
  ci.collection("Jobs for the toys-core gem", :all_toys_core,
                [:bundle_toys_core, :rubocop_toys_core, :test_toys_core, :yard_toys_core, :build_toys_core],
                override_flags: (local_dir == "toys-core" ? ["all-toys-core", "current"] : nil))
  ci.collection("Jobs for the toys gem", :all_toys,
                [:bundle_toys, :rubocop_toys, :test_toys, :test_builtins, :yard_toys, :build_toys],
                override_flags: (local_dir == "toys" ? ["all-toys", "current"] : nil))
  ci.collection("Jobs for the toys-ci gem", :all_toys_ci,
                [:bundle_toys_ci, :rubocop_toys_ci, :test_toys_ci, :yard_toys_ci, :build_toys_ci],
                override_flags: (local_dir == "toys-ci" ? ["all-toys-ci", "current"] : nil))
  ci.collection("Jobs for the toys-release gem", :all_toys_release,
                [:bundle_toys_release, :rubocop_toys_release, :test_toys_release, :yard_toys_release,
                 :build_toys_release],
                override_flags: (local_dir == "toys-release" ? ["all-toys-release", "current"] : nil))
end
