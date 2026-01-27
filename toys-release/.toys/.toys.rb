# frozen_string_literal: true

# Run this against local Toys code instead of installed Toys gems.
# This is to support development of Toys itself. Most Toys files should not
# include this.
unless ::ENV["TOYS_DEV"]
  ::Kernel.exec(::File.join(::File.dirname(context_directory), "toys-dev"), *::ARGV)
end

expand :clean, paths: :gitignore

tool "test" do
  flag :integration_tests, "--integration-tests", "--integration", desc: "Enable integration tests"

  include :exec

  def run
    ::ENV["TOYS_TEST_INTEGRATION"] = "true" if integration_tests
    exit(cli.run(["system", "test", "-d", "toys", "--minitest-focus", "--minitest-rg"] + verbosity_flags))
  end
end

expand :rubocop, bundler: true

expand :yardoc do |t|
  t.generate_output_flag = true
  t.fail_on_warning = true
  t.fail_on_undocumented_objects = true
  t.bundler = true
end

tool "yardoc-test", delegate_to: "yardoc"

expand :rdoc, output_dir: "doc", bundler: true

expand :gem_build

expand :gem_build, name: "release", push_gem: true

expand :gem_build, name: "install", install_gem: true

tool "copy-core-docs" do
  desc "Unused for toys-release"

  flag :optimize, "--[no-]optimize"

  def run; end
end
