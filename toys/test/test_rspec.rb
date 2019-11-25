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
require "toys/utils/exec"

describe "rspec template" do
  let(:logger) {
    Logger.new(StringIO.new).tap do |lgr|
      lgr.level = Logger::WARN
    end
  }
  let(:executable_name) { "toys" }
  let(:cli) {
    Toys::CLI.new(
      executable_name: executable_name,
      logger: logger,
      middleware_stack: [],
      template_lookup: Toys::ModuleLookup.new.add_path("toys/templates")
    )
  }
  let(:loader) { cli.loader }
  let(:executor) { Toys::Utils::Exec.new(out: :capture, err: :capture) }

  it "executes a successful spec" do
    loader.add_block do
      expand :rspec, libs: File.join(__dir__, "rspec-cases", "lib1"),
                     pattern: File.join(__dir__, "rspec-cases", "spec", "*_spec.rb")
    end
    out, _err = capture_subprocess_io do
      assert_equal(0, cli.run("spec"))
    end
    assert_match(/1 example, 0 failures/, out)
  end

  it "executes an unsuccessful spec" do
    loader.add_block do
      expand :rspec, libs: File.join(__dir__, "rspec-cases", "lib2"),
                     pattern: File.join(__dir__, "rspec-cases", "spec", "*_spec.rb")
    end
    out, _err = capture_subprocess_io do
      refute_equal(0, cli.run("spec"))
    end
    assert_match(/1 example, 1 failure/, out)
  end
end
