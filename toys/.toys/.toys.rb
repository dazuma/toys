# frozen_string_literal: true

# Run this against local Toys code instead of installed Toys gems.
# This is to support development of Toys itself. Most Toys files should not
# include this.
unless ::ENV["TOYS_DEV"]
  ::Kernel.exec(::File.join(::File.dirname(context_directory), "toys-dev"), *::ARGV)
end

expand :clean, paths: :gitignore

expand :minitest, libs: ["lib", "test"], bundler: true, mt_compat: true

tool "test" do
  flag :integration_tests, "--integration-tests", "--integration", desc: "Enable integration tests"

  alias_method :run_orig, :run

  def run
    ::ENV["TOYS_TEST_INTEGRATION"] = "true" if integration_tests
    run_orig
  end
end

tool "test-builtins" do
  include :exec, e: true
  include :bundler

  def run
    ::Dir.chdir(context_directory)
    exec_separate_tool(["system", "test", "-d", "builtins",
                        "--minitest-focus", "--minitest-rg", "--minitest-compat"])
  end
end

expand :rubocop, bundler: true

expand :yardoc do |t|
  t.generate_output_flag = true
  t.fail_on_warning = true
  t.fail_on_undocumented_objects = true
  t.bundler = true
end

tool "yardoc" do
  flag :optimize, "--[no-]optimize", default: true, desc: "Remove unused code (default is true)"

  alias_method :run_orig, :run

  def run
    cli.run("copy-core-docs", optimize ? "--optimize" : "--no-optimize")
    run_orig
  end
end

tool "yardoc-test" do
  include :exec, e: true
  include :terminal

  def run
    puts "Running yardoc on unoptimized input..."
    unoptimized_result = exec_tool(["yardoc", "--no-optimize"], out: [:tee, :inherit, :controller])
    puts "Running yardoc on optimized input..."
    optimized_result = exec_tool(["yardoc", "--optimize"], out: [:tee, :inherit, :controller])
    unless unoptimized_result.captured_out == optimized_result.captured_out
      puts "Output changed!", :red
      exit 1
    end
  end
end

expand :rdoc, output_dir: "doc", bundler: true

expand :gem_build

tool "build" do
  alias_method :run_orig, :run

  def run
    cli.run("copy-core-docs")
    run_orig
  end
end

expand :gem_build, name: "release", push_gem: true

tool "release" do
  alias_method :run_orig, :run

  def run
    cli.run("copy-core-docs")
    run_orig
  end
end

expand :gem_build, name: "install", install_gem: true

tool "install" do
  alias_method :run_orig, :run

  def run
    cli.run("copy-core-docs")
    run_orig
  end
end
