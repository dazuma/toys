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

describe Toys::ArgParser do
  let(:binary_name) { "toys" }
  let(:cli) {
    Toys::CLI.new(binary_name: binary_name, middleware_stack: [],
                  index_file_name: ".toys.rb", data_directory_name: ".data")
  }
  let(:loader) { cli.loader }
  let(:tool_name) { "foo" }
  let(:root_tool) { loader.activate_tool_definition([], 0) }
  let(:tool) { loader.activate_tool_definition([tool_name], 0) }
  let(:arg_parser) { Toys::ArgParser.new(tool) }

  describe "misc cases" do
    it "allows empty arguments when none are specified" do
      arg_parser.parse([])
      arg_parser.finish
      assert_equal({}, arg_parser.data)
      assert_empty(arg_parser.errors)
    end

    it "finishes parsing" do
      assert_equal(false, arg_parser.finished?)
      arg_parser.parse([])
      assert_equal(false, arg_parser.finished?)
      arg_parser.finish
      assert_equal(true, arg_parser.finished?)
      assert_raises(::StandardError) do
        arg_parser.parse(["hello"])
      end
    end

    it "honors tool defaults" do
      tool.add_flag(:a, ["-a", "--aa=VALUE"], default: "hello")
      tool.add_optional_arg(:b, default: "world")
      tool.default_data[:c] = "today"
      assert_equal({a: "hello", b: "world", c: "today"}, arg_parser.data)
    end

    it "collects parsed args" do
      tool.set_remaining_args(:a)
      tool.add_flag(:a, ["-a", "--aa"])
      tool.add_flag(:b, ["-b", "--bb=VALUE"])
      arg_parser.parse(["hello", "world", "-a"])
      arg_parser.parse(["--bb=yoyo", "ruby"])
      assert_equal(["hello", "world", "-a", "--bb=yoyo", "ruby"], arg_parser.parsed_args)
    end
  end

  describe "flag parsing" do
    it "defaults simple boolean flag to nil" do
      tool.add_flag(:a, ["-a", "--aa"], desc: "hi there")
      arg_parser.parse([])
      arg_parser.finish
      assert_equal({a: nil}, arg_parser.data)
      assert_empty(arg_parser.errors)
    end

    it "sets simple boolean flag" do
      tool.add_flag(:a, ["-a", "--aa"], desc: "hi there")
      arg_parser.parse(["--aa"])
      arg_parser.finish
      assert_equal({a: true}, arg_parser.data)
      assert_empty(arg_parser.errors)
    end

    it "defaults value flag to nil" do
      tool.add_flag(:a, ["-a", "--aa=VALUE"], desc: "hi there")
      arg_parser.parse([])
      arg_parser.finish
      assert_equal({a: nil}, arg_parser.data)
      assert_empty(arg_parser.errors)
    end

    it "honors given default of a value flag" do
      tool.add_flag(:a, ["-a", "--aa=VALUE"], default: "hehe", desc: "hi there")
      arg_parser.parse([])
      arg_parser.finish
      assert_equal({a: "hehe"}, arg_parser.data)
      assert_empty(arg_parser.errors)
    end

    it "sets value flag" do
      tool.add_flag(:a, ["-a", "--aa=VALUE"], desc: "hi there")
      arg_parser.parse(["--aa", "hoho"])
      arg_parser.finish
      assert_equal({a: "hoho"}, arg_parser.data)
      assert_empty(arg_parser.errors)
    end

    it "converts a value flag" do
      tool.add_flag(:a, ["-a", "--aa=VALUE"], accept: Integer, desc: "hi there")
      arg_parser.parse(["--aa", "1234"])
      arg_parser.finish
      assert_equal({a: 1234}, arg_parser.data)
      assert_empty(arg_parser.errors)
    end

    it "checks match of a value flag" do
      tool.add_flag(:a, ["-a", "--aa=VALUE"], accept: Integer, desc: "hi there")
      arg_parser.parse(["--aa", "a1234"])
      arg_parser.finish
      assert_includes(arg_parser.errors, "Unacceptable value for flag \"--aa\".")
    end

    it "converts a value flag using a custom acceptor" do
      tool.add_acceptor(Toys::Definition::PatternAcceptor.new("myenum", /foo|bar/))
      tool.add_flag(:a, ["-a", "--aa=VALUE"], accept: "myenum", desc: "hi there")
      arg_parser.parse(["--aa", "bar"])
      arg_parser.finish
      assert_equal({a: "bar"}, arg_parser.data)
      assert_empty(arg_parser.errors)
    end

    it "checks match of a value flag using a custom acceptor" do
      tool.add_acceptor(Toys::Definition::PatternAcceptor.new("myenum", /foo|bar/))
      tool.add_flag(:a, ["-a", "--aa=VALUE"], accept: "myenum", desc: "hi there")
      arg_parser.parse(["--aa", "1234"])
      arg_parser.finish
      assert_includes(arg_parser.errors, "Unacceptable value for flag \"--aa\".")
    end

    it "defaults the name of a value flag" do
      tool.add_flag(:a_bc, accept: String, desc: "hi there")
      arg_parser.parse(["--a-bc", "hoho"])
      arg_parser.finish
      assert_equal({a_bc: "hoho"}, arg_parser.data)
      assert_empty(arg_parser.errors)
    end

    it "honors a proc handler" do
      tool.add_flag(:a, ["-a", "--aa=VALUE"], default: "hi", handler: ->(v, c) { "#{c}#{v}" })
      arg_parser.parse(["--aa", "ho"])
      arg_parser.finish
      assert_equal({a: "hiho"}, arg_parser.data)
      assert_empty(arg_parser.errors)
    end

    it "honors the push handler" do
      tool.add_flag(:a, ["-a", "--aa=VALUE"], handler: :push)
      arg_parser.parse(["--aa", "hi", "-a", "ho"])
      arg_parser.finish
      assert_equal({a: ["hi", "ho"]}, arg_parser.data)
      assert_empty(arg_parser.errors)
    end

    it "errors on an unknown flag" do
      arg_parser.parse(["-a"])
      arg_parser.finish
      assert_includes(arg_parser.errors, "Flag \"-a\" is not recognized.")
    end

    it "supports flags in a group" do
      tool.add_flag_group(type: :required, name: :mygroup)
      tool.add_flag(:a, ["-a"], group: :mygroup)
      arg_parser.parse(["-a"])
      arg_parser.finish
      assert_equal({a: true}, arg_parser.data)
      assert_empty(arg_parser.errors)
    end

    it "errors when a required flag is not provided" do
      tool.add_flag_group(type: :required, name: :mygroup)
      tool.add_flag(:a, ["-a"], group: :mygroup)
      arg_parser.parse([])
      arg_parser.finish
      assert_includes(arg_parser.errors, "Flag \"-a\" is required.")
    end
  end

  describe "argument parsing" do
    it "recognizes args in order" do
      tool.add_optional_arg(:b)
      assert_equal(true, tool.includes_definition?)
      tool.add_optional_arg(:c)
      tool.add_required_arg(:a, desc: "Hello")
      tool.set_remaining_args(:d)
      arg_parser.parse(["foo", "bar", "baz", "hello", "world"])
      arg_parser.finish
      assert_equal({a: "foo", b: "bar", c: "baz", d: ["hello", "world"]}, arg_parser.data)
      assert_empty(arg_parser.errors)
    end

    it "omits optional args if not provided" do
      tool.add_optional_arg(:b)
      tool.add_optional_arg(:c)
      tool.add_required_arg(:a, desc: "Hello")
      tool.set_remaining_args(:d)
      arg_parser.parse(["foo", "bar"])
      arg_parser.finish
      assert_equal({a: "foo", b: "bar", c: nil, d: []}, arg_parser.data)
      assert_empty(arg_parser.errors)
    end

    it "errors if required args are missing" do
      tool.add_required_arg(:a)
      tool.add_required_arg(:b)
      arg_parser.parse(["foo"])
      arg_parser.finish
      assert_includes(arg_parser.errors, "Required argument \"B\" is missing.")
    end

    it "errors on runnable tool if there are too many arguments" do
      tool.add_optional_arg(:b)
      tool.add_required_arg(:a)
      tool.runnable = proc {}
      arg_parser.parse(["foo", "bar", "baz"])
      arg_parser.finish
      assert_includes(arg_parser.errors, "Extra arguments: [\"baz\"].")
    end

    it "errors non-runnable tool if there are too many arguments" do
      tool.add_optional_arg(:b)
      tool.add_required_arg(:a)
      arg_parser.parse(["foo", "bar", "baz"])
      arg_parser.finish
      assert_includes(arg_parser.errors, 'Tool not found: ["foo", "foo", "bar", "baz"].')
    end

    it "honors defaults for optional arg" do
      tool.add_optional_arg(:b, default: "hello")
      tool.add_required_arg(:a)
      arg_parser.parse(["foo"])
      arg_parser.finish
      assert_equal({a: "foo", b: "hello"}, arg_parser.data)
      assert_empty(arg_parser.errors)
    end
  end
end
