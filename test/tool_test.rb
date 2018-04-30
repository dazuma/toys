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

describe Toys::Tool do
  let(:loader) { Toys::Loader.new }
  let(:binary_name) { "toys" }
  let(:tool_name) { "foo" }
  let(:full_tool_name) { "fool" }
  let(:subtool_name) { "bar" }
  let(:subtool2_name) { "baz" }
  let(:root_tool) { Toys::Tool.new([], []) }
  let(:tool) { Toys::Tool.new([tool_name], []) }
  let(:subtool) { Toys::Tool.new([tool_name, subtool_name], []) }
  let(:subtool2) { Toys::Tool.new([tool_name, subtool2_name], []) }
  let(:full_tool) { Toys::Tool.new([full_tool_name], Toys::CLI::DEFAULT_MIDDLEWARE) }
  let(:logger) {
    Logger.new(StringIO.new).tap do |lgr|
      lgr.level = Logger::WARN
    end
  }
  let(:context_base) { Toys::Context::Base.new(loader, binary_name, logger) }

  describe "names" do
    it "works for a root tool" do
      assert_nil(root_tool.simple_name)
      assert_equal([], root_tool.full_name)
    end

    it "works for a toplevel tool" do
      assert_equal(tool_name, tool.simple_name)
      assert_equal([tool_name], tool.full_name)
    end

    it "works for a subtool" do
      assert_equal(subtool_name, subtool.simple_name)
      assert_equal([tool_name, subtool_name], subtool.full_name)
    end
  end

  describe "definition state" do
    it "defaults to empty" do
      assert_equal(false, tool.includes_description?)
      assert_equal(false, tool.includes_definition?)
      assert_equal(false, tool.includes_executor?)
    end

    it "prevents defining from multiple paths" do
      tool.defining_from("path1") do
        tool.desc = "hi"
        tool.long_desc = "hiho"
      end
      assert_raises(Toys::ToolDefinitionError) do
        tool.desc = "ho"
      end
    end
  end

  describe "option parsing" do
    it "allows empty arguments when none are specified" do
      assertions = self
      tool.executor = proc do
        assertions.assert_equal({}, options)
        assertions.assert_equal([], args)
      end
      assert_equal(0, tool.execute(context_base, []))
    end

    it "defaults simple boolean switch to nil" do
      assertions = self
      tool.add_switch(:a, "-a", "--aa", doc: "hi there")
      tool.executor = proc do
        assertions.assert_equal({a: nil}, options)
      end
      assert_equal(0, tool.execute(context_base, []))
    end

    it "sets simple boolean switch" do
      assertions = self
      tool.add_switch(:a, "-a", "--aa", doc: "hi there")
      tool.executor = proc do
        assertions.assert_equal({a: true}, options)
      end
      assert_equal(0, tool.execute(context_base, ["--aa"]))
    end

    it "defaults value switch to nil" do
      assertions = self
      tool.add_switch(:a, "-a", "--aa=VALUE", doc: "hi there")
      tool.executor = proc do
        assertions.assert_equal({a: nil}, options)
      end
      assert_equal(0, tool.execute(context_base, []))
    end

    it "honors given default of a value switch" do
      assertions = self
      tool.add_switch(:a, "-a", "--aa=VALUE", default: "hehe", doc: "hi there")
      tool.executor = proc do
        assertions.assert_equal({a: "hehe"}, options)
      end
      assert_equal(0, tool.execute(context_base, []))
    end

    it "sets value switch" do
      assertions = self
      tool.add_switch(:a, "-a", "--aa=VALUE", doc: "hi there")
      tool.executor = proc do
        assertions.assert_equal({a: "hoho"}, options)
      end
      assert_equal(0, tool.execute(context_base, ["--aa", "hoho"]))
    end

    it "converts a value switch" do
      assertions = self
      tool.add_switch(:a, "-a", "--aa=VALUE", accept: Integer, doc: "hi there")
      tool.executor = proc do
        assertions.assert_equal({a: 1234}, options)
      end
      assert_equal(0, tool.execute(context_base, ["--aa", "1234"]))
    end

    it "checks match of a value switch" do
      assertions = self
      tool.add_switch(:a, "-a", "--aa=VALUE", accept: Integer, doc: "hi there")
      tool.executor = proc do
        assertions.assert_match(/invalid argument: --aa a1234/, usage_error)
      end
      assert_equal(0, tool.execute(context_base, ["--aa", "a1234"]))
    end

    it "defaults the name of a value switch" do
      assertions = self
      tool.add_switch(:a_bc, doc: "hi there")
      tool.executor = proc do
        assertions.assert_equal({a_bc: "hoho"}, options)
      end
      assert_equal(0, tool.execute(context_base, ["--a-bc", "hoho"]))
    end

    it "errors on an unknown switch" do
      assertions = self
      tool.executor = proc do
        assertions.assert_match(/invalid option: -a/, usage_error)
      end
      assert_equal(0, tool.execute(context_base, ["-a"]))
    end

    it "recognizes args in order" do
      assertions = self
      tool.add_optional_arg(:b)
      tool.add_optional_arg(:c)
      tool.add_required_arg(:a, doc: "Hello")
      tool.set_remaining_args(:d)
      tool.executor = proc do
        assertions.assert_equal({a: "foo", b: "bar", c: "baz", d: ["hello", "world"]}, options)
      end
      assert_equal(0, tool.execute(context_base, ["foo", "bar", "baz", "hello", "world"]))
    end

    it "omits optional args if not provided" do
      assertions = self
      tool.add_optional_arg(:b)
      tool.add_optional_arg(:c)
      tool.add_required_arg(:a, doc: "Hello")
      tool.set_remaining_args(:d)
      tool.executor = proc do
        assertions.assert_equal({a: "foo", b: "bar", c: nil, d: []}, options)
      end
      assert_equal(0, tool.execute(context_base, ["foo", "bar"]))
    end

    it "errors if required args are missing" do
      assertions = self
      tool.add_required_arg(:a)
      tool.add_required_arg(:b)
      tool.executor = proc do
        assertions.assert_match(/No value given for required argument named <b>/, usage_error)
      end
      assert_equal(0, tool.execute(context_base, ["foo"]))
    end

    it "errors if there are too many arguments" do
      assertions = self
      tool.add_optional_arg(:b)
      tool.add_required_arg(:a)
      tool.executor = proc do
        assertions.assert_match(/Extra arguments provided: baz/, usage_error)
      end
      assert_equal(0, tool.execute(context_base, ["foo", "bar", "baz"]))
    end

    it "honors defaults for optional arg" do
      assertions = self
      tool.add_optional_arg(:b, default: "hello")
      tool.add_required_arg(:a)
      tool.executor = proc do
        assertions.assert_equal({a: "foo", b: "hello"}, options)
      end
      assert_equal(0, tool.execute(context_base, ["foo"]))
    end
  end

  describe "default component stack" do
    it "honors --verbose flag" do
      assertions = self
      full_tool.executor = proc do
        assertions.assert_equal(Logger::DEBUG, logger.level)
      end
      assert_equal(0, full_tool.execute(context_base, ["-v", "--verbose"]))
    end

    it "honors --quiet flag" do
      assertions = self
      full_tool.executor = proc do
        assertions.assert_equal(Logger::FATAL, logger.level)
      end
      assert_equal(0, full_tool.execute(context_base, ["-q", "--quiet"]))
    end

    it "prints help for a command with an executor" do
      full_tool.executor = proc do
        raise "shouldn't have gotten here"
      end
      assert_output(/Usage:/) do
        assert_equal(0, full_tool.execute(context_base, ["--help"]))
      end
    end

    it "prints help for a command with no executor" do
      assert_output(/Usage:/) do
        assert_equal(0, full_tool.execute(context_base, []))
      end
    end

    it "prints usage error" do
      full_tool.add_optional_arg(:b)
      full_tool.add_required_arg(:a)
      full_tool.executor = proc do
        raise "shouldn't have gotten here"
      end
      assert_output(/Extra arguments provided: baz/) do
        refute_equal(0, full_tool.execute(context_base, ["foo", "bar", "baz"]))
      end
    end
  end

  describe "helper" do
    it "can be defined on a tool" do
      assertions = self
      tool.add_helper("hello_helper") { |val| val * 2 }
      tool.executor = proc do
        assertions.assert_equal(4, hello_helper(2))
      end
      assert_equal(0, tool.execute(context_base, []))
    end

    it "cannot begin with an underscore" do
      assert_raises(Toys::ToolDefinitionError) do
        tool.add_helper("_hello_helper") { |val| val * 2 }
      end
    end
  end

  describe "helper module" do
    it "can be looked up from standard helpers" do
      assertions = self
      tool.use_module(:file_utils)
      tool.executor = proc do
        assertions.assert_equal(true, private_methods.include?(:rm_rf))
      end
      assert_equal(0, tool.execute(context_base, []))
    end
  end

  describe "aliases" do
  end
end
