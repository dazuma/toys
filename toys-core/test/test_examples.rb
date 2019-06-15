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

require "helper"
require "fileutils"
require "English"

describe "toys-core" do
  def assert_succeeds(cmd)
    system cmd
    assert($CHILD_STATUS.success?, "Command failed: #{cmd}")
  end

  it "builds gems and runs examples" do
    core_dir = File.dirname(__dir__)
    tmp_dir = File.join(core_dir, "tmp")
    gems_dir = File.join(tmp_dir, "gems")
    bin_dir = File.join(tmp_dir, "bin")
    core_gem_pkg = File.join(tmp_dir, "core.gem")
    simple_gem_pkg = File.join(tmp_dir, "simple.gem")
    multi_file_gem_pkg = File.join(tmp_dir, "multi-file.gem")
    examples_dir = File.join(core_dir, "examples")
    simple_example_dir = File.join(examples_dir, "simple-gem")
    multi_file_example_dir = File.join(examples_dir, "multi-file-gem")

    FileUtils.rm_rf(tmp_dir)
    FileUtils.mkdir_p(gems_dir)
    FileUtils.mkdir_p(bin_dir)

    Dir.chdir(core_dir) do
      assert_succeeds("gem build -o #{core_gem_pkg} toys-core.gemspec >/dev/null 2>&1")
    end
    assert_succeeds("gem install -i #{gems_dir} -n #{bin_dir} --ignore-dependencies" \
                    " #{core_gem_pkg} >/dev/null")

    Dir.chdir(simple_example_dir) do
      assert_succeeds("GEM_PATH=#{gems_dir} gem build -o #{simple_gem_pkg}" \
                      " toys-core-simple-example.gemspec >/dev/null 2>&1")
    end
    Dir.chdir(multi_file_example_dir) do
      assert_succeeds("GEM_PATH=#{gems_dir} gem build -o #{multi_file_gem_pkg}" \
                      " toys-core-multi-file-example.gemspec >/dev/null 2>&1")
    end
    assert_succeeds("gem install -i #{gems_dir} -n #{bin_dir} --ignore-dependencies" \
                    " #{simple_gem_pkg} >/dev/null")
    assert_succeeds("gem install -i #{gems_dir} -n #{bin_dir} --ignore-dependencies" \
                    " #{multi_file_gem_pkg} >/dev/null")

    assert_equal("Hello, Toys!\n",
                 `GEM_PATH=#{gems_dir} #{bin_dir}/toys-core-simple-example --whom=Toys`)
    assert_equal("Hello, Toys!\n",
                 `GEM_PATH=#{gems_dir} #{bin_dir}/toys-core-multi-file-example greet --whom=Toys`)

    FileUtils.rm_rf(tmp_dir)
  end
end
