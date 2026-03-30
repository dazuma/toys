# frozen_string_literal: true

# Normally you would do the following to load the CI framework:
#     load_gem "toys-ci"
# In this repo we want to use the current HEAD instead, so we manually add
# the lib directory to the load path and load the tool directory directly.
toys_ci_path = ::File.join(::File.dirname(__dir__), "toys-ci")
lib_path = ::File.join(toys_ci_path, "lib")
$LOAD_PATH.unshift(lib_path) unless $LOAD_PATH.include?(lib_path)
load(::File.join(toys_ci_path, "toys"))

desc "Runs all tests"

flag :integration_tests, "--integration-tests", "--integration", desc: "Enable integration tests"

expand(Toys::CI::Template) do |ci|
  ci.only_flag = true
  ci.fail_fast_flag = true
  ci.base_ref_flag = true
  ci.use_github_base_ref_flag = true
  ci.before_run do
    ::ENV["TOYS_TEST_INTEGRATION"] = "true" if integration_tests
  end

  ci.tool_job("Tests for toys-core",
              ["test"], chdir: "toys-core",
              flag: :toys_core,
              trigger_paths: ["toys-core/"])
  ci.tool_job("Tests for toys",
              ["test"], chdir: "toys",
              flag: :toys,
              trigger_paths: ["toys-core/", "toys/"])
  ci.tool_job("Tests for builtin commands",
              ["test-builtins"], chdir: "toys",
              flag: :builtins,
              trigger_paths: ["toys-core/", "toys/"])
  ci.tool_job("Tests for toys-ci",
              ["test"], chdir: "toys-ci",
              flag: :toys_ci,
              trigger_paths: ["toys-core/", "toys-ci/"])
  ci.tool_job("Tests for toys-release",
              ["system", "test", "-d", "toys", "--minitest-focus", "--minitest-rg"], chdir: "toys-release",
              flag: :toys_release,
              trigger_paths: ["toys-core/", "toys-release/"])
  ci.tool_job("Tests for global stuff",
              ["test-root"],
              flag: :root,
              trigger_paths: ["toys/docs/", "toys-core/docs/", "toys-release/docs/", "README.md",
                              "toys/README.md", "toys-core/README.md", "toys-ci/README.md", "toys-release/README.md"])
end
