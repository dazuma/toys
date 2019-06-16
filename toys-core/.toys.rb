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
::Kernel.exec(::File.join(::File.dirname(__dir__), "toys-dev"), *::ARGV) unless ::ENV["TOYS_DEV"]

expand :clean, paths: ["pkg", "doc", ".yardoc", "tmp"]

expand :minitest, libs: ["lib", "test"]

expand :rubocop

expand :yardoc do |t|
  t.generate_output_flag = true
  t.fail_on_warning = true
  t.fail_on_undocumented_objects = true
end

expand :rdoc, output_dir: "doc"

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
    exec_tool(["yardoc"], name: "Docs generation")
  end
end
