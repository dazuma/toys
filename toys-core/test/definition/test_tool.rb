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

module MyMixin
  def mixin1
    :mixin1
  end
end

module MyTemplate
  include Toys::Template
  to_expand do |t|
  end
end

describe Toys::Definition::Tool do
  let(:logger) {
    Logger.new(StringIO.new).tap do |lgr|
      lgr.level = Logger::WARN
    end
  }
  let(:binary_name) { "toys" }
  let(:cli) { Toys::CLI.new(binary_name: binary_name, logger: logger, middleware_stack: []) }
  let(:full_cli) { Toys::CLI.new(binary_name: binary_name, logger: logger) }
  let(:loader) { cli.loader }
  let(:full_loader) { full_cli.loader }
  let(:tool_name) { "foo" }
  let(:full_tool_name) { "fool" }
  let(:subtool_name) { "bar" }
  let(:subtool2_name) { "baz" }
  let(:alias_name) { "alz" }
  let(:root_tool) { loader.activate_tool_definition([], 0) }
  let(:tool) { loader.activate_tool_definition([tool_name], 0) }
  let(:subtool) { loader.activate_tool_definition([tool_name, subtool_name], 0) }
  let(:subtool2) { loader.activate_tool_definition([tool_name, subtool2_name], 0) }
  let(:full_tool) { full_loader.activate_tool_definition([full_tool_name], 0) }
  let(:alias_tool) { loader.activate_tool_definition([tool_name, alias_name], 0) }
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
      it "reports flag collisions" do
        tool.add_flag(:a, ["-a VAL", "--bb=VALUE"])
        assert_raises(Toys::ToolDefinitionError) do
          tool.add_flag(:b, ["-b", "--bb"])
        end
      end

      it "uniquifies flags" do
        tool.add_flag(:a, ["-a VAL", "--bb=VALUE"])
        tool.add_flag(:b, ["-b VAL", "--bb=VALUE"], report_collisions: false)
        tool.add_flag(:c, ["-a VAL"], report_collisions: false)
        flag = tool.flag_definitions.last
        assert_equal(["-b"], flag.effective_flags)
        assert(flag.active?)
      end

      it "disables flags" do
        tool.disable_flag("--bb")
        tool.add_flag(:b, ["-b VAL", "--bb=VALUE"], report_collisions: false)
        flag = tool.flag_definitions.last
        assert_equal(["-b"], flag.effective_flags)
        assert(flag.active?)
      end

      it "removes all flags" do
        tool.add_flag(:a, ["-a VAL", "--bb=VALUE"])
        tool.add_flag(:b, ["-a VAL", "--bb=VALUE"], report_collisions: false)
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

    it "allows disabling" do
      tool.add_flag(:a, ["-a", "--aa"])
      tool.disable_flag("-b", "--bb")
      assert_equal(["-a", "--aa", "-b", "--bb"], tool.used_flags)
    end

    it "removes duplicate flags" do
      tool.add_flag(:a, ["-a", "--aa"])
      tool.add_flag(:b, ["-b", "--aa"], report_collisions: false)
      assert_equal(["-a", "--aa", "-b"], tool.used_flags)
    end

    it "handles special syntax" do
      tool.add_flag(:a, ["--[no-]aa"])
      tool.add_flag(:b, ["-bVALUE", "--bb=VALUE"])
      assert_equal(["--aa", "--no-aa", "-b", "--bb"], tool.used_flags)
    end
  end

  describe "acceptor" do
    let(:acceptor_name) { "acc1" }
    let(:acceptor) { Toys::Definition::Acceptor.new(acceptor_name) }

    it "resolves well-known acceptors" do
      assert_equal(Integer, tool.resolve_acceptor(Integer))
    end

    it "resolves the nil acceptor" do
      assert_nil(tool.resolve_acceptor(nil))
    end

    it "can be added and resolved" do
      tool.add_acceptor(acceptor)
      assert_equal(acceptor, tool.resolve_acceptor(acceptor_name))
    end

    it "raises if not found" do
      assert_raises(Toys::ToolDefinitionError) do
        tool.resolve_acceptor("acc2")
      end
    end

    it "can be resolved in a subtool" do
      tool.add_acceptor(acceptor)
      assert_equal(acceptor, subtool.resolve_acceptor(acceptor_name))
    end

    it "can be referenced in a flag" do
      tool.add_acceptor(acceptor)
      tool.add_flag(:a, ["-a VAL"], accept: acceptor_name)
      assert_equal(acceptor, tool.flag_definitions.first.accept)
    end
  end

  describe "source info" do
    let(:source_path) { File.expand_path(__FILE__) }
    let(:source_path2) { File.expand_path(__dir__) }
    let(:source_info) { Toys::Definition::SourceInfo.create_path_root(source_path) }
    let(:source_info2) { Toys::Definition::SourceInfo.create_path_root(source_path2) }

    it "starts at nil" do
      assert_nil(tool.source_info)
    end

    it "can be set" do
      tool.lock_source(source_info)
      assert_equal(source_path, tool.source_info.source_path)
    end

    it "can be set repeatedly to the same value" do
      tool.lock_source(source_info)
      tool.lock_source(source_info)
      assert_equal(source_path, tool.source_info.source_path)
    end

    it "prevents defining from multiple paths" do
      tool.lock_source(source_info)
      assert_raises(Toys::ToolDefinitionError) do
        tool.lock_source(source_info2)
      end
    end
  end

  describe "mixin module" do
    it "can be looked up from standard mixins" do
      test = self
      tool.include_mixin(:fileutils)
      tool.runnable = proc do
        test.assert_equal(true, private_methods.include?(:rm_rf))
      end
      assert_equal(0, Toys::Runner.new(cli, tool).run([]))
    end

    it "defaults to nil if not set" do
      assert_nil(tool.resolve_mixin("mymixin"))
    end

    it "can be set and retrieved" do
      tool.add_mixin("mymixin", MyMixin)
      assert_equal(MyMixin, tool.resolve_mixin("mymixin"))
    end

    it "can be retrieved from a subtool" do
      tool.add_mixin("mymixin", MyMixin)
      assert_equal(MyMixin, subtool.resolve_mixin("mymixin"))
    end

    it "mixes into the executable tool" do
      test = self
      tool.add_mixin("mymixin", MyMixin)
      tool.include_mixin("mymixin")
      tool.runnable = proc do
        test.assert_equal(:mixin1, mixin1)
      end
      assert_equal(0, Toys::Runner.new(cli, tool).run([]))
    end
  end

  describe "template class" do
    it "defaults to nil if not set" do
      assert_nil(tool.resolve_template("mytemplate"))
    end

    it "can be set and retrieved" do
      tool.add_mixin("mytemplate", MyTemplate)
      assert_equal(MyTemplate, tool.resolve_mixin("mytemplate"))
    end

    it "can be retrieved from a subtool" do
      tool.add_mixin("mytemplate", MyTemplate)
      assert_equal(MyTemplate, subtool.resolve_mixin("mytemplate"))
    end
  end

  describe "finish_definition" do
    it "runs middleware config" do
      assert_equal(true, full_tool.flag_definitions.empty?)
      full_tool.finish_definition(full_loader)
      assert_equal(false, full_tool.flag_definitions.empty?)
    end

    it "can be called multiple times" do
      full_tool.finish_definition(full_loader)
      full_tool.finish_definition(full_loader)
    end

    it "prevents further editing of description" do
      full_tool.finish_definition(full_loader)
      assert_raises(Toys::ToolDefinitionError) do
        full_tool.desc = "hi"
      end
    end
  end

  describe "context directory" do
    let(:source_path) { File.expand_path(__FILE__) }
    let(:default_context_dir) { File.expand_path(__dir__) }
    let(:source_info) { Toys::Definition::SourceInfo.create_path_root(source_path) }

    it "defaults to nil" do
      assert_nil(tool.context_directory)
    end

    it "defaults to source info" do
      tool.lock_source(source_info)
      assert_equal(default_context_dir, tool.context_directory)
    end

    it "can be set" do
      tool.custom_context_directory = "hi/there"
      assert_equal("hi/there", tool.context_directory)
    end

    it "can be set in an ancestor tool" do
      tool.custom_context_directory = "hi/there"
      assert_equal("hi/there", subtool.context_directory)
    end
  end
end
