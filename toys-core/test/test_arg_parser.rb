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

  describe "flag parsing" do
    describe "boolean flag" do
      it "defaults to nil" do
        tool.add_flag(:a, ["-a", "--aa"])
        arg_parser.parse([])
        arg_parser.finish
        assert_equal({a: nil}, arg_parser.data)
        assert_empty(arg_parser.errors)
      end

      it "sets value" do
        tool.add_flag(:a, ["-a", "--aa"])
        arg_parser.parse(["--aa"])
        arg_parser.finish
        assert_equal({a: true}, arg_parser.data)
        assert_empty(arg_parser.errors)
      end

      it "sets positive value" do
        tool.add_flag(:a, ["--[no-]aa"])
        arg_parser.parse(["--aa"])
        arg_parser.finish
        assert_equal({a: true}, arg_parser.data)
        assert_empty(arg_parser.errors)
      end

      it "sets negative value" do
        tool.add_flag(:a, ["--[no-]aa"])
        arg_parser.parse(["--no-aa"])
        arg_parser.finish
        assert_equal({a: false}, arg_parser.data)
        assert_empty(arg_parser.errors)
      end

      it "recognizes a substring" do
        tool.add_flag(:a, ["-a", "--abcde"])
        arg_parser.parse(["--ab"])
        arg_parser.finish
        assert_equal({a: true}, arg_parser.data)
        assert_empty(arg_parser.errors)
      end

      it "allows multiple setting" do
        tool.add_flag(:a, ["-a", "--aa"])
        arg_parser.parse(["--aa", "-a"])
        arg_parser.finish
        assert_equal({a: true}, arg_parser.data)
        assert_empty(arg_parser.errors)
      end

      it "honors a proc handler" do
        tool.add_flag(:a, ["-a", "--aa"], default: 0, handler: ->(_v, c) { c + 1 })
        arg_parser.parse(["--aa", "-a", "-a"])
        arg_parser.finish
        assert_equal({a: 3}, arg_parser.data)
        assert_empty(arg_parser.errors)
      end

      it "recognizes squashed single flags" do
        tool.add_flag(:a, ["-a"], default: 0, handler: ->(_v, c) { c + 1 })
        tool.add_flag(:b, ["-b"], default: 0, handler: ->(_v, c) { c + 1 })
        arg_parser.parse(["-babba"])
        arg_parser.finish
        assert_equal({a: 2, b: 3}, arg_parser.data)
        assert_empty(arg_parser.errors)
      end

      it "creates a default flag name" do
        tool.add_flag(:a_bc)
        arg_parser.parse(["--a-bc"])
        arg_parser.finish
        assert_equal({a_bc: true}, arg_parser.data)
        assert_empty(arg_parser.errors)
      end

      it "should not accept an argument" do
        tool.add_flag(:a, ["--aa"])
        arg_parser.parse(["--aa=hi"])
        arg_parser.finish
        assert_includes(arg_parser.errors, "Flag \"--aa\" should not take an argument.")
      end
    end

    describe "required value flag" do
      it "defaults value to nil" do
        tool.add_flag(:a, ["-a", "--aa=VALUE"])
        arg_parser.parse([])
        arg_parser.finish
        assert_equal({a: nil}, arg_parser.data)
        assert_empty(arg_parser.errors)
      end

      it "honors given default" do
        tool.add_flag(:a, ["-a", "--aa=VALUE"], default: "hehe")
        arg_parser.parse([])
        arg_parser.finish
        assert_equal({a: "hehe"}, arg_parser.data)
        assert_empty(arg_parser.errors)
      end

      it "sets value using long flag and separate argument" do
        tool.add_flag(:a, ["-a", "--aa=VALUE"])
        arg_parser.parse(["--aa", "hoho"])
        arg_parser.finish
        assert_equal({a: "hoho"}, arg_parser.data)
        assert_empty(arg_parser.errors)
      end

      it "sets value using long flag and =" do
        tool.add_flag(:a, ["-a", "--aa=VALUE"])
        arg_parser.parse(["--aa=hoho"])
        arg_parser.finish
        assert_equal({a: "hoho"}, arg_parser.data)
        assert_empty(arg_parser.errors)
      end

      it "sets value using short flag and separate argument" do
        tool.add_flag(:a, ["-a", "--aa=VALUE"])
        arg_parser.parse(["-a", "hoho"])
        arg_parser.finish
        assert_equal({a: "hoho"}, arg_parser.data)
        assert_empty(arg_parser.errors)
      end

      it "sets value using short flag and attached argument" do
        tool.add_flag(:a, ["-a", "--aa=VALUE"])
        arg_parser.parse(["-ahoho"])
        arg_parser.finish
        assert_equal({a: "hoho"}, arg_parser.data)
        assert_empty(arg_parser.errors)
      end

      it "honors the last setting" do
        tool.add_flag(:a, ["-a", "--aa=VALUE"])
        arg_parser.parse(["--aa", "hoho", "-a", "hehe"])
        arg_parser.finish
        assert_equal({a: "hehe"}, arg_parser.data)
        assert_empty(arg_parser.errors)
      end

      it "recognizes short flag value in a squashed setting" do
        tool.add_flag(:a, ["-aVALUE"])
        tool.add_flag(:b, ["-b"], default: 0, handler: ->(_v, c) { c + 1 })
        arg_parser.parse(["-bbaba"])
        arg_parser.finish
        assert_equal({a: "ba", b: 2}, arg_parser.data)
        assert_empty(arg_parser.errors)
      end

      it "allows a value to look like a flag" do
        tool.add_flag(:a, ["-a", "--aa=VALUE"])
        arg_parser.parse(["--aa", "--aa"])
        arg_parser.finish
        assert_equal({a: "--aa"}, arg_parser.data)
        assert_empty(arg_parser.errors)
      end

      it "converts a value" do
        tool.add_flag(:a, ["-a", "--aa=VALUE"], accept: Integer)
        arg_parser.parse(["--aa", "1234"])
        arg_parser.finish
        assert_equal({a: 1234}, arg_parser.data)
        assert_empty(arg_parser.errors)
      end

      it "checks match of a value" do
        tool.add_flag(:a, ["-a", "--aa=VALUE"], accept: Integer)
        arg_parser.parse(["--aa", "a1234"])
        arg_parser.finish
        assert_includes(arg_parser.errors, "Unacceptable value for flag \"--aa\".")
      end

      it "converts a value using a custom acceptor" do
        tool.add_acceptor(Toys::Definition::EnumAcceptor.new("myenum", [:foo, :bar]))
        tool.add_flag(:a, ["-a", "--aa=VALUE"], accept: "myenum")
        arg_parser.parse(["--aa", "bar"])
        arg_parser.finish
        assert_equal({a: :bar}, arg_parser.data)
        assert_empty(arg_parser.errors)
      end

      it "handles match failure using a custom acceptor" do
        tool.add_acceptor(Toys::Definition::EnumAcceptor.new("myenum", [:foo, :bar]))
        tool.add_flag(:a, ["-a", "--aa=VALUE"], accept: "myenum")
        arg_parser.parse(["--aa", "1234"])
        arg_parser.finish
        assert_includes(arg_parser.errors, "Unacceptable value for flag \"--aa\".")
      end

      it "creates a default flag name" do
        tool.add_flag(:a_bc, accept: String)
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

      it "errors if no value is given with = delimiter" do
        tool.add_flag(:a, ["-a", "--aa=VALUE"])
        arg_parser.parse(["--aa"])
        arg_parser.finish
        assert_includes(arg_parser.errors, "Flag \"--aa\" is missing a value.")
      end

      it "errors if no value is given with space delimiter" do
        tool.add_flag(:a, ["-a", "--aa VALUE"])
        arg_parser.parse(["--aa"])
        arg_parser.finish
        assert_includes(arg_parser.errors, "Flag \"--aa\" is missing a value.")
      end
    end

    describe "optional value flag" do
      it "sets a given default" do
        tool.add_flag(:a, ["--aa=[VALUE]"], default: "def")
        tool.set_remaining_args(:r)
        arg_parser.parse([])
        arg_parser.finish
        assert_equal({a: "def", r: []}, arg_parser.data)
        assert_empty(arg_parser.errors)
      end

      describe "long option with = delimiter" do
        before do
          tool.add_flag(:a, ["--aa=[VALUE]"], default: "def")
          tool.set_remaining_args(:r)
        end

        it "recognizes setting with =" do
          arg_parser.parse(["--aa=hoho"])
          arg_parser.finish
          assert_equal({a: "hoho", r: []}, arg_parser.data)
          assert_empty(arg_parser.errors)
        end

        it "goes to nil when the value is in a separate arg" do
          arg_parser.parse(["--aa", "hoho"])
          arg_parser.finish
          assert_equal({a: nil, r: ["hoho"]}, arg_parser.data)
          assert_empty(arg_parser.errors)
        end

        it "goes to nil when no more args are available" do
          arg_parser.parse(["--aa"])
          arg_parser.finish
          assert_equal({a: nil, r: []}, arg_parser.data)
          assert_empty(arg_parser.errors)
        end
      end

      describe "long option with space delimiter" do
        before do
          tool.add_flag(:a, ["--aa [VALUE]"], default: "def")
          tool.set_remaining_args(:r)
        end

        it "recognizes setting with =" do
          arg_parser.parse(["--aa=hoho"])
          arg_parser.finish
          assert_equal({a: "hoho", r: []}, arg_parser.data)
          assert_empty(arg_parser.errors)
        end

        it "recognizes a value in a separate arg" do
          arg_parser.parse(["--aa", "hoho"])
          arg_parser.finish
          assert_equal({a: "hoho", r: []}, arg_parser.data)
          assert_empty(arg_parser.errors)
        end

        it "goes to nil if the next separate arg looks like a flag" do
          arg_parser.parse(["--aa", "--"])
          arg_parser.finish
          assert_equal({a: nil, r: []}, arg_parser.data)
          assert_empty(arg_parser.errors)
        end

        it "goes to nil when no more args are available" do
          arg_parser.parse(["--aa"])
          arg_parser.finish
          assert_equal({a: nil, r: []}, arg_parser.data)
          assert_empty(arg_parser.errors)
        end
      end

      describe "short option with attached value" do
        before do
          tool.add_flag(:a, ["-a[VALUE]"], default: "def")
          tool.set_remaining_args(:r)
        end

        it "recognizes setting with attached value" do
          arg_parser.parse(["-ahoho"])
          arg_parser.finish
          assert_equal({a: "hoho", r: []}, arg_parser.data)
          assert_empty(arg_parser.errors)
        end

        it "recognizes setting with attached value even when the next character could be a flag" do
          tool.add_flag(:h, ["-h"])
          arg_parser.parse(["-ahoho"])
          arg_parser.finish
          assert_equal({a: "hoho", r: [], h: nil}, arg_parser.data)
          assert_empty(arg_parser.errors)
        end

        it "goes to nil when the value is in a separate arg" do
          arg_parser.parse(["-a", "hoho"])
          arg_parser.finish
          assert_equal({a: nil, r: ["hoho"]}, arg_parser.data)
          assert_empty(arg_parser.errors)
        end

        it "goes to nil when at the end of a squash and the value is in a separate arg" do
          tool.add_flag(:h, ["-h"])
          arg_parser.parse(["-ha", "hoho"])
          arg_parser.finish
          assert_equal({a: nil, r: ["hoho"], h: true}, arg_parser.data)
          assert_empty(arg_parser.errors)
        end

        it "goes to nil when no more args are available" do
          arg_parser.parse(["-a"])
          arg_parser.finish
          assert_equal({a: nil, r: []}, arg_parser.data)
          assert_empty(arg_parser.errors)
        end
      end

      describe "short option with space delimiter" do
        before do
          tool.add_flag(:a, ["-a [VALUE]"], default: "def")
          tool.set_remaining_args(:r)
        end

        it "recognizes setting with attached value" do
          arg_parser.parse(["-ahoho"])
          arg_parser.finish
          assert_equal({a: "hoho", r: []}, arg_parser.data)
          assert_empty(arg_parser.errors)
        end

        it "recognizes setting with attached value even when the next character could be a flag" do
          tool.add_flag(:h, ["-h"])
          arg_parser.parse(["-ahoho"])
          arg_parser.finish
          assert_equal({a: "hoho", r: [], h: nil}, arg_parser.data)
          assert_empty(arg_parser.errors)
        end

        it "recognizes a value in a separate arg" do
          arg_parser.parse(["-a", "hoho"])
          arg_parser.finish
          assert_equal({a: "hoho", r: []}, arg_parser.data)
          assert_empty(arg_parser.errors)
        end

        it "recognizes a value in a separate arg when at the end of a squash" do
          tool.add_flag(:h, ["-h"])
          arg_parser.parse(["-ha", "hoho"])
          arg_parser.finish
          assert_equal({a: "hoho", r: [], h: true}, arg_parser.data)
          assert_empty(arg_parser.errors)
        end

        it "goes to nil when no more args are available" do
          arg_parser.parse(["-a"])
          arg_parser.finish
          assert_equal({a: nil, r: []}, arg_parser.data)
          assert_empty(arg_parser.errors)
        end
      end
    end

    it "errors on an unknown flag" do
      arg_parser.parse(["-a"])
      arg_parser.finish
      assert_includes(arg_parser.errors, "Flag \"-a\" is not recognized.")
    end

    it "errors on ambiguous flag" do
      tool.add_flag(:abc)
      tool.add_flag(:abd)
      arg_parser.parse(["--ab"])
      arg_parser.finish
      assert_includes(arg_parser.errors, "Flag prefix \"--ab\" is ambiguous.")
    end

    it "stops flag parsing after --" do
      tool.add_flag(:a, ["-a", "--aa VALUE"])
      tool.set_remaining_args(:b)
      arg_parser.parse(["--", "--aa", "hoho"])
      arg_parser.finish
      assert_equal({a: nil, b: ["--aa", "hoho"]}, arg_parser.data)
    end
  end

  describe "flag groups" do
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

    it "converts a value using a custom acceptor" do
      tool.add_acceptor(Toys::Definition::EnumAcceptor.new("myenum", [:foo, :bar]))
      tool.add_optional_arg(:a, accept: "myenum")
      arg_parser.parse(["bar"])
      arg_parser.finish
      assert_equal({a: :bar}, arg_parser.data)
      assert_empty(arg_parser.errors)
    end

    it "handles match failure using a custom acceptor" do
      tool.add_acceptor(Toys::Definition::EnumAcceptor.new("myenum", [:foo, :bar]))
      tool.add_optional_arg(:a, accept: "myenum")
      arg_parser.parse(["1234"])
      arg_parser.finish
      assert_includes(arg_parser.errors, "Unacceptable value for arg \"A\".")
    end
  end
end
