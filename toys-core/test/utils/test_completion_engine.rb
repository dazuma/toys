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
require "toys/utils/completion_engine"

describe Toys::Utils::CompletionEngine do
  let(:logger) {
    Logger.new(StringIO.new).tap do |lgr|
      lgr.level = Logger::WARN
    end
  }
  let(:binary_name) { "toys" }
  let(:context_capture) {
    proc { |context|
      @context = context
      []
    }
  }
  let(:cli) {
    tester = self
    cli = Toys::CLI.new(binary_name: binary_name, logger: logger, middleware_stack: [])
    cli.add_config_block do
      tool "one" do
        flag :hello, completion: ["neighbor", "kitty"]
        flag :world, "--world VALUE", completion: ["building", "news"]
        flag :ruby, "--ruby [VALUE]", completion: ["gems", "tuesday"]
        required_arg :foo, completion: ["lish", "sball"]
        optional_arg :bar, completion: ["n", "k"]
        remaining_args :baz, completion: ["aar", "ooka"]
      end
      tool "two" do
      end
      tool "three" do
        tool "four" do
          flag :hello, completion: tester.context_capture
          flag :world, "--world VALUE", "-wVALUE", completion: tester.context_capture
          required_arg :foo, completion: tester.context_capture
          optional_arg :bar, completion: tester.context_capture
          remaining_args :baz, completion: tester.context_capture
        end
      end
    end
    cli
  }
  let(:loader) { cli.loader }
  let(:completion) { Toys::Utils::CompletionEngine.new(loader) }

  it "detects failure to find binary name" do
    result = completion.run_bash_internal("toys")
    assert_nil(result)
  end

  it "completes empty input" do
    result = completion.run_bash_internal("toys ")
    assert_equal(["one ", "three ", "two "], result)
  end

  it "completes t" do
    result = completion.run_bash_internal("toys t")
    assert_equal(["three ", "two "], result)
  end

  it "completes tw" do
    result = completion.run_bash_internal("toys tw")
    assert_equal(["two "], result)
  end

  it "completes subtool" do
    result = completion.run_bash_internal("toys three ")
    assert_equal(["four "], result)
  end

  it "completes flag names and first arg" do
    result = completion.run_bash_internal("toys one ")
    assert_equal(["--hello ", "--ruby ", "--world ", "lish ", "sball "], result)
  end

  it "completes flag names only" do
    result = completion.run_bash_internal("toys one --")
    assert_equal(["--hello ", "--ruby ", "--world "], result)
  end

  it "completes flag names and second arg" do
    result = completion.run_bash_internal("toys one x ")
    assert_equal(["--hello ", "--ruby ", "--world ", "k ", "n "], result)
  end

  it "completes flag names and remaining arg" do
    result = completion.run_bash_internal("toys one x y z ")
    assert_equal(["--hello ", "--ruby ", "--world ", "aar ", "ooka "], result)
  end

  it "completes after flag with no argument" do
    result = completion.run_bash_internal("toys one --hello ")
    assert_equal(["--hello ", "--ruby ", "--world ", "lish ", "sball "], result)
  end

  it "completes empty string after flag with required argument" do
    result = completion.run_bash_internal("toys one --world ")
    assert_equal(["building ", "news "], result)
  end

  it "completes empty string after flag with optional argument" do
    result = completion.run_bash_internal("toys one --ruby ")
    assert_equal(["--hello ", "--ruby ", "--world ", "gems ", "tuesday "], result)
  end

  it "completes apparent flag after flag with optional argument" do
    result = completion.run_bash_internal("toys one --ruby -")
    assert_equal(["--hello ", "--ruby ", "--world "], result)
  end

  it "completes after flag with its argument" do
    result = completion.run_bash_internal("toys one --ruby together ")
    assert_equal(["--hello ", "--ruby ", "--world ", "lish ", "sball "], result)
  end

  it "completes after flag ender" do
    result = completion.run_bash_internal("toys one -- ")
    assert_equal(["lish ", "sball "], result)
  end

  it "recognizes closed single quotes" do
    result = completion.run_bash_internal("toys 't'")
    assert_equal(["'three' ", "'two' "], result)
  end

  it "recognizes open single quotes" do
    result = completion.run_bash_internal("toys 't")
    assert_equal(["'three' ", "'two' "], result)
  end

  it "recognizes closed double quotes" do
    result = completion.run_bash_internal('toys "t"')
    assert_equal(['"three" ', '"two" '], result)
  end

  it "recognizes open double quotes" do
    result = completion.run_bash_internal('toys "t')
    assert_equal(['"three" ', '"two" '], result)
  end

  it "constructs context for no previous" do
    completion.run_bash_internal("toys three four --hello 123")
    assert_equal("123", @context.string)
    assert_nil(@context.previous)
  end

  it "constructs context for long flag with value" do
    completion.run_bash_internal("toys three four --world 123")
    assert_equal("123", @context.string)
    assert_equal("--world", @context.previous)
  end

  it "constructs context for long flag with equals value" do
    completion.run_bash_internal("toys three four --world=123")
    assert_equal("123", @context.string)
    assert_equal("--world=", @context.previous)
  end

  it "constructs context for single character flag with value" do
    completion.run_bash_internal("toys three four -w 123")
    assert_equal("123", @context.string)
    assert_equal("-w", @context.previous)
  end

  it "constructs context for single character flag with attached value" do
    completion.run_bash_internal("toys three four -w123")
    assert_equal("123", @context.string)
    assert_equal("-w", @context.previous)
  end

  it "constructs context for empty remaining args" do
    completion.run_bash_internal("toys three four foo bar ")
    assert_equal("", @context.string)
    assert_equal([], @context.previous)
  end

  it "constructs context for several remaining args" do
    completion.run_bash_internal("toys three four foo bar baz1 baz2 ")
    assert_equal("", @context.string)
    assert_equal(["baz1", "baz2"], @context.previous)
  end
end
