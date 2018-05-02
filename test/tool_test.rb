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
  let(:alias_name) { "alz" }
  let(:root_tool) { Toys::Tool.new([]) }
  let(:tool) { Toys::Tool.new([tool_name]) }
  let(:subtool) { Toys::Tool.new([tool_name, subtool_name]) }
  let(:subtool2) { Toys::Tool.new([tool_name, subtool2_name]) }
  let(:full_tool) {
    Toys::Tool.new([full_tool_name]).tap do |t|
      t.middleware_stack.concat(Toys::CLI.default_middleware_stack)
    end
  }
  let(:alias_tool) { Toys::Tool.new([tool_name, alias_name]) }
  let(:logger) {
    Logger.new(StringIO.new).tap do |lgr|
      lgr.level = Logger::WARN
    end
  }
  let(:context_base) { Toys::Context::Base.new(loader, binary_name, logger) }

  describe "name field" do
    it "works for a root tool" do
      assert_nil(root_tool.simple_name)
      assert_equal([], root_tool.full_name)
      assert_equal(true, root_tool.root?)
      assert_equal("", root_tool.display_name)
    end

    it "works for a toplevel tool" do
      assert_equal(tool_name, tool.simple_name)
      assert_equal([tool_name], tool.full_name)
      assert_equal(false, tool.root?)
      assert_equal(tool_name, tool.display_name)
    end

    it "works for a subtool" do
      assert_equal(subtool_name, subtool.simple_name)
      assert_equal([tool_name, subtool_name], subtool.full_name)
      assert_equal(false, subtool.root?)
      assert_equal("#{tool_name} #{subtool_name}", subtool.display_name)
    end
  end

  describe "description" do
    it "defaults to empty" do
      assert_equal(false, tool.includes_description?)
      assert_match(/^\(/, tool.effective_desc)
      assert_match(/^\(/, tool.effective_long_desc)
    end

    it "handles set of short description" do
      tool.desc = "hi"
      assert_equal(true, tool.includes_description?)
      assert_equal("hi", tool.effective_desc)
      assert_equal("hi", tool.effective_long_desc)
    end

    it "handles set of long description" do
      tool.long_desc = "ho"
      assert_equal(true, tool.includes_description?)
      assert_match(/^\(/, tool.effective_desc)
      assert_equal("ho", tool.effective_long_desc)
    end

    it "handles set of both descriptions" do
      tool.desc = "hi"
      tool.long_desc = "ho"
      assert_equal(true, tool.includes_description?)
      assert_equal("hi", tool.effective_desc)
      assert_equal("ho", tool.effective_long_desc)
    end
  end

  describe "definition path" do
    it "starts at nil" do
      assert_nil(tool.definition_path)
    end

    it "can be set" do
      tool.defining_from("path1") do
        tool.desc = "hi"
        tool.long_desc = "hiho"
      end
      assert_equal("path1", tool.definition_path)
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

    it "prevents nested defining paths" do
      tool.defining_from("path1") do
        assert_raises(Toys::ToolDefinitionError) do
          tool.defining_from("path2") do
          end
        end
      end
    end

    it "yields defining paths" do
      tool.defining_from("path1") do
        tool.yield_definition do
          tool.defining_from("path2") do
            tool.desc = "hi"
          end
        end
      end
      assert_equal("path1", tool.definition_path)
    end
  end

  describe "option parsing" do
    it "allows empty arguments when none are specified" do
      assert_equal(false, tool.includes_definition?)
      test = self
      tool.executor = proc do
        test.assert_equal({}, options)
      end
      assert_equal(0, tool.execute(context_base, []))
    end

    it "defaults simple boolean switch to nil" do
      test = self
      tool.add_switch(:a, "-a", "--aa", doc: "hi there")
      assert_equal(true, tool.includes_definition?)
      tool.executor = proc do
        test.assert_equal({a: nil}, options)
      end
      assert_equal(0, tool.execute(context_base, []))
    end

    it "sets simple boolean switch" do
      test = self
      tool.add_switch(:a, "-a", "--aa", doc: "hi there")
      tool.executor = proc do
        test.assert_equal({a: true}, options)
      end
      assert_equal(0, tool.execute(context_base, ["--aa"]))
    end

    it "defaults value switch to nil" do
      test = self
      tool.add_switch(:a, "-a", "--aa=VALUE", doc: "hi there")
      tool.executor = proc do
        test.assert_equal({a: nil}, options)
      end
      assert_equal(0, tool.execute(context_base, []))
    end

    it "honors given default of a value switch" do
      test = self
      tool.add_switch(:a, "-a", "--aa=VALUE", default: "hehe", doc: "hi there")
      tool.executor = proc do
        test.assert_equal({a: "hehe"}, options)
      end
      assert_equal(0, tool.execute(context_base, []))
    end

    it "sets value switch" do
      test = self
      tool.add_switch(:a, "-a", "--aa=VALUE", doc: "hi there")
      tool.executor = proc do
        test.assert_equal({a: "hoho"}, options)
      end
      assert_equal(0, tool.execute(context_base, ["--aa", "hoho"]))
    end

    it "converts a value switch" do
      test = self
      tool.add_switch(:a, "-a", "--aa=VALUE", accept: Integer, doc: "hi there")
      tool.executor = proc do
        test.assert_equal({a: 1234}, options)
      end
      assert_equal(0, tool.execute(context_base, ["--aa", "1234"]))
    end

    it "checks match of a value switch" do
      test = self
      tool.add_switch(:a, "-a", "--aa=VALUE", accept: Integer, doc: "hi there")
      tool.executor = proc do
        test.assert_match(/invalid argument: --aa a1234/, usage_error)
      end
      assert_equal(0, tool.execute(context_base, ["--aa", "a1234"]))
    end

    it "defaults the name of a value switch" do
      test = self
      tool.add_switch(:a_bc, doc: "hi there")
      tool.executor = proc do
        test.assert_equal({a_bc: "hoho"}, options)
      end
      assert_equal(0, tool.execute(context_base, ["--a-bc", "hoho"]))
    end

    it "errors on an unknown switch" do
      test = self
      tool.executor = proc do
        test.assert_match(/invalid option: -a/, usage_error)
      end
      assert_equal(0, tool.execute(context_base, ["-a"]))
    end
  end

  describe "used_switches" do
    it "starts empty" do
      assert_equal([], tool.used_switches)
    end

    it "handles switches" do
      tool.add_switch(:a, "-a", "--aa")
      assert_equal(["-a", "--aa"], tool.used_switches)
    end

    it "removes duplicate switches" do
      tool.add_switch(:a, "-a", "--aa")
      tool.add_switch(:b, "-b", "--aa")
      assert_equal(["-a", "--aa", "-b"], tool.used_switches)
    end

    it "handles special syntax" do
      tool.add_switch(:a, "--[no-]aa")
      tool.add_switch(:b, "-bVALUE", "--bb=VALUE")
      assert_equal(["--aa", "--no-aa", "-b", "--bb"], tool.used_switches)
    end
  end

  describe "argument parsing" do
    it "allows empty arguments when none are specified" do
      assert_equal(false, tool.includes_definition?)
      test = self
      tool.executor = proc do
        test.assert_equal([], args)
      end
      assert_equal(0, tool.execute(context_base, []))
    end

    it "recognizes args in order" do
      test = self
      tool.add_optional_arg(:b)
      assert_equal(true, tool.includes_definition?)
      tool.add_optional_arg(:c)
      tool.add_required_arg(:a, doc: "Hello")
      tool.set_remaining_args(:d)
      tool.executor = proc do
        test.assert_equal({a: "foo", b: "bar", c: "baz", d: ["hello", "world"]}, options)
      end
      assert_equal(0, tool.execute(context_base, ["foo", "bar", "baz", "hello", "world"]))
    end

    it "omits optional args if not provided" do
      test = self
      tool.add_optional_arg(:b)
      tool.add_optional_arg(:c)
      tool.add_required_arg(:a, doc: "Hello")
      tool.set_remaining_args(:d)
      tool.executor = proc do
        test.assert_equal({a: "foo", b: "bar", c: nil, d: []}, options)
      end
      assert_equal(0, tool.execute(context_base, ["foo", "bar"]))
    end

    it "errors if required args are missing" do
      test = self
      tool.add_required_arg(:a)
      tool.add_required_arg(:b)
      tool.executor = proc do
        test.assert_match(/No value given for required argument named <b>/, usage_error)
      end
      assert_equal(0, tool.execute(context_base, ["foo"]))
    end

    it "errors if there are too many arguments" do
      test = self
      tool.add_optional_arg(:b)
      tool.add_required_arg(:a)
      tool.executor = proc do
        test.assert_match(/Extra arguments provided: baz/, usage_error)
      end
      assert_equal(0, tool.execute(context_base, ["foo", "bar", "baz"]))
    end

    it "honors defaults for optional arg" do
      test = self
      tool.add_optional_arg(:b, default: "hello")
      tool.add_required_arg(:a)
      tool.executor = proc do
        test.assert_equal({a: "foo", b: "hello"}, options)
      end
      assert_equal(0, tool.execute(context_base, ["foo"]))
    end
  end

  describe "default component stack" do
    it "honors --verbose flag" do
      test = self
      full_tool.executor = proc do
        test.assert_equal(Logger::DEBUG, logger.level)
      end
      assert_equal(0, full_tool.execute(context_base, ["-v", "--verbose"]))
    end

    it "honors --quiet flag" do
      test = self
      full_tool.executor = proc do
        test.assert_equal(Logger::FATAL, logger.level)
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

  describe "helper method" do
    it "can be defined on a tool" do
      test = self
      tool.add_helper("hello_helper") { |val| val * 2 }
      tool.executor = proc do
        test.assert_equal(4, hello_helper(2))
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
      test = self
      tool.use_module(:file_utils)
      tool.executor = proc do
        test.assert_equal(true, private_methods.include?(:rm_rf))
      end
      assert_equal(0, tool.execute(context_base, []))
    end
  end

  describe "aliasing" do
    it "starts without" do
      assert_equal(false, alias_tool.alias?)
    end

    it "cannot be done on the root tool" do
      assert_raises(Toys::ToolDefinitionError) do
        root_tool.make_alias_of(tool_name)
      end
    end

    it "cannot be done if description has been set" do
      alias_tool.desc = "hi"
      assert_raises(Toys::ToolDefinitionError) do
        alias_tool.make_alias_of(subtool_name)
      end
    end

    it "cannot be done if definition has been set" do
      alias_tool.executor = proc {}
      assert_raises(Toys::ToolDefinitionError) do
        alias_tool.make_alias_of(subtool_name)
      end
    end

    it "can be set" do
      alias_tool.make_alias_of(subtool_name)
      assert_equal(true, alias_tool.alias?)
    end

    it "prevents setting of other fields" do
      alias_tool.make_alias_of(subtool_name)
      assert_raises(Toys::ToolDefinitionError) do
        alias_tool.desc = "hi"
      end
    end
  end

  describe "finish_definition" do
    it "runs middleware config" do
      assert_equal(true, full_tool.switches.empty?)
      full_tool.finish_definition
      assert_equal(false, full_tool.switches.empty?)
    end

    it "can be called multiple times" do
      full_tool.finish_definition
      full_tool.finish_definition
    end

    it "prevents further editing of description" do
      full_tool.finish_definition
      assert_raises(Toys::ToolDefinitionError) do
        full_tool.desc = "hi"
      end
    end
  end

  describe "execution" do
    it "handles no executor defined" do
      assert_equal(-1, tool.execute(context_base, []))
    end

    it "sets context fields" do
      test = self
      tool.add_optional_arg(:arg1)
      tool.add_optional_arg(:arg2)
      tool.add_switch(:sw1, "-a")
      tool.executor = proc do
        test.assert_equal(0, verbosity)
        test.assert_equal(test.tool, tool)
        test.assert_equal(test.tool.full_name, tool_name)
        test.assert_equal(test.loader, loader)
        test.assert_instance_of(Logger, logger)
        test.assert_equal("toys", binary_name)
        test.assert_equal(["hello", "-a"], args)
        test.assert_equal({arg1: "hello", arg2: nil, sw1: true}, options)
      end
      assert_equal(0, tool.execute(context_base, ["hello", "-a"]))
    end

    it "supports exit code" do
      tool.executor = proc do
        exit(2)
      end
      assert_equal(2, tool.execute(context_base, []))
    end

    it "supports sub-runs" do
      test = self
      subtool.add_optional_arg(:arg1)
      subtool.executor = proc do
        test.assert_equal("hi", self[:arg1])
        run(test.tool_name, test.subtool2_name, "ho", exit_on_nonzero_status: true)
      end
      subtool2.add_optional_arg(:arg2)
      subtool2.executor = proc do
        test.assert_equal("ho", self[:arg2])
        exit(3)
      end
      loader.put_tool!(subtool2)
      assert_equal(3, subtool.execute(context_base, ["hi"]))
    end

    it "supports aliases" do
      test = self
      subtool2.add_optional_arg(:arg2)
      subtool2.executor = proc do
        test.assert_equal("ho", self[:arg2])
        exit(3)
      end
      loader.put_tool!(subtool2)
      alias_tool.make_alias_of(subtool2_name)
      assert_equal(3, alias_tool.execute(context_base, ["ho"]))
    end
  end
end
