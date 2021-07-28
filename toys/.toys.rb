# frozen_string_literal: true

# Run this against local Toys code instead of installed Toys gems.
# This is to support development of Toys itself. Most Toys files should not
# include this.
unless ::ENV["TOYS_DEV"]
  ::Kernel.exec(::File.join(::File.dirname(context_directory), "toys-dev"), *::ARGV)
end

expand :clean, paths: :gitignore

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

  long_desc "The CI tool runs all CI checks for the toys gem, including unit" \
              " tests, rubocop, and documentation checks. It is useful for" \
              " running tests in normal development, as well as being the" \
              " entrypoint for CI systems. Any failure will result in a" \
              " nonzero result code."

  include :exec, result_callback: :handle_result
  include :terminal

  def handle_result(result)
    if result.success?
      puts("** #{result.name} passed\n\n", :green, :bold)
    else
      puts("** CI terminated: #{result.name} failed!", :red, :bold)
      exit(1)
    end
  end

  def run
    exec_tool(["test"], name: "Tests")
    exec_tool(["rubocop"], name: "Style checker")
    exec_tool(["yardoc-full"], name: "Docs generation")
    exec_tool(["build"], name: "Gem build")
  end
end

class YardocFull < Toys::Tool
  STAGING_DIR = "toys-core"

  desc "Generate full yardoc including classes from toys-core"

  include :exec, e: true
  include :fileutils

  def run
    cd(context_directory)
    rm_rf(STAGING_DIR)
    begin
      mkdir_p(STAGING_DIR)
      cp_r("../toys-core/lib", STAGING_DIR)
      add_notice
      exec_tool(["yardoc-full", "_generate"])
    ensure
      rm_rf(STAGING_DIR)
    end
  end

  def add_notice
    pat = /\n(?<in> *)##\n(?<def>(?:\k<in>#[^\n]*\n)+\k<in>(?:module|class) [A-Z]\w+)/
    repl = "\n\\k<in>##\n\\k<in># **_Defined in the toys-core gem_**\n\\k<in>#\n\\k<def>"
    Dir.glob("#{STAGING_DIR}/**/*.rb") do |path|
      content = File.read(path)
      if content.gsub!(pat, repl)
        File.open(path, "w") { |file| file.write(content) }
      end
    end
  end

  expand :yardoc do |t|
    t.name = "_generate"
    t.files = ["./#{STAGING_DIR}/**/*.rb"]
    t.bundler = true
  end
end
