# frozen_string_literal: true

# Run this against local Toys code instead of installed Toys gems.
# This is to support development of Toys itself. Most Toys files should not
# include this.
unless ::ENV["TOYS_DEV"]
  ::Kernel.exec(::File.join(::File.dirname(context_directory), "toys-dev"), *::ARGV)
end

expand :clean, paths: ["pkg", "doc", ".yardoc", "tmp", "Gemfile.lock"]

expand :minitest, libs: ["lib", "test"], bundler: true

expand :rubocop, bundler: true

expand :yardoc do |t|
  t.generate_output_flag = true
  t.fail_on_warning = true
  t.fail_on_undocumented_objects = true
  t.bundler = true
end

expand :rdoc, output_dir: "doc", bundler: true

expand :gem_build

expand :gem_build, name: "release", push_gem: true

expand :gem_build, name: "install", install_gem: true

tool "ci" do
  desc "Run all CI checks"

  long_desc "The CI tool runs all CI checks for the toys-core gem, including" \
              " unit tests, rubocop, and documentation checks. It is useful" \
              " for running tests in normal development, as well as being" \
              " the entrypoint for CI systems. Any failure will result in a" \
              " nonzero result code."

  include :terminal

  def run_stage(tool, name:)
    status = cli.run(tool)
    if status.zero?
      puts("** #{name} passed\n\n", :green, :bold)
    else
      puts("** CI terminated: #{name} failed!", :red, :bold)
      exit(1)
    end
  end

  def run
    run_stage("test", name: "Tests")
    run_stage("rubocop", name: "Style checker")
    run_stage("yardoc", name: "Docs generation")
  end
end
