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
  let(:fake_loader) {
    obj = Object.new
    def obj.has_subtools?(_words)
      false
    end
    obj
  }
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
      t.middleware_stack.concat(Toys::Middleware.resolve_stack(Toys::CLI.default_middleware_stack))
    end
  }
  let(:alias_tool) { Toys::Tool.new([tool_name, alias_name]) }
  let(:logger) {
    Logger.new(StringIO.new).tap do |lgr|
      lgr.level = Logger::WARN
    end
  }
  let(:cli) { Toys::CLI.new(binary_name: binary_name, logger: logger) }
  def wrappable(str)
    Toys::Utils::WrappableString.new(str)
  end

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
      assert_equal(wrappable(""), tool.desc)
      assert_equal([], tool.long_desc)
    end

    it "handles short description with line breaks" do
      tool.desc = "hi\nthere"
      assert_equal(true, tool.includes_description?)
      assert_equal(wrappable("hi there"), tool.desc)
      assert_equal([], tool.long_desc)
    end

    it "handles single-line long description" do
      tool.long_desc = "ho"
      assert_equal(true, tool.includes_description?)
      assert_equal(wrappable(""), tool.desc)
      assert_equal([wrappable("ho")], tool.long_desc)
    end

    it "handles multi-line long description" do
      tool.long_desc = ["ho\nhum", "dee dum"]
      assert_equal(true, tool.includes_description?)
      assert_equal(wrappable(""), tool.desc)
      assert_equal([wrappable("ho hum"), wrappable("dee dum")], tool.long_desc)
    end
  end

  describe "flag definition" do
    it "starts empty" do
      assert(tool.flag_definitions.empty?)
    end

    describe "flag syntax checking" do
      it "allows legal flag syntax with raw booleans" do
        tool.add_flag(:foo, ["-a", "-?", "--d", "--e-f-g"])
      end

      it "allows legal flag syntax with required values" do
        tool.add_flag(:foo, ["-bVAL", "-c VAL", "--kl=VAL", "--mn VAL"])
      end

      it "allows legal flag syntax with optional values" do
        tool.add_flag(:foo, ["-b[VAL]", "-c [VAL]", "--kl=[VAL]", "--mn [VAL]"])
      end

      it "allows legal flag syntax with boolean switches" do
        tool.add_flag(:foo, ["-a", "--[no-]op"])
      end

      it "does not allow illegal flag syntax" do
        assert_raises(Toys::ToolDefinitionError) do
          tool.add_flag(:foo, ["hi"])
        end
        assert_raises(Toys::ToolDefinitionError) do
          tool.add_flag(:foo, [""])
        end
        assert_raises(Toys::ToolDefinitionError) do
          tool.add_flag(:foo, ["-a -"])
        end
      end
    end

    describe "options" do
      it "handles no explicit options" do
        tool.add_flag(:a, ["-a"])
        assert_equal(1, tool.flag_definitions.size)
        flag = tool.flag_definitions.first
        assert_equal(:a, flag.key)
        assert_equal(1, flag.flag_syntax.size)
        assert_equal(["-a"], flag.flag_syntax.first.flags)
        assert_nil(flag.accept)
        assert_equal("", flag.desc.to_s)
        assert_equal([], flag.long_desc)
        assert_equal(1, flag.handler.call(1, 2))
        assert_equal(true, flag.active?)
      end

      it "sets the default to nil by default" do
        tool.add_flag(:a, ["-a"])
        assert(tool.default_data.key?(:a))
        assert_nil(tool.default_data[:a])
      end

      it "sets a default to a custom value" do
        tool.add_flag(:a, ["-a"], default: 2)
        assert(tool.default_data.key?(:a))
        assert_equal(2, tool.default_data[:a])
      end

      it "recognizes desc and long desc" do
        tool.add_flag(:a, ["-a"], desc: "I like Ruby",
                                  long_desc: ["hello", "world"])
        flag = tool.flag_definitions.first
        assert_equal(wrappable("I like Ruby"), flag.desc)
        assert_equal([wrappable("hello"), wrappable("world")], flag.long_desc)
      end
    end

    describe "forcing values" do
      it "adds a value label by default when an acceptor is present" do
        tool.add_flag(:a, ["-a", "--bb"], accept: Integer)
        flag = tool.flag_definitions.first
        assert_equal("VALUE", flag.value_label)
        assert_equal(" ", flag.value_delim)
      end

      it "adds a value label by default when a nonboolean default is present" do
        tool.add_flag(:a, ["-a", "--bb"], default: "hi")
        flag = tool.flag_definitions.first
        assert_equal("VALUE", flag.value_label)
        assert_equal(" ", flag.value_delim)
      end

      it "does not add a value label by default when a boolean default is present" do
        tool.add_flag(:a, ["-a", "--bb"], default: true)
        flag = tool.flag_definitions.first
        assert_nil(flag.value_label)
      end
    end

    describe "default flag generation" do
      it "adds a default flag without an acceptor" do
        tool.add_flag(:abc)
        flag = tool.flag_definitions.first
        assert_equal(["--abc"], flag.optparser_info)
      end

      it "adds a default flag with an acceptor" do
        tool.add_flag(:abc, accept: String)
        flag = tool.flag_definitions.first
        assert_equal(["--abc VALUE", String], flag.optparser_info)
      end

      it "adds a default flag with a nonboolean default" do
        tool.add_flag(:abc, default: "hi")
        flag = tool.flag_definitions.first
        assert_equal(["--abc VALUE"], flag.optparser_info)
      end

      it "adds a default flag with a boolean default" do
        tool.add_flag(:abc, default: true)
        flag = tool.flag_definitions.first
        assert_equal(["--abc"], flag.optparser_info)
      end
    end

    describe "single vs double" do
      it "finds single and double flags with values" do
        tool.add_flag(:a, ["-a", "--bb", "-cVALUE", "--dd=VAL"])
        flag = tool.flag_definitions.first
        assert_equal(["-a", "-cVALUE"], flag.single_flag_syntax.map(&:original_str))
        assert_equal(["--bb", "--dd=VAL"], flag.double_flag_syntax.map(&:original_str))
      end

      it "finds single and double flags with booleans" do
        tool.add_flag(:a, ["-a", "--bb", "--[no-]ee"])
        flag = tool.flag_definitions.first
        assert_equal(["-a"], flag.single_flag_syntax.map(&:original_str))
        assert_equal(["--bb", "--[no-]ee"], flag.double_flag_syntax.map(&:original_str))
      end
    end

    describe "effective flags" do
      it "determines effective flags with values" do
        tool.add_flag(:a, ["-a", "--bb", "-cVALUE", "--dd=VAL"])
        flag = tool.flag_definitions.first
        assert_equal(["-a", "--bb", "-c", "--dd"], flag.effective_flags)
      end

      it "determines effective flags with booleans" do
        tool.add_flag(:a, ["-a", "--bb", "--[no-]ee"])
        flag = tool.flag_definitions.first
        assert_equal(["-a", "--bb", "--ee", "--no-ee"], flag.effective_flags)
      end
    end

    describe "uniquification" do
      it "uniquifies flags" do
        tool.add_flag(:a, ["-a VAL", "--bb=VALUE"])
        tool.add_flag(:b, ["-b VAL", "--bb=VALUE"], only_unique: true)
        tool.add_flag(:c, ["-a VAL"], only_unique: true)
        flag = tool.flag_definitions.last
        assert_equal(["-b"], flag.effective_flags)
        assert(flag.active?)
      end

      it "removes all flags" do
        tool.add_flag(:a, ["-a VAL", "--bb=VALUE"])
        tool.add_flag(:b, ["-a VAL", "--bb=VALUE"], only_unique: true)
        assert_equal(1, tool.flag_definitions.size)
      end
    end

    describe "flag types" do
      it "detects required value type" do
        tool.add_flag(:a, ["-a", "-cVALUE", "--bb"])
        flag = tool.flag_definitions.first
        assert_equal(:value, flag.flag_type)
        assert_equal(:required, flag.value_type)
      end

      it "detects optional value type" do
        tool.add_flag(:a, ["-a", "-c[VALUE]", "--bb"])
        flag = tool.flag_definitions.first
        assert_equal(:value, flag.flag_type)
        assert_equal(:optional, flag.value_type)
      end

      it "detects boolean switch type" do
        tool.add_flag(:a, ["-a", "--[no-]cc", "--bb"])
        flag = tool.flag_definitions.first
        assert_equal(:boolean, flag.flag_type)
        assert_nil(flag.value_type)
      end

      it "detects default boolean type" do
        tool.add_flag(:a, ["-a", "--bb"])
        flag = tool.flag_definitions.first
        assert_equal(:boolean, flag.flag_type)
        assert_nil(flag.value_type)
      end

      it "prevents incompatible flag types from coexisting" do
        assert_raises(Toys::ToolDefinitionError) do
          tool.add_flag(:a, ["--aa VALUE", "--[no-]cc"])
        end
        assert_raises(Toys::ToolDefinitionError) do
          tool.add_flag(:a, ["--aa [VALUE]", "--[no-]cc"])
        end
      end

      it "prevents incompatible value types from coexisting" do
        assert_raises(Toys::ToolDefinitionError) do
          tool.add_flag(:a, ["--aa VALUE", "--aa [VALUE]"])
        end
      end
    end

    describe "optparser canonicalization" do
      it "fills required value from single with empty delimiter" do
        tool.add_flag(:a, ["-a", "--bb", "-cVALUE"])
        flag = tool.flag_definitions.first
        assert_equal(["-aVALUE", "--bb=VALUE", "-cVALUE"], flag.optparser_info)
      end

      it "fills required value from single with space delimiter" do
        tool.add_flag(:a, ["-a", "--bb", "-c VALUE"])
        flag = tool.flag_definitions.first
        assert_equal(["-a VALUE", "--bb VALUE", "-c VALUE"], flag.optparser_info)
      end

      it "fills required value from double with space delimiter" do
        tool.add_flag(:a, ["-a", "--bb", "--cc VALUE"])
        flag = tool.flag_definitions.first
        assert_equal(["-a VALUE", "--bb VALUE", "--cc VALUE"], flag.optparser_info)
      end

      it "fills required value from double with equals delimiter" do
        tool.add_flag(:a, ["-a", "--bb", "--cc=VALUE"])
        flag = tool.flag_definitions.first
        assert_equal(["-aVALUE", "--bb=VALUE", "--cc=VALUE"], flag.optparser_info)
      end

      it "fills optional value from single with empty delimiter" do
        tool.add_flag(:a, ["-a", "--bb", "-c[VALUE]"])
        flag = tool.flag_definitions.first
        assert_equal(["-a[VALUE]", "--bb=[VALUE]", "-c[VALUE]"], flag.optparser_info)
      end

      it "fills optional value from single with space delimiter" do
        tool.add_flag(:a, ["-a", "--bb", "-c [VALUE]"])
        flag = tool.flag_definitions.first
        assert_equal(["-a [VALUE]", "--bb [VALUE]", "-c [VALUE]"], flag.optparser_info)
      end

      it "fills optional value from double with space delimiter" do
        tool.add_flag(:a, ["-a", "--bb", "--cc [VALUE]"])
        flag = tool.flag_definitions.first
        assert_equal(["-a [VALUE]", "--bb [VALUE]", "--cc [VALUE]"], flag.optparser_info)
      end

      it "fills optional value from double with equals delimiter" do
        tool.add_flag(:a, ["-a", "--bb", "--cc=[VALUE]"])
        flag = tool.flag_definitions.first
        assert_equal(["-a[VALUE]", "--bb=[VALUE]", "--cc=[VALUE]"], flag.optparser_info)
      end

      it "handles an acceptor" do
        tool.add_flag(:a, ["-a", "--bb", "-cVALUE"], accept: Integer)
        flag = tool.flag_definitions.first
        assert_equal(["-aVALUE", "--bb=VALUE", "-cVALUE", Integer], flag.optparser_info)
      end

      it "gets value label from last double flag" do
        tool.add_flag(:a, ["-a", "--bb", "-cVALUE", "--aa=VALU", "--dd=VAL"])
        flag = tool.flag_definitions.first
        assert_equal("VAL", flag.value_label)
        assert_equal("=", flag.value_delim)
      end

      it "gets value label from last single flag" do
        tool.add_flag(:a, ["-a VAL", "--bb", "-cVALUE", "--aa"])
        flag = tool.flag_definitions.first
        assert_equal("VALUE", flag.value_label)
        assert_equal("", flag.value_delim)
      end
    end
  end

  describe "used_flags" do
    it "starts empty" do
      assert_equal([], tool.used_flags)
    end

    it "handles flags" do
      tool.add_flag(:a, ["-a", "--aa"])
      assert_equal(["-a", "--aa"], tool.used_flags)
    end

    it "removes duplicate flags" do
      tool.add_flag(:a, ["-a", "--aa"])
      tool.add_flag(:b, ["-b", "--aa"])
      assert_equal(["-a", "--aa", "-b"], tool.used_flags)
    end

    it "handles special syntax" do
      tool.add_flag(:a, ["--[no-]aa"])
      tool.add_flag(:b, ["-bVALUE", "--bb=VALUE"])
      assert_equal(["--aa", "--no-aa", "-b", "--bb"], tool.used_flags)
    end
  end

  describe "option parsing" do
    it "allows empty arguments when none are specified" do
      assert_equal(false, tool.includes_definition?)
      test = self
      tool.script = proc do
        test.assert_equal({}, options)
      end
      assert_equal(0, tool.execute(cli, []))
    end

    it "defaults simple boolean flag to nil" do
      test = self
      tool.add_flag(:a, ["-a", "--aa"], desc: "hi there")
      assert_equal(true, tool.includes_definition?)
      tool.script = proc do
        test.assert_equal({a: nil}, options)
      end
      assert_equal(0, tool.execute(cli, []))
    end

    it "sets simple boolean flag" do
      test = self
      tool.add_flag(:a, ["-a", "--aa"], desc: "hi there")
      tool.script = proc do
        test.assert_equal({a: true}, options)
      end
      assert_equal(0, tool.execute(cli, ["--aa"]))
    end

    it "defaults value flag to nil" do
      test = self
      tool.add_flag(:a, ["-a", "--aa=VALUE"], desc: "hi there")
      tool.script = proc do
        test.assert_equal({a: nil}, options)
      end
      assert_equal(0, tool.execute(cli, []))
    end

    it "honors given default of a value flag" do
      test = self
      tool.add_flag(:a, ["-a", "--aa=VALUE"], default: "hehe", desc: "hi there")
      tool.script = proc do
        test.assert_equal({a: "hehe"}, options)
      end
      assert_equal(0, tool.execute(cli, []))
    end

    it "sets value flag" do
      test = self
      tool.add_flag(:a, ["-a", "--aa=VALUE"], desc: "hi there")
      tool.script = proc do
        test.assert_equal({a: "hoho"}, options)
      end
      assert_equal(0, tool.execute(cli, ["--aa", "hoho"]))
    end

    it "converts a value flag" do
      test = self
      tool.add_flag(:a, ["-a", "--aa=VALUE"], accept: Integer, desc: "hi there")
      tool.script = proc do
        test.assert_equal({a: 1234}, options)
      end
      assert_equal(0, tool.execute(cli, ["--aa", "1234"]))
    end

    it "checks match of a value flag" do
      test = self
      tool.add_flag(:a, ["-a", "--aa=VALUE"], accept: Integer, desc: "hi there")
      tool.script = proc do
        test.assert_match(/invalid argument: --aa a1234/, usage_error)
      end
      assert_equal(0, tool.execute(cli, ["--aa", "a1234"]))
    end

    it "converts a value flag using a custom acceptor" do
      test = self
      tool.add_acceptor("myenum", /foo|bar/)
      tool.add_flag(:a, ["-a", "--aa=VALUE"], accept: "myenum", desc: "hi there")
      tool.script = proc do
        test.assert_equal({a: "bar"}, options)
      end
      assert_equal(0, tool.execute(cli, ["--aa", "bar"]))
    end

    it "checks match of a value flag using a custom acceptor" do
      test = self
      tool.add_acceptor("myenum", /foo|bar/)
      tool.add_flag(:a, ["-a", "--aa=VALUE"], accept: "myenum", desc: "hi there")
      tool.script = proc do
        test.assert_match(/invalid argument: --aa 1234/, usage_error)
      end
      assert_equal(0, tool.execute(cli, ["--aa", "1234"]))
    end

    it "defaults the name of a value flag" do
      test = self
      tool.add_flag(:a_bc, accept: String, desc: "hi there")
      tool.script = proc do
        test.assert_equal({a_bc: "hoho"}, options)
      end
      assert_equal(0, tool.execute(cli, ["--a-bc", "hoho"]))
    end

    it "honors the handler" do
      test = self
      tool.add_flag(:a, ["-a", "--aa=VALUE"], default: "hi", handler: ->(v, c) { "#{c}#{v}" })
      tool.script = proc do
        test.assert_equal({a: "hiho"}, options)
      end
      assert_equal(0, tool.execute(cli, ["--aa", "ho"]))
    end

    it "errors on an unknown flag" do
      test = self
      tool.script = proc do
        test.assert_match(/invalid option: -a/, usage_error)
      end
      assert_equal(0, tool.execute(cli, ["-a"]))
    end
  end

  describe "argument parsing" do
    it "allows empty arguments when none are specified" do
      assert_equal(false, tool.includes_definition?)
      test = self
      tool.script = proc do
        test.assert_equal([], args)
      end
      assert_equal(0, tool.execute(cli, []))
    end

    it "recognizes args in order" do
      test = self
      tool.add_optional_arg(:b)
      assert_equal(true, tool.includes_definition?)
      tool.add_optional_arg(:c)
      tool.add_required_arg(:a, desc: "Hello")
      tool.set_remaining_args(:d)
      tool.script = proc do
        test.assert_equal({a: "foo", b: "bar", c: "baz", d: ["hello", "world"]}, options)
      end
      assert_equal(0, tool.execute(cli, ["foo", "bar", "baz", "hello", "world"]))
    end

    it "omits optional args if not provided" do
      test = self
      tool.add_optional_arg(:b)
      tool.add_optional_arg(:c)
      tool.add_required_arg(:a, desc: "Hello")
      tool.set_remaining_args(:d)
      tool.script = proc do
        test.assert_equal({a: "foo", b: "bar", c: nil, d: []}, options)
      end
      assert_equal(0, tool.execute(cli, ["foo", "bar"]))
    end

    it "errors if required args are missing" do
      test = self
      tool.add_required_arg(:a)
      tool.add_required_arg(:b)
      tool.script = proc do
        test.assert_match(/No value given for required argument B/, usage_error)
      end
      assert_equal(0, tool.execute(cli, ["foo"]))
    end

    it "errors if there are too many arguments" do
      test = self
      tool.add_optional_arg(:b)
      tool.add_required_arg(:a)
      tool.script = proc do
        test.assert_match(/Extra arguments provided: baz/, usage_error)
      end
      assert_equal(0, tool.execute(cli, ["foo", "bar", "baz"]))
    end

    it "honors defaults for optional arg" do
      test = self
      tool.add_optional_arg(:b, default: "hello")
      tool.add_required_arg(:a)
      tool.script = proc do
        test.assert_equal({a: "foo", b: "hello"}, options)
      end
      assert_equal(0, tool.execute(cli, ["foo"]))
    end
  end

  describe "definition path" do
    it "starts at nil" do
      assert_nil(tool.definition_path)
    end

    it "can be set" do
      tool.lock_definition_path("path1")
      assert_equal("path1", tool.definition_path)
    end

    it "can be set repeatedly to the same value" do
      tool.lock_definition_path("path1")
      tool.lock_definition_path("path1")
      assert_equal("path1", tool.definition_path)
    end

    it "prevents defining from multiple paths" do
      tool.lock_definition_path("path1")
      assert_raises(Toys::ToolDefinitionError) do
        tool.lock_definition_path("path2")
      end
    end
  end

  describe "helper method" do
    it "can be defined on a tool" do
      test = self
      tool.add_helper("hello_helper") { |val| val * 2 }
      tool.script = proc do
        test.assert_equal(4, hello_helper(2))
      end
      assert_equal(0, tool.execute(cli, []))
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
      tool.use_module(:fileutils)
      tool.script = proc do
        test.assert_equal(true, private_methods.include?(:rm_rf))
      end
      assert_equal(0, tool.execute(cli, []))
    end
  end

  describe "finish_definition" do
    it "runs middleware config" do
      assert_equal(true, full_tool.flag_definitions.empty?)
      full_tool.finish_definition(fake_loader)
      assert_equal(false, full_tool.flag_definitions.empty?)
    end

    it "can be called multiple times" do
      full_tool.finish_definition(fake_loader)
      full_tool.finish_definition(fake_loader)
    end

    it "prevents further editing of description" do
      full_tool.finish_definition(fake_loader)
      assert_raises(Toys::ToolDefinitionError) do
        full_tool.desc = "hi"
      end
    end
  end

  describe "execution" do
    it "handles no script defined" do
      assert_equal(-1, tool.execute(cli, []))
    end

    it "sets context fields" do
      test = self
      tool.add_optional_arg(:arg1)
      tool.add_optional_arg(:arg2)
      tool.add_flag(:sw1, ["-a"])
      tool.script = proc do
        test.assert_equal(0, verbosity)
        test.assert_equal(test.tool, tool)
        test.assert_equal(test.tool.full_name, tool_name)
        test.assert_instance_of(Logger, logger)
        test.assert_equal("toys", binary_name)
        test.assert_equal(["hello", "-a"], args)
        test.assert_equal({arg1: "hello", arg2: nil, sw1: true}, options)
      end
      assert_equal(0, tool.execute(cli, ["hello", "-a"]))
    end

    it "supports exit code" do
      tool.script = proc do
        exit(2)
      end
      assert_equal(2, tool.execute(cli, []))
    end

    it "supports sub-runs" do
      test = self
      subtool.add_optional_arg(:arg1)
      subtool.script = proc do
        test.assert_equal("hi", self[:arg1])
        run(test.tool_name, test.subtool2_name, "ho", exit_on_nonzero_status: true)
      end
      subtool2.add_optional_arg(:arg2)
      subtool2.script = proc do
        test.assert_equal("ho", self[:arg2])
        exit(3)
      end
      cli.loader.put_tool!(subtool2)
      assert_equal(3, subtool.execute(cli, ["hi"]))
    end
  end
end
