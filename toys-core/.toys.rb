# frozen_string_literal: true

# Copyright 2019 Daniel Azuma
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.
;

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
