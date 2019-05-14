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
require "toys/utils/bash_completion"

describe Toys::Utils::BashCompletion do
  let(:logger) {
    Logger.new(StringIO.new).tap do |lgr|
      lgr.level = Logger::WARN
    end
  }
  let(:binary_name) { "toys" }
  let(:cli) {
    cli = Toys::CLI.new(binary_name: binary_name, logger: logger, middleware_stack: [])
    cli.add_config_block do
      tool "one" do
        flag :hello
      end
      tool "two" do
      end
      tool "three" do
        tool "four" do
        end
      end
    end
    cli
  }
  let(:loader) { cli.loader }
  let(:completion) { Toys::Utils::BashCompletion.new(loader) }

  it "detects failure to find binary name" do
    result = completion.compute("toys")
    assert_nil(result)
  end

  it "completes empty input" do
    result = completion.compute("toys ")
    assert_equal(["one", "three", "two"], result)
  end

  it "completes t" do
    result = completion.compute("toys t")
    assert_equal(["three", "two"], result)
  end

  it "completes tw" do
    result = completion.compute("toys tw")
    assert_equal(["two"], result)
  end

  it "completes subtool" do
    result = completion.compute("toys three ")
    assert_equal(["four"], result)
  end

  it "completes hello flag" do
    result = completion.compute("toys one --")
    assert_equal(["--hello"], result)
  end

  it "recognizes closed single quotes" do
    result = completion.compute("toys 't'")
    assert_equal(["'three'", "'two'"], result)
  end

  it "recognizes open single quotes" do
    result = completion.compute("toys 't")
    assert_equal(["'three'", "'two'"], result)
  end

  it "recognizes closed double quotes" do
    result = completion.compute('toys "t"')
    assert_equal(['"three"', '"two"'], result)
  end

  it "recognizes open double quotes" do
    result = completion.compute('toys "t')
    assert_equal(['"three"', '"two"'], result)
  end
end
