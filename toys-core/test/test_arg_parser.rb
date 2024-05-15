# frozen_string_literal: true

require "helper"

describe Toys::ArgParser do
  let(:supports_suggestions?) { ::Toys::Compat.supports_suggestions? }
  let(:executable_name) { "toys" }
  let(:cli) {
    Toys::CLI.new(executable_name: executable_name, middleware_stack: [],
                  index_file_name: ".toys.rb", data_dir_name: ".data")
  }
  let(:loader) { cli.loader }
  let(:tool_name) { "foo" }
  let(:root_tool) { loader.activate_tool([], 0) }
  let(:tool) { loader.activate_tool([tool_name], 0) }
  let(:arg_parser) { Toys::ArgParser.new(cli, tool) }
  let(:root_arg_parser) { Toys::ArgParser.new(cli, root_tool) }

  def assert_data_includes(expected, data)
    expected.each do |k, v|
      assert_equal(true, data.key?(k), "data does not include key #{k.inspect}")
      if v.nil?
        assert_nil(data[k], "data for key #{k.inspect} was #{data[k].inspect}, expected nil")
      else
        assert_equal(v, data[k],
                     "data for key #{k.inspect} was #{data[k].inspect}, expected #{v.inspect}")
      end
    end
  end

  def assert_errors_include(expected, errors)
    return if errors.any? do |err|
      case expected
      when ::String
        err.message == expected
      when ::Array
        err.suggestions == expected
      when ::Class
        err.is_a?(expected)
      end
    end
    flunk("Errors #{errors.inspect} did not include expected #{expected.inspect}")
  end

  it "allows empty arguments when none are specified" do
    arg_parser.parse([])
    arg_parser.finish
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
    assert_data_includes({a: "hello", b: "world", c: "today"}, arg_parser.data)
  end

  it "collects parsed args" do
    tool.set_remaining_args(:a)
    tool.add_flag(:a, ["-a", "--aa"])
    tool.add_flag(:b, ["-b", "--bb=VALUE"])
    arg_parser.parse(["hello", "world", "-a"])
    arg_parser.parse(["--bb=yoyo", "ruby"])
    assert_equal(["hello", "world", "-a", "--bb=yoyo", "ruby"], arg_parser.parsed_args)
  end

  it "honors enforce_flags_before_args" do
    tool.enforce_flags_before_args
    tool.add_flag(:a)
    tool.add_flag(:b)
    tool.set_remaining_args(:c)
    arg_parser.parse(["-a", "hello", "-b"])
    arg_parser.finish
    assert_data_includes({a: true, b: nil, c: ["hello", "-b"]}, arg_parser.data)
    assert_empty(arg_parser.errors)
  end

  it "records unmatched" do
    tool.add_flag(:a)
    tool.add_optional_arg(:b)
    arg_parser.parse(["x", "y", "-b", "-a", "z"])
    assert_equal(["y", "z"], arg_parser.unmatched_positional)
    assert_equal(["-b"], arg_parser.unmatched_flags)
    assert_equal(["y", "-b", "z"], arg_parser.unmatched_args)
  end

  describe "flag parsing" do
    describe "boolean flag" do
      it "defaults to nil" do
        tool.add_flag(:a, ["-a", "--aa"])
        arg_parser.parse([])
        arg_parser.finish
        assert_data_includes({a: nil}, arg_parser.data)
        assert_empty(arg_parser.errors)
      end

      it "sets value" do
        tool.add_flag(:a, ["-a", "--aa"])
        arg_parser.parse(["--aa"])
        arg_parser.finish
        assert_data_includes({a: true}, arg_parser.data)
        assert_empty(arg_parser.errors)
      end

      it "sets positive value" do
        tool.add_flag(:a, ["--[no-]aa"])
        arg_parser.parse(["--aa"])
        arg_parser.finish
        assert_data_includes({a: true}, arg_parser.data)
        assert_empty(arg_parser.errors)
      end

      it "sets negative value" do
        tool.add_flag(:a, ["--[no-]aa"])
        arg_parser.parse(["--no-aa"])
        arg_parser.finish
        assert_data_includes({a: false}, arg_parser.data)
        assert_empty(arg_parser.errors)
      end

      it "recognizes a substring" do
        tool.add_flag(:a, ["-a", "--abcde"])
        arg_parser.parse(["--ab"])
        arg_parser.finish
        assert_data_includes({a: true}, arg_parser.data)
        assert_empty(arg_parser.errors)
      end

      it "allows multiple setting" do
        tool.add_flag(:a, ["-a", "--aa"])
        arg_parser.parse(["--aa", "-a"])
        arg_parser.finish
        assert_data_includes({a: true}, arg_parser.data)
        assert_empty(arg_parser.errors)
      end

      it "honors a proc handler" do
        tool.add_flag(:a, ["-a", "--aa"], default: 0, handler: ->(_v, c) { c + 1 })
        arg_parser.parse(["--aa", "-a", "-a"])
        arg_parser.finish
        assert_data_includes({a: 3}, arg_parser.data)
        assert_empty(arg_parser.errors)
      end

      it "recognizes squashed single flags" do
        tool.add_flag(:a, ["-a"], default: 0, handler: ->(_v, c) { c + 1 })
        tool.add_flag(:b, ["-b"], default: 0, handler: ->(_v, c) { c + 1 })
        arg_parser.parse(["-babba"])
        arg_parser.finish
        assert_data_includes({a: 2, b: 3}, arg_parser.data)
        assert_empty(arg_parser.errors)
      end

      it "creates a default flag name" do
        tool.add_flag(:a_bc)
        arg_parser.parse(["--a-bc"])
        arg_parser.finish
        assert_data_includes({a_bc: true}, arg_parser.data)
        assert_empty(arg_parser.errors)
      end

      it "should not accept an argument" do
        tool.add_flag(:a, ["--aa"])
        arg_parser.parse(["--aa=hi"])
        arg_parser.finish
        assert_errors_include('Flag "--aa" should not take an argument.', arg_parser.errors)
      end
    end

    describe "required value flag" do
      it "defaults value to nil" do
        tool.add_flag(:a, ["-a", "--aa=VALUE"])
        arg_parser.parse([])
        arg_parser.finish
        assert_data_includes({a: nil}, arg_parser.data)
        assert_empty(arg_parser.errors)
      end

      it "honors given default" do
        tool.add_flag(:a, ["-a", "--aa=VALUE"], default: "hehe")
        arg_parser.parse([])
        arg_parser.finish
        assert_data_includes({a: "hehe"}, arg_parser.data)
        assert_empty(arg_parser.errors)
      end

      it "sets value using long flag and separate argument" do
        tool.add_flag(:a, ["-a", "--aa=VALUE"])
        arg_parser.parse(["--aa", "hoho"])
        arg_parser.finish
        assert_data_includes({a: "hoho"}, arg_parser.data)
        assert_empty(arg_parser.errors)
      end

      it "sets value using long flag and =" do
        tool.add_flag(:a, ["-a", "--aa=VALUE"])
        arg_parser.parse(["--aa=hoho"])
        arg_parser.finish
        assert_data_includes({a: "hoho"}, arg_parser.data)
        assert_empty(arg_parser.errors)
      end

      it "sets value using short flag and separate argument" do
        tool.add_flag(:a, ["-a", "--aa=VALUE"])
        arg_parser.parse(["-a", "hoho"])
        arg_parser.finish
        assert_data_includes({a: "hoho"}, arg_parser.data)
        assert_empty(arg_parser.errors)
      end

      it "sets value using short flag and attached argument" do
        tool.add_flag(:a, ["-a", "--aa=VALUE"])
        arg_parser.parse(["-ahoho"])
        arg_parser.finish
        assert_data_includes({a: "hoho"}, arg_parser.data)
        assert_empty(arg_parser.errors)
      end

      it "honors the last setting" do
        tool.add_flag(:a, ["-a", "--aa=VALUE"])
        arg_parser.parse(["--aa", "hoho", "-a", "hehe"])
        arg_parser.finish
        assert_data_includes({a: "hehe"}, arg_parser.data)
        assert_empty(arg_parser.errors)
      end

      it "recognizes short flag value in a squashed setting" do
        tool.add_flag(:a, ["-aVALUE"])
        tool.add_flag(:b, ["-b"], default: 0, handler: ->(_v, c) { c + 1 })
        arg_parser.parse(["-bbaba"])
        arg_parser.finish
        assert_data_includes({a: "ba", b: 2}, arg_parser.data)
        assert_empty(arg_parser.errors)
      end

      it "allows a value to look like a flag" do
        tool.add_flag(:a, ["-a", "--aa=VALUE"])
        arg_parser.parse(["--aa", "--aa"])
        arg_parser.finish
        assert_data_includes({a: "--aa"}, arg_parser.data)
        assert_empty(arg_parser.errors)
      end

      it "converts a value" do
        tool.add_flag(:a, ["-a", "--aa=VALUE"], accept: Integer)
        arg_parser.parse(["--aa", "1234"])
        arg_parser.finish
        assert_data_includes({a: 1234}, arg_parser.data)
        assert_empty(arg_parser.errors)
      end

      it "checks match of a value" do
        tool.add_flag(:a, ["-a", "--aa=VALUE"], accept: Integer)
        arg_parser.parse(["--aa", "a1234"])
        arg_parser.finish
        assert_errors_include('Unacceptable value "a1234" for flag "--aa".', arg_parser.errors)
      end

      it "converts a value using a custom acceptor" do
        tool.add_acceptor("myenum", Toys::Acceptor::Enum.new([:foo, :bar]))
        tool.add_flag(:a, ["-a", "--aa=VALUE"], accept: "myenum")
        arg_parser.parse(["--aa", "bar"])
        arg_parser.finish
        assert_data_includes({a: :bar}, arg_parser.data)
        assert_empty(arg_parser.errors)
      end

      it "handles match failure using a custom acceptor" do
        tool.add_acceptor("myenum", Toys::Acceptor::Enum.new([:foo, :bar]))
        tool.add_flag(:a, ["-a", "--aa=VALUE"], accept: "myenum")
        arg_parser.parse(["--aa", "1234"])
        arg_parser.finish
        assert_errors_include('Unacceptable value "1234" for flag "--aa".', arg_parser.errors)
      end

      it "creates a default flag name" do
        tool.add_flag(:a_bc, accept: String)
        arg_parser.parse(["--a-bc", "hoho"])
        arg_parser.finish
        assert_data_includes({a_bc: "hoho"}, arg_parser.data)
        assert_empty(arg_parser.errors)
      end

      it "honors a proc handler" do
        tool.add_flag(:a, ["-a", "--aa=VALUE"], default: "hi", handler: ->(v, c) { "#{c}#{v}" })
        arg_parser.parse(["--aa", "ho"])
        arg_parser.finish
        assert_data_includes({a: "hiho"}, arg_parser.data)
        assert_empty(arg_parser.errors)
      end

      it "honors the push handler" do
        tool.add_flag(:a, ["-a", "--aa=VALUE"], handler: :push)
        arg_parser.parse(["--aa", "hi", "-a", "ho"])
        arg_parser.finish
        assert_data_includes({a: ["hi", "ho"]}, arg_parser.data)
        assert_empty(arg_parser.errors)
      end

      it "errors if no value is given with = delimiter" do
        tool.add_flag(:a, ["-a", "--aa=VALUE"])
        arg_parser.parse(["--aa"])
        arg_parser.finish
        assert_errors_include('Flag "--aa" is missing a value.', arg_parser.errors)
      end

      it "errors if no value is given with space delimiter" do
        tool.add_flag(:a, ["-a", "--aa VALUE"])
        arg_parser.parse(["--aa"])
        arg_parser.finish
        assert_errors_include('Flag "--aa" is missing a value.', arg_parser.errors)
      end

      it "allows an = value with a newline" do
        tool.add_flag(:a, ["-a", "--aa=VALUE"])
        arg_parser.parse(["--aa=hi\nho"])
        arg_parser.finish
        assert_data_includes({a: "hi\nho"}, arg_parser.data)
        assert_empty(arg_parser.errors)
      end

      it "allows a separate value with a newline" do
        tool.add_flag(:a, ["-a", "--aa=VALUE"])
        arg_parser.parse(["--aa", "hi\nho"])
        arg_parser.finish
        assert_data_includes({a: "hi\nho"}, arg_parser.data)
        assert_empty(arg_parser.errors)
      end
    end

    describe "optional value flag" do
      it "sets a given default" do
        tool.add_flag(:a, ["--aa=[VALUE]"], default: "def")
        tool.set_remaining_args(:r)
        arg_parser.parse([])
        arg_parser.finish
        assert_data_includes({a: "def", r: []}, arg_parser.data)
        assert_empty(arg_parser.errors)
      end

      it "defaults to nil if absent" do
        tool.add_flag(:a, ["--aa=[VALUE]"])
        tool.set_remaining_args(:r)
        arg_parser.parse([])
        arg_parser.finish
        assert_data_includes({a: nil, r: []}, arg_parser.data)
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
          assert_data_includes({a: "hoho", r: []}, arg_parser.data)
          assert_empty(arg_parser.errors)
        end

        it "goes to true when the value is in a separate arg" do
          arg_parser.parse(["--aa", "hoho"])
          arg_parser.finish
          assert_data_includes({a: true, r: ["hoho"]}, arg_parser.data)
          assert_empty(arg_parser.errors)
        end

        it "goes to true when no more args are available" do
          arg_parser.parse(["--aa"])
          arg_parser.finish
          assert_data_includes({a: true, r: []}, arg_parser.data)
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
          assert_data_includes({a: "hoho", r: []}, arg_parser.data)
          assert_empty(arg_parser.errors)
        end

        it "recognizes a value in a separate arg" do
          arg_parser.parse(["--aa", "hoho"])
          arg_parser.finish
          assert_data_includes({a: "hoho", r: []}, arg_parser.data)
          assert_empty(arg_parser.errors)
        end

        it "goes to true if the next separate arg looks like a flag" do
          tool.add_flag(:bb)
          arg_parser.parse(["--aa", "--bb"])
          arg_parser.finish
          assert_data_includes({a: true, bb: true, r: []}, arg_parser.data)
          assert_empty(arg_parser.errors)
        end

        it "goes to true if followed by the end-flags signal" do
          arg_parser.parse(["--aa", "--"])
          arg_parser.finish
          assert_data_includes({a: true, r: []}, arg_parser.data)
          assert_empty(arg_parser.errors)
        end

        it "goes to true when no more args are available" do
          arg_parser.parse(["--aa"])
          arg_parser.finish
          assert_data_includes({a: true, r: []}, arg_parser.data)
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
          assert_data_includes({a: "hoho", r: []}, arg_parser.data)
          assert_empty(arg_parser.errors)
        end

        it "recognizes setting with attached value even when the next character could be a flag" do
          tool.add_flag(:h, ["-h"])
          arg_parser.parse(["-ahoho"])
          arg_parser.finish
          assert_data_includes({a: "hoho", r: [], h: nil}, arg_parser.data)
          assert_empty(arg_parser.errors)
        end

        it "goes to true when the value is in a separate arg" do
          arg_parser.parse(["-a", "hoho"])
          arg_parser.finish
          assert_data_includes({a: true, r: ["hoho"]}, arg_parser.data)
          assert_empty(arg_parser.errors)
        end

        it "goes to true when at the end of a squash and the value is in a separate arg" do
          tool.add_flag(:h, ["-h"])
          arg_parser.parse(["-ha", "hoho"])
          arg_parser.finish
          assert_data_includes({a: true, r: ["hoho"], h: true}, arg_parser.data)
          assert_empty(arg_parser.errors)
        end

        it "goes to true when no more args are available" do
          arg_parser.parse(["-a"])
          arg_parser.finish
          assert_data_includes({a: true, r: []}, arg_parser.data)
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
          assert_data_includes({a: "hoho", r: []}, arg_parser.data)
          assert_empty(arg_parser.errors)
        end

        it "recognizes setting with attached value even when the next character could be a flag" do
          tool.add_flag(:h, ["-h"])
          arg_parser.parse(["-ahoho"])
          arg_parser.finish
          assert_data_includes({a: "hoho", r: [], h: nil}, arg_parser.data)
          assert_empty(arg_parser.errors)
        end

        it "recognizes a value in a separate arg" do
          arg_parser.parse(["-a", "hoho"])
          arg_parser.finish
          assert_data_includes({a: "hoho", r: []}, arg_parser.data)
          assert_empty(arg_parser.errors)
        end

        it "recognizes a value in a separate arg when at the end of a squash" do
          tool.add_flag(:h, ["-h"])
          arg_parser.parse(["-ha", "hoho"])
          arg_parser.finish
          assert_data_includes({a: "hoho", r: [], h: true}, arg_parser.data)
          assert_empty(arg_parser.errors)
        end

        it "goes to true when no more args are available" do
          arg_parser.parse(["-a"])
          arg_parser.finish
          assert_data_includes({a: true, r: []}, arg_parser.data)
          assert_empty(arg_parser.errors)
        end
      end

      describe "long option with space delimiter and an acceptor" do
        before do
          tool.add_flag(:a, ["--aa [VALUE]"], accept: Integer)
          tool.set_remaining_args(:r)
        end

        it "accepts a number" do
          arg_parser.parse(["--aa", "123"])
          arg_parser.finish
          assert_data_includes({a: 123, r: []}, arg_parser.data)
          assert_empty(arg_parser.errors)
        end

        it "accepts true when there are no more args" do
          arg_parser.parse(["--aa"])
          arg_parser.finish
          assert_data_includes({a: true, r: []}, arg_parser.data)
          assert_empty(arg_parser.errors)
        end
      end

      describe "long option with = delimiter and an acceptor" do
        before do
          tool.add_flag(:a, ["--aa[=VALUE]"], accept: Integer)
          tool.set_remaining_args(:r)
        end

        it "accepts a number" do
          arg_parser.parse(["--aa=123"])
          arg_parser.finish
          assert_data_includes({a: 123, r: []}, arg_parser.data)
          assert_empty(arg_parser.errors)
        end

        it "accepts true when the value is in a separate arg" do
          arg_parser.parse(["--aa", "123"])
          arg_parser.finish
          assert_data_includes({a: true, r: ["123"]}, arg_parser.data)
          assert_empty(arg_parser.errors)
        end

        it "accepts true when there are no more args" do
          arg_parser.parse(["--aa"])
          arg_parser.finish
          assert_data_includes({a: true, r: []}, arg_parser.data)
          assert_empty(arg_parser.errors)
        end
      end

      describe "short option with attached value and an acceptor" do
        before do
          tool.add_flag(:a, ["-a[VALUE]"], accept: Integer)
          tool.set_remaining_args(:r)
        end

        it "accepts a number" do
          arg_parser.parse(["-a123"])
          arg_parser.finish
          assert_data_includes({a: 123, r: []}, arg_parser.data)
          assert_empty(arg_parser.errors)
        end

        it "accepts true when there are no more args" do
          arg_parser.parse(["-a"])
          arg_parser.finish
          assert_data_includes({a: true, r: []}, arg_parser.data)
          assert_empty(arg_parser.errors)
        end
      end

      describe "short option with space delimiter and an acceptor" do
        before do
          tool.add_flag(:a, ["-a [VALUE]"], accept: Integer)
          tool.set_remaining_args(:r)
        end

        it "accepts a number" do
          arg_parser.parse(["-a", "123"])
          arg_parser.finish
          assert_data_includes({a: 123, r: []}, arg_parser.data)
          assert_empty(arg_parser.errors)
        end

        it "accepts true when there are no more args" do
          arg_parser.parse(["-a"])
          arg_parser.finish
          assert_data_includes({a: true, r: []}, arg_parser.data)
          assert_empty(arg_parser.errors)
        end
      end
    end

    it "errors on an unknown flag" do
      arg_parser.parse(["-a"])
      arg_parser.finish
      assert_errors_include('Flag "-a" is not recognized.', arg_parser.errors)
      assert_errors_include([], arg_parser.errors)
      assert_includes(arg_parser.unmatched_flags, "-a")
    end

    it "errors on an unknown flag with suggestions" do
      tool.add_flag(:abcde)
      arg_parser.parse(["--abcdd"])
      arg_parser.finish
      assert_errors_include('Flag "--abcdd" is not recognized.', arg_parser.errors)
      assert_errors_include(["--abcde"], arg_parser.errors) if supports_suggestions?
      assert_includes(arg_parser.unmatched_flags, "--abcdd")
    end

    it "errors on ambiguous flag" do
      tool.add_flag(:abc)
      tool.add_flag(:abd)
      arg_parser.parse(["--ab"])
      arg_parser.finish
      assert_errors_include('Flag prefix "--ab" is ambiguous.', arg_parser.errors)
      assert_errors_include(["--abc", "--abd"], arg_parser.errors)
    end

    it "matches partially" do
      tool.add_flag(:abcde)
      arg_parser.parse(["--ab"])
      arg_parser.finish
      assert_data_includes({abcde: true}, arg_parser.data)
    end

    it "does not match partially" do
      tool.add_flag(:abcde)
      arg_parser = Toys::ArgParser.new(cli, tool, require_exact_flag_match: true)
      arg_parser.parse(["--abcd"])
      arg_parser.finish
      assert_errors_include('Flag "--abcd" is not recognized.', arg_parser.errors)
      assert_errors_include(["--abcde"], arg_parser.errors) if supports_suggestions?
      assert_includes(arg_parser.unmatched_flags, "--abcd")
    end

    it "stops flag parsing after --" do
      tool.add_flag(:a, ["-a", "--aa VALUE"])
      tool.set_remaining_args(:b)
      arg_parser.parse(["--", "--aa", "hoho"])
      arg_parser.finish
      assert_data_includes({a: nil, b: ["--aa", "hoho"]}, arg_parser.data)
    end
  end

  describe "flag group" do
    describe "of type required" do
      before do
        tool.add_flag_group(type: :required, name: :mygroup, desc: "My Group")
        tool.add_flag(:a, group: :mygroup)
        tool.add_flag(:b, group: :mygroup)
      end

      it "succeeds when all flags are provided" do
        arg_parser.parse(["-a", "-b"])
        arg_parser.finish
        assert_data_includes({a: true, b: true}, arg_parser.data)
        assert_empty(arg_parser.errors)
      end

      it "errors when flags are missing" do
        arg_parser.parse([])
        arg_parser.finish
        assert_errors_include('Flag "-a" is required.', arg_parser.errors)
        assert_errors_include('Flag "-b" is required.', arg_parser.errors)
      end
    end

    describe "of type exactly_one" do
      before do
        tool.add_flag_group(type: :exactly_one, name: :mygroup, desc: "My Group")
        tool.add_flag(:a, group: :mygroup)
        tool.add_flag(:b, group: :mygroup)
      end

      it "succeeds when one flag is provided" do
        arg_parser.parse(["-b"])
        arg_parser.finish
        assert_data_includes({a: nil, b: true}, arg_parser.data)
        assert_empty(arg_parser.errors)
      end

      it "errors when no flag is provided" do
        arg_parser.parse([])
        arg_parser.finish
        assert_errors_include('Exactly one flag out of group "My Group" is required, but' \
                              " none were provided.", arg_parser.errors)
      end

      it "errors when mulitple flags are provided" do
        arg_parser.parse(["-a", "-b"])
        arg_parser.finish
        assert_errors_include('Exactly one flag out of group "My Group" is required, but' \
                              ' 2 were provided: ["-a", "-b"].', arg_parser.errors)
      end
    end

    describe "of type at_most_one" do
      before do
        tool.add_flag_group(type: :at_most_one, name: :mygroup, desc: "My Group")
        tool.add_flag(:a, group: :mygroup)
        tool.add_flag(:b, group: :mygroup)
      end

      it "succeeds when one flag is provided" do
        arg_parser.parse(["-b"])
        arg_parser.finish
        assert_data_includes({a: nil, b: true}, arg_parser.data)
        assert_empty(arg_parser.errors)
      end

      it "succeeds when no flag is provided" do
        arg_parser.parse([])
        arg_parser.finish
        assert_data_includes({a: nil, b: nil}, arg_parser.data)
        assert_empty(arg_parser.errors)
      end

      it "errors when mulitple flags are provided" do
        arg_parser.parse(["-a", "-b"])
        arg_parser.finish
        assert_errors_include('At most one flag out of group "My Group" is required, but' \
                              ' 2 were provided: ["-a", "-b"].', arg_parser.errors)
      end
    end

    describe "of type at_least_one" do
      before do
        tool.add_flag_group(type: :at_least_one, name: :mygroup, desc: "My Group")
        tool.add_flag(:a, group: :mygroup)
        tool.add_flag(:b, group: :mygroup)
      end

      it "succeeds when one flag is provided" do
        arg_parser.parse(["-b"])
        arg_parser.finish
        assert_data_includes({a: nil, b: true}, arg_parser.data)
        assert_empty(arg_parser.errors)
      end

      it "errors when no flag is provided" do
        arg_parser.parse([])
        arg_parser.finish
        assert_errors_include('At least one flag out of group "My Group" is required, but' \
                              " none were provided.", arg_parser.errors)
      end

      it "succeeds when mulitple flags are provided" do
        arg_parser.parse(["-a", "-b"])
        arg_parser.finish
        assert_data_includes({a: true, b: true}, arg_parser.data)
        assert_empty(arg_parser.errors)
      end
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
      assert_data_includes({a: "foo", b: "bar", c: "baz", d: ["hello", "world"]}, arg_parser.data)
      assert_empty(arg_parser.errors)
    end

    it "omits optional args if not provided" do
      tool.add_optional_arg(:b)
      tool.add_optional_arg(:c)
      tool.add_required_arg(:a, desc: "Hello")
      tool.set_remaining_args(:d)
      arg_parser.parse(["foo", "bar"])
      arg_parser.finish
      assert_data_includes({a: "foo", b: "bar", c: nil, d: []}, arg_parser.data)
      assert_empty(arg_parser.errors)
    end

    it "errors if required args are missing" do
      tool.add_required_arg(:a)
      tool.add_required_arg(:b)
      arg_parser.parse(["foo"])
      arg_parser.finish
      assert_errors_include('Required positional argument "B" is missing.', arg_parser.errors)
    end

    it "errors on runnable tool if there are too many arguments" do
      tool.add_optional_arg(:b)
      tool.add_required_arg(:a)
      tool.run_handler = proc { nil }
      arg_parser.parse(["foo", "bar", "baz"])
      arg_parser.finish
      assert_errors_include('Extra arguments: "baz".', arg_parser.errors)
      assert_equal(["baz"], arg_parser.unmatched_positional)
    end

    it "errors non-runnable tool if there are too many arguments" do
      tool.add_optional_arg(:b)
      tool.add_required_arg(:a)
      arg_parser.parse(["foo", "bar", "baz"])
      arg_parser.finish
      assert_errors_include('Tool not found: "foo baz"', arg_parser.errors)
      assert_equal(["baz"], arg_parser.unmatched_positional)
    end

    it "includes tool suggestions" do
      tool.run_handler = proc { nil }
      root_arg_parser.parse(["fop"])
      root_arg_parser.finish
      assert_errors_include('Tool not found: "fop"', root_arg_parser.errors)
      assert_errors_include(["foo"], root_arg_parser.errors) if supports_suggestions?
    end

    it "honors defaults for optional arg" do
      tool.add_optional_arg(:b, default: "hello")
      tool.add_required_arg(:a)
      arg_parser.parse(["foo"])
      arg_parser.finish
      assert_data_includes({a: "foo", b: "hello"}, arg_parser.data)
      assert_empty(arg_parser.errors)
    end

    it "converts a value using a custom acceptor" do
      tool.add_acceptor("myenum", Toys::Acceptor::Enum.new([:foo, :bar]))
      tool.add_optional_arg(:a, accept: "myenum")
      arg_parser.parse(["bar"])
      arg_parser.finish
      assert_data_includes({a: :bar}, arg_parser.data)
      assert_empty(arg_parser.errors)
    end

    it "handles match failure using a custom acceptor" do
      tool.add_acceptor("myenum", Toys::Acceptor::Enum.new([:foo, :bar]))
      tool.add_optional_arg(:a, accept: "myenum")
      arg_parser.parse(["baz"])
      arg_parser.finish
      assert_errors_include('Unacceptable value "baz" for positional argument "A".',
                            arg_parser.errors)
      assert_errors_include(["bar"], arg_parser.errors) if supports_suggestions?
    end
  end
end
