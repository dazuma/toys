# frozen_string_literal: true

# Copyright 2018 Daniel Azuma
#
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice,
#   this list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# * Neither the name of the copyright holder, nor the names of any other
#   contributors to this software, may be used to endorse or promote products
#   derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
;

require "helper"

describe Toys::Runner do
  let(:logger) {
    Logger.new(StringIO.new).tap do |lgr|
      lgr.level = Logger::WARN
    end
  }
  let(:binary_name) { "toys" }
  let(:cli) { Toys::CLI.new(binary_name: binary_name, logger: logger, middleware_stack: []) }
  let(:loader) { cli.loader }
  let(:tool_name) { "foo" }
  let(:subtool_name) { "bar" }
  let(:subtool2_name) { "baz" }
  let(:root_tool) { loader.activate_tool_definition([], 0) }
  let(:tool) { loader.activate_tool_definition([tool_name], 0) }
  let(:subtool) { loader.activate_tool_definition([tool_name, subtool_name], 0) }
  let(:subtool2) { loader.activate_tool_definition([tool_name, subtool2_name], 0) }

  describe "option parsing" do
    it "allows empty arguments when none are specified" do
      assert_equal(false, tool.includes_definition?)
      test = self
      tool.runnable = proc do
        test.assert_equal({}, options)
      end
      assert_equal(0, Toys::Runner.new(cli, tool).run([]))
    end

    it "defaults simple boolean flag to nil" do
      test = self
      tool.add_flag(:a, ["-a", "--aa"], desc: "hi there")
      assert_equal(true, tool.includes_definition?)
      tool.runnable = proc do
        test.assert_equal({a: nil}, options)
      end
      assert_equal(0, Toys::Runner.new(cli, tool).run([]))
    end

    it "sets simple boolean flag" do
      test = self
      tool.add_flag(:a, ["-a", "--aa"], desc: "hi there")
      tool.runnable = proc do
        test.assert_equal({a: true}, options)
      end
      assert_equal(0, Toys::Runner.new(cli, tool).run(["--aa"]))
    end

    it "defaults value flag to nil" do
      test = self
      tool.add_flag(:a, ["-a", "--aa=VALUE"], desc: "hi there")
      tool.runnable = proc do
        test.assert_equal({a: nil}, options)
      end
      assert_equal(0, Toys::Runner.new(cli, tool).run([]))
    end

    it "honors given default of a value flag" do
      test = self
      tool.add_flag(:a, ["-a", "--aa=VALUE"], default: "hehe", desc: "hi there")
      tool.runnable = proc do
        test.assert_equal({a: "hehe"}, options)
      end
      assert_equal(0, Toys::Runner.new(cli, tool).run([]))
    end

    it "sets value flag" do
      test = self
      tool.add_flag(:a, ["-a", "--aa=VALUE"], desc: "hi there")
      tool.runnable = proc do
        test.assert_equal({a: "hoho"}, options)
      end
      assert_equal(0, Toys::Runner.new(cli, tool).run(["--aa", "hoho"]))
    end

    it "converts a value flag" do
      test = self
      tool.add_flag(:a, ["-a", "--aa=VALUE"], accept: Integer, desc: "hi there")
      tool.runnable = proc do
        test.assert_equal({a: 1234}, options)
      end
      assert_equal(0, Toys::Runner.new(cli, tool).run(["--aa", "1234"]))
    end

    it "checks match of a value flag" do
      test = self
      tool.add_flag(:a, ["-a", "--aa=VALUE"], accept: Integer, desc: "hi there")
      tool.runnable = proc do
        test.assert_match(/invalid argument: --aa a1234/, usage_error)
      end
      assert_equal(0, Toys::Runner.new(cli, tool).run(["--aa", "a1234"]))
    end

    it "converts a value flag using a custom acceptor" do
      test = self
      tool.add_acceptor(Toys::Definition::PatternAcceptor.new("myenum", /foo|bar/))
      tool.add_flag(:a, ["-a", "--aa=VALUE"], accept: "myenum", desc: "hi there")
      tool.runnable = proc do
        test.assert_equal({a: "bar"}, options)
      end
      assert_equal(0, Toys::Runner.new(cli, tool).run(["--aa", "bar"]))
    end

    it "checks match of a value flag using a custom acceptor" do
      test = self
      tool.add_acceptor(Toys::Definition::PatternAcceptor.new("myenum", /foo|bar/))
      tool.add_flag(:a, ["-a", "--aa=VALUE"], accept: "myenum", desc: "hi there")
      tool.runnable = proc do
        test.assert_match(/invalid argument: --aa 1234/, usage_error)
      end
      assert_equal(0, Toys::Runner.new(cli, tool).run(["--aa", "1234"]))
    end

    it "defaults the name of a value flag" do
      test = self
      tool.add_flag(:a_bc, accept: String, desc: "hi there")
      tool.runnable = proc do
        test.assert_equal({a_bc: "hoho"}, options)
      end
      assert_equal(0, Toys::Runner.new(cli, tool).run(["--a-bc", "hoho"]))
    end

    it "honors the handler" do
      test = self
      tool.add_flag(:a, ["-a", "--aa=VALUE"], default: "hi", handler: ->(v, c) { "#{c}#{v}" })
      tool.runnable = proc do
        test.assert_equal({a: "hiho"}, options)
      end
      assert_equal(0, Toys::Runner.new(cli, tool).run(["--aa", "ho"]))
    end

    it "errors on an unknown flag" do
      test = self
      tool.runnable = proc do
        test.assert_match(/invalid option: -a/, usage_error)
      end
      assert_equal(0, Toys::Runner.new(cli, tool).run(["-a"]))
    end
  end

  describe "argument parsing" do
    it "allows empty arguments when none are specified" do
      assert_equal(false, tool.includes_definition?)
      test = self
      tool.runnable = proc do
        test.assert_equal([], args)
      end
      assert_equal(0, Toys::Runner.new(cli, tool).run([]))
    end

    it "recognizes args in order" do
      test = self
      tool.add_optional_arg(:b)
      assert_equal(true, tool.includes_definition?)
      tool.add_optional_arg(:c)
      tool.add_required_arg(:a, desc: "Hello")
      tool.set_remaining_args(:d)
      tool.runnable = proc do
        test.assert_equal({a: "foo", b: "bar", c: "baz", d: ["hello", "world"]}, options)
      end
      assert_equal(0, Toys::Runner.new(cli, tool).run(["foo", "bar", "baz", "hello", "world"]))
    end

    it "omits optional args if not provided" do
      test = self
      tool.add_optional_arg(:b)
      tool.add_optional_arg(:c)
      tool.add_required_arg(:a, desc: "Hello")
      tool.set_remaining_args(:d)
      tool.runnable = proc do
        test.assert_equal({a: "foo", b: "bar", c: nil, d: []}, options)
      end
      assert_equal(0, Toys::Runner.new(cli, tool).run(["foo", "bar"]))
    end

    it "errors if required args are missing" do
      test = self
      tool.add_required_arg(:a)
      tool.add_required_arg(:b)
      tool.runnable = proc do
        test.assert_match(/No value given for required argument B/, usage_error)
      end
      assert_equal(0, Toys::Runner.new(cli, tool).run(["foo"]))
    end

    it "errors if there are too many arguments" do
      test = self
      tool.add_optional_arg(:b)
      tool.add_required_arg(:a)
      tool.runnable = proc do
        test.assert_match(/Extra arguments provided: baz/, usage_error)
      end
      assert_equal(0, Toys::Runner.new(cli, tool).run(["foo", "bar", "baz"]))
    end

    it "honors defaults for optional arg" do
      test = self
      tool.add_optional_arg(:b, default: "hello")
      tool.add_required_arg(:a)
      tool.runnable = proc do
        test.assert_equal({a: "foo", b: "hello"}, options)
      end
      assert_equal(0, Toys::Runner.new(cli, tool).run(["foo"]))
    end

    it "can be disabled" do
      test = self
      tool.disable_argument_parsing
      tool.runnable = proc do
        test.assert_equal(["foo", "--bar"], args)
      end
      assert_equal(0, Toys::Runner.new(cli, tool).run(["foo", "--bar"]))
    end
  end

  describe "execution" do
    it "handles no script defined" do
      assert_equal(-1, Toys::Runner.new(cli, tool).run([]))
    end

    it "runs initializer at the beginning" do
      test = self
      tool.add_initializer(proc { |a| set(:a, a) }, 123)
      tool.runnable = proc do
        test.assert_equal(123, get(:a))
      end
      assert_equal(0, Toys::Runner.new(cli, tool).run([]))
    end

    it "makes context fields available via convenience methods" do
      test = self
      tool.add_optional_arg(:arg1)
      tool.add_optional_arg(:arg2)
      tool.add_flag(:sw1, ["-a"])
      tool.runnable = proc do
        test.assert_equal(0, verbosity)
        test.assert_equal(test.tool, tool_definition)
        test.assert_equal(test.tool.full_name, tool_name)
        test.assert_instance_of(Logger, logger)
        test.assert_equal("toys", binary_name)
        test.assert_equal(["hello", "-a"], args)
        test.assert_equal({arg1: "hello", arg2: nil, sw1: true}, options)
      end
      assert_equal(0, Toys::Runner.new(cli, tool).run(["hello", "-a"]))
    end

    it "makes context fields available via get" do
      test = self
      tool.add_optional_arg(:arg1)
      tool.add_optional_arg(:arg2)
      tool.add_flag(:sw1, ["-a"])
      tool.runnable = proc do
        test.assert_equal(0, get(Toys::Tool::Keys::VERBOSITY))
        test.assert_equal(test.tool, get(Toys::Tool::Keys::TOOL_DEFINITION))
        test.assert_equal(test.tool.full_name, get(Toys::Tool::Keys::TOOL_NAME))
        test.assert_instance_of(Logger, get(Toys::Tool::Keys::LOGGER))
        test.assert_equal("toys", get(Toys::Tool::Keys::BINARY_NAME))
        test.assert_equal(["hello", "-a"], get(Toys::Tool::Keys::ARGS))
      end
      assert_equal(0, Toys::Runner.new(cli, tool).run(["hello", "-a"]))
    end

    it "makes options available via get" do
      test = self
      tool.add_optional_arg(:arg1)
      tool.add_optional_arg(:arg2)
      tool.add_flag(:sw1, ["-a"])
      tool.runnable = proc do
        test.assert_equal(true, get(:sw1))
        test.assert_equal("hello", get(:arg1))
        test.assert_nil(get(:arg2))
      end
      assert_equal(0, Toys::Runner.new(cli, tool).run(["hello", "-a"]))
    end

    it "supports exit code" do
      tool.runnable = proc do
        exit(2)
      end
      assert_equal(2, Toys::Runner.new(cli, tool).run([]))
    end

    it "supports sub-runs" do
      test = self
      subtool.add_optional_arg(:arg1)
      subtool.runnable = proc do
        test.assert_equal("hi", self[:arg1])
        exit(cli.run(test.tool_name, test.subtool2_name, "ho"))
      end
      subtool2.add_optional_arg(:arg2)
      subtool2.runnable = proc do
        test.assert_equal("ho", self[:arg2])
        exit(3)
      end
      assert_equal(3, Toys::Runner.new(cli, subtool).run(["hi"]))
    end
  end
end
