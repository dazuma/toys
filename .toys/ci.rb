# frozen_string_literal: true

load "#{__dir__}/../common-tools/ci"

desc "CI target that runs all CI jobs for the entire repo"

flag :integration_tests, "--integration-tests", "--integration", desc: "Enable integration tests"

expand("toys-ci") do |toys_ci|
  toys_ci.only_flag = true
  toys_ci.fail_fast_flag = true
  toys_ci.on_prerun do
    ::ENV["TOYS_TEST_INTEGRATION"] = "true" if integration_tests
  end
  toys_ci.job("Bundle for the root directory", flag: :bundle_root,
              exec: ["bundle", "update", "--all"])
  toys_ci.job("Bundle for toys-core", flag: :bundle_core,
              exec: ["bundle", "update", "--all"], chdir: "toys-core")
  toys_ci.job("Bundle for toys", flag: :bundle_toys,
              exec: ["bundle", "update", "--all"], chdir: "toys")
  toys_ci.job("Bundle for toys-release", flag: :bundle_release,
              exec: ["bundle", "update", "--all"], chdir: "toys-release")
  toys_ci.job("Rubocop for toys-core", flag: :rubocop_core,
              tool: ["rubocop"], chdir: "toys-core")
  toys_ci.job("Rubocop for toys", flag: :rubocop_toys,
              tool: ["rubocop"], chdir: "toys")
  toys_ci.job("Rubocop for toys-release", flag: :rubocop_release,
              tool: ["rubocop"], chdir: "toys-release")
  toys_ci.job("Rubocop for the repo tools and common tools", flag: :rubocop_root,
              tool: ["rubocop", "_root"])
  toys_ci.job("Tests for toys-core", flag: :test_core,
              tool: ["test"], chdir: "toys-core")
  toys_ci.job("Tests for toys", flag: :test_toys,
              tool: ["test"], chdir: "toys")
  toys_ci.job("Tests for builtin commands", flag: :test_builtins,
              tool: ["test-builtins"], chdir: "toys")
  toys_ci.job("Tests for toys-release", flag: :test_release,
              tool: ["system", "test", "-d", "toys", "--minitest-focus", "--minitest-rg"],
              chdir: "toys-release")
  toys_ci.job("Tests for common-tools", flag: :test_tools,
              tool: ["system", "test", "-d", ".", "--minitest-focus", "--minitest-rg"],
              chdir: "common-tools")
  toys_ci.job("Yardoc generation for toys-core", flag: :yard_core,
              tool: ["yardoc-test"], chdir: "toys-core")
  toys_ci.job("Yardoc generation and output test for toys", flag: :yard_toys,
              tool: ["yardoc-test"], chdir: "toys")
  toys_ci.job("Yardoc generation for toys-release", flag: :yard_release,
              tool: ["yardoc-test"], chdir: "toys-release")
  toys_ci.job("Build toys-core gem", flag: :build_core,
              tool: ["build"], chdir: "toys-core")
  toys_ci.job("Build toys gem", flag: :build_toys,
              tool: ["build"], chdir: "toys")
  toys_ci.job("Build toys-release gem", flag: :build_release,
              tool: ["build"], chdir: "toys-release")
  toys_ci.collection("Bundle jobs", :bundle_all,
                     job_flags: [:bundle_root, :bundle_core, :bundle_toys, :bundle_release])
  toys_ci.collection("Rubocop jobs", :rubocop_all,
                     job_flags: [:rubocop_core, :rubocop_toys, :rubocop_release, :rubocop_root])
  toys_ci.collection("Test jobs", :test_all,
                     job_flags: [:test_core, :test_toys, :test_builtins, :test_release, :test_tools])
  toys_ci.collection("Yardoc generation jobs", :yard_all,
                     job_flags: [:yard_core, :yard_toys, :yard_release])
  toys_ci.collection("Gem build jobs", :build_all,
                     job_flags: [:build_core, :build_toys, :build_release])
end

tool "init" do
  desc "Initialize the environment for CI systems"

  include :exec
  include :fileutils

  def run
    changed = false
    if exec(["git", "config", "--global", "--get", "user.email"], out: :null).error?
      puts "CI init: Initializing user.email"
      exec(["git", "config", "--global", "user.email", "hello@example.com"], e: true)
      changed = true
    end
    if exec(["git", "config", "--global", "--get", "user.name"], out: :null).error?
      puts "CI init: Initializing user.name"
      exec(["git", "config", "--global", "user.name", "Hello Ruby"], e: true)
      changed = true
    end
    gems_dir = File.join(Gem.dir, "gems")
    if (File.stat(gems_dir).mode & 0o1777) == 0o777
      puts "CI init: Setting sticky bit on gems directory"
      chmod("a+t", gems_dir)
      changed = true
    end
    puts "CI init: No changes needed" unless changed
  end
end
