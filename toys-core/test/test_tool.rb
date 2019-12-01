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
require "optparse"

module MyMixin
  def mixin1
    :mixin1
  end
end

module MyTemplate
  include Toys::Template
  on_expand do |t|
  end
end

describe Toys::Tool do
  let(:logger) {
    Logger.new(StringIO.new).tap do |lgr|
      lgr.level = Logger::WARN
    end
  }
  let(:executable_name) { "toys" }
  let(:cli) {
    Toys::CLI.new(executable_name: executable_name, logger: logger, middleware_stack: [])
  }
  let(:full_cli) { Toys::CLI.new(executable_name: executable_name, logger: logger) }
  let(:loader) { cli.loader }
  let(:full_loader) { full_cli.loader }
  let(:tool_name) { "foo" }
  let(:tool2_name) { "boo" }
  let(:full_tool_name) { "fool" }
  let(:subtool_name) { "bar" }
  let(:subtool2_name) { "baz" }
  let(:root_tool) { loader.activate_tool([], 0) }
  let(:tool) { loader.activate_tool([tool_name], 0) }
  let(:tool2) { loader.activate_tool([tool2_name], 0) }
  let(:subtool) { loader.activate_tool([tool_name, subtool_name], 0) }
  let(:subtool2) { loader.activate_tool([tool_name, subtool2_name], 0) }
  let(:full_tool) { full_loader.activate_tool([full_tool_name], 0) }
  def wrappable(str)
    Toys::WrappableString.new(str)
  end

  describe "definition state" do
    it "begins without definition" do
      assert_equal(false, tool.includes_definition?)
    end

    it "is set when flags are present" do
      tool.add_flag(:a, ["-a", "--aa"], desc: "hi there")
      assert_equal(true, tool.includes_definition?)
    end
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
      assert(tool.flags.empty?)
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
        assert_equal(1, tool.flags.size)
        flag = tool.flags.first
        assert_equal(:a, flag.key)
        assert_equal(1, flag.flag_syntax.size)
        assert_equal(["-a"], flag.flag_syntax.first.flags)
        assert_equal(Toys::Acceptor::DEFAULT, flag.acceptor)
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
        flag = tool.flags.first
        assert_equal(wrappable("I like Ruby"), flag.desc)
        assert_equal([wrappable("hello"), wrappable("world")], flag.long_desc)
      end
    end

    describe "forcing values" do
      it "adds a value label by default when an acceptor is present" do
        tool.add_flag(:a, accept: Integer)
        flag = tool.flags.first
        assert_equal("VALUE", flag.value_label)
        assert_equal(" ", flag.value_delim)
      end

      it "adds a value label by default when a nonboolean default is present" do
        tool.add_flag(:a, default: "hi")
        flag = tool.flags.first
        assert_equal("VALUE", flag.value_label)
        assert_equal(" ", flag.value_delim)
      end

      it "does not add a value label by default when a boolean default is present" do
        tool.add_flag(:a, default: true)
        flag = tool.flags.first
        assert_nil(flag.value_label)
      end

      it "does not add a value label by default when explicit flags are present" do
        tool.add_flag(:a, ["-a", "--bb"], default: "hi")
        flag = tool.flags.first
        assert_nil(flag.value_label)
      end
    end

    describe "default flag generation" do
      it "adds a default flag without an acceptor" do
        tool.add_flag(:abc)
        flag = tool.flags.first
        assert_equal(["--abc"], flag.canonical_syntax_strings)
        assert_equal(Toys::Acceptor::DEFAULT, flag.acceptor)
      end

      it "adds a default flag with an acceptor" do
        tool.add_flag(:abc, accept: String)
        flag = tool.flags.first
        assert_equal(["--abc VALUE"], flag.canonical_syntax_strings)
        assert_equal(String, flag.acceptor.well_known_spec)
      end

      it "adds a default flag with a nonboolean default" do
        tool.add_flag(:abc, default: "hi")
        flag = tool.flags.first
        assert_equal(["--abc VALUE"], flag.canonical_syntax_strings)
      end

      it "adds a default flag with a boolean default" do
        tool.add_flag(:abc, default: true)
        flag = tool.flags.first
        assert_equal(["--abc"], flag.canonical_syntax_strings)
      end
    end

    describe "syntax styles" do
      it "finds short and long flags with values" do
        tool.add_flag(:a, ["-a", "--bb", "-cVALUE", "--dd=VAL"])
        flag = tool.flags.first
        assert_equal(["-a", "-cVALUE"], flag.short_flag_syntax.map(&:original_str))
        assert_equal(["--bb", "--dd=VAL"], flag.long_flag_syntax.map(&:original_str))
      end

      it "finds short and long flags with booleans" do
        tool.add_flag(:a, ["-a", "--bb", "--[no-]ee"])
        flag = tool.flags.first
        assert_equal(["-a"], flag.short_flag_syntax.map(&:original_str))
        assert_equal(["--bb", "--[no-]ee"], flag.long_flag_syntax.map(&:original_str))
      end
    end

    describe "effective flags" do
      it "determines effective flags with values" do
        tool.add_flag(:a, ["-a", "--bb", "-cVALUE", "--dd=VAL"])
        flag = tool.flags.first
        assert_equal(["-a", "--bb", "-c", "--dd"], flag.effective_flags)
      end

      it "determines effective flags with booleans" do
        tool.add_flag(:a, ["-a", "--bb", "--[no-]ee"])
        flag = tool.flags.first
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
        flag = tool.flags.last
        assert_equal(["-b"], flag.effective_flags)
        assert(flag.active?)
      end

      it "disables flags" do
        tool.disable_flag("--bb")
        tool.add_flag(:b, ["-b VAL", "--bb=VALUE"], report_collisions: false)
        flag = tool.flags.last
        assert_equal(["-b"], flag.effective_flags)
        assert(flag.active?)
      end

      it "removes all flags" do
        tool.add_flag(:a, ["-a VAL", "--bb=VALUE"])
        tool.add_flag(:b, ["-a VAL", "--bb=VALUE"], report_collisions: false)
        assert_equal(1, tool.flags.size)
      end
    end

    describe "flag types" do
      it "detects required value type" do
        tool.add_flag(:a, ["-a", "-cVALUE", "--bb"])
        flag = tool.flags.first
        assert_equal(:value, flag.flag_type)
        assert_equal(:required, flag.value_type)
      end

      it "detects optional value type" do
        tool.add_flag(:a, ["-a", "-c[VALUE]", "--bb"])
        flag = tool.flags.first
        assert_equal(:value, flag.flag_type)
        assert_equal(:optional, flag.value_type)
      end

      it "detects boolean switch type" do
        tool.add_flag(:a, ["-a", "--[no-]cc", "--bb"])
        flag = tool.flags.first
        assert_equal(:boolean, flag.flag_type)
        assert_nil(flag.value_type)
      end

      it "detects default boolean type" do
        tool.add_flag(:a, ["-a", "--bb"])
        flag = tool.flags.first
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

    describe "canonicalization" do
      it "fills required value from single with empty delimiter" do
        tool.add_flag(:a, ["-a", "--bb", "-cVALUE"])
        flag = tool.flags.first
        assert_equal(["-aVALUE", "--bb=VALUE", "-cVALUE"], flag.canonical_syntax_strings)
      end

      it "fills required value from single with space delimiter" do
        tool.add_flag(:a, ["-a", "--bb", "-c VALUE"])
        flag = tool.flags.first
        assert_equal(["-a VALUE", "--bb VALUE", "-c VALUE"], flag.canonical_syntax_strings)
      end

      it "fills required value from double with space delimiter" do
        tool.add_flag(:a, ["-a", "--bb", "--cc VALUE"])
        flag = tool.flags.first
        assert_equal(["-a VALUE", "--bb VALUE", "--cc VALUE"], flag.canonical_syntax_strings)
      end

      it "fills required value from double with equals delimiter" do
        tool.add_flag(:a, ["-a", "--bb", "--cc=VALUE"])
        flag = tool.flags.first
        assert_equal(["-aVALUE", "--bb=VALUE", "--cc=VALUE"], flag.canonical_syntax_strings)
      end

      it "fills optional value from single with empty delimiter" do
        tool.add_flag(:a, ["-a", "--bb", "-c[VALUE]"])
        flag = tool.flags.first
        assert_equal(["-a[VALUE]", "--bb=[VALUE]", "-c[VALUE]"], flag.canonical_syntax_strings)
      end

      it "fills optional value from single with space delimiter" do
        tool.add_flag(:a, ["-a", "--bb", "-c [VALUE]"])
        flag = tool.flags.first
        assert_equal(["-a [VALUE]", "--bb [VALUE]", "-c [VALUE]"], flag.canonical_syntax_strings)
      end

      it "fills optional value from double with space delimiter" do
        tool.add_flag(:a, ["-a", "--bb", "--cc [VALUE]"])
        flag = tool.flags.first
        assert_equal(["-a [VALUE]", "--bb [VALUE]", "--cc [VALUE]"], flag.canonical_syntax_strings)
      end

      it "fills optional value from double with equals delimiter" do
        tool.add_flag(:a, ["-a", "--bb", "--cc=[VALUE]"])
        flag = tool.flags.first
        assert_equal(["-a[VALUE]", "--bb=[VALUE]", "--cc=[VALUE]"], flag.canonical_syntax_strings)
      end

      it "handles an acceptor" do
        tool.add_flag(:a, ["-a", "--bb", "-cVALUE"], accept: Integer)
        flag = tool.flags.first
        assert_equal(["-aVALUE", "--bb=VALUE", "-cVALUE"], flag.canonical_syntax_strings)
        assert_equal(Integer, flag.acceptor.well_known_spec)
      end

      it "gets value label from first double flag" do
        tool.add_flag(:a, ["-a", "--dd=VAL", "-cVALUE", "--aa=VALU", "--bb"])
        flag = tool.flags.first
        assert_equal("VAL", flag.value_label)
        assert_equal("=", flag.value_delim)
      end

      it "gets value label from first single flag" do
        tool.add_flag(:a, ["-cVALUE", "--bb", "-a VAL", "--aa"])
        flag = tool.flags.first
        assert_equal("VALUE", flag.value_label)
        assert_equal("", flag.value_delim)
      end
    end

    describe "flag resolution" do
      it "finds a single flag" do
        tool.add_flag(:a, ["-a"])
        flag = tool.flags.first
        resolution = tool.resolve_flag("-a")
        assert_equal("-a", resolution.string)
        assert_equal(true, resolution.found_exact?)
        assert_equal(1, resolution.count)
        assert_equal(true, resolution.found_unique?)
        assert_equal(false, resolution.not_found?)
        assert_equal(false, resolution.found_multiple?)
        assert_equal(flag, resolution.unique_flag)
        assert_equal(flag.flag_syntax.first, resolution.unique_flag_syntax)
        assert_equal(false, resolution.unique_flag_negative?)
      end

      it "reports not found when no flags are present" do
        resolution = tool.resolve_flag("-b")
        assert_equal("-b", resolution.string)
        assert_equal(false, resolution.found_exact?)
        assert_equal(0, resolution.count)
        assert_equal(false, resolution.found_unique?)
        assert_equal(true, resolution.not_found?)
        assert_equal(false, resolution.found_multiple?)
        assert_nil(resolution.unique_flag)
        assert_nil(resolution.unique_flag_syntax)
        assert_nil(resolution.unique_flag_negative?)
      end

      it "reports ambiguous resolution across multiple flags" do
        tool.add_flag(:abc)
        tool.add_flag(:abd)
        resolution = tool.resolve_flag("--ab")
        assert_equal("--ab", resolution.string)
        assert_equal(false, resolution.found_exact?)
        assert_equal(2, resolution.count)
        assert_equal(false, resolution.found_unique?)
        assert_equal(false, resolution.not_found?)
        assert_equal(true, resolution.found_multiple?)
        assert_nil(resolution.unique_flag)
        assert_nil(resolution.unique_flag_syntax)
        assert_nil(resolution.unique_flag_negative?)
      end

      it "prefers exact matches over substrings when the exact match appears first" do
        tool.add_flag(:ab)
        tool.add_flag(:abc)
        resolution = tool.resolve_flag("--ab")
        assert_equal(true, resolution.found_exact?)
        assert_equal(tool.flags.first, resolution.unique_flag)
      end

      it "prefers exact matches over substrings when the exact match appears last" do
        tool.add_flag(:abc)
        tool.add_flag(:ab)
        resolution = tool.resolve_flag("--ab")
        assert_equal(true, resolution.found_exact?)
        assert_equal(tool.flags.last, resolution.unique_flag)
      end
    end
  end

  describe "flag groups" do
    it "has a default group" do
      assert_equal(1, tool.flag_groups.size)
      group = tool.flag_groups.first
      assert_nil(group.name)
      tool.add_flag(:a, ["-a"])
      flag = tool.flags.first
      assert_equal(group, flag.group)
      assert_equal([flag], group.flags)
    end

    it "appends a flag group" do
      tool.add_flag_group(type: :required)
      assert_equal(Toys::FlagGroup::Base, tool.flag_groups[0].class)
      assert_equal(Toys::FlagGroup::Required, tool.flag_groups[1].class)
    end

    it "prepends a flag group" do
      tool.add_flag_group(type: :required, prepend: true)
      assert_equal(Toys::FlagGroup::Required, tool.flag_groups[0].class)
      assert_equal(Toys::FlagGroup::Base, tool.flag_groups[1].class)
    end

    it "adds to a flag group by name" do
      tool.add_flag_group(type: :required, name: :mygroup)
      tool.add_flag(:a, ["-a"], group: :mygroup)
      flag = tool.flags.first
      assert_equal(:mygroup, flag.group.name)
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
    let(:acceptor) { Toys::Acceptor::Base.new }

    describe "add and lookup" do
      it "finds an acceptor by name" do
        tool.add_acceptor(acceptor_name, acceptor)
        assert_same(acceptor, tool.lookup_acceptor(acceptor_name))
      end

      it "returns nil on an unknown name" do
        assert_nil(tool.lookup_acceptor("acc2"))
      end

      it "does not do full resolution" do
        assert_nil(tool.lookup_acceptor(Integer))
      end

      it "finds an acceptor from a subtool" do
        tool.add_acceptor(acceptor_name, acceptor)
        assert_same(acceptor, subtool.lookup_acceptor(acceptor_name))
      end

      it "adds default" do
        tool.add_acceptor(acceptor_name, nil)
        assert_same(Toys::Acceptor::DEFAULT, tool.lookup_acceptor(acceptor_name))
      end

      it "adds enum" do
        tool.add_acceptor(acceptor_name, ["one", "two", "three"])
        assert_instance_of(Toys::Acceptor::Enum, tool.lookup_acceptor(acceptor_name))
      end

      it "adds enum with an option" do
        tool.add_acceptor(acceptor_name, ["one", "two", "three"], type_desc: "hi")
        found_acceptor = tool.lookup_acceptor(acceptor_name)
        assert_instance_of(Toys::Acceptor::Enum, found_acceptor)
        assert_equal("hi", found_acceptor.type_desc)
      end

      it "adds block" do
        tool.add_acceptor(acceptor_name) { |str| str }
        assert_instance_of(Toys::Acceptor::Simple, tool.lookup_acceptor(acceptor_name))
      end
    end

    describe "usage in flags and args" do
      it "resolves the default acceptor" do
        tool.add_flag(:a, ["-a VAL"])
        assert_equal(Toys::Acceptor::DEFAULT, tool.flags.first.acceptor)
      end

      it "resolves the default acceptor by passing :default" do
        tool.add_flag(:a, ["-a VAL"], accept: :default)
        assert_equal(Toys::Acceptor::DEFAULT, tool.flags.first.acceptor)
      end

      it "resolves well-known acceptors" do
        tool.add_flag(:a, ["-a VAL"], accept: Integer)
        assert_equal(Integer, tool.flags.first.acceptor.well_known_spec)
      end

      it "builds regex acceptors" do
        tool.add_flag(:a, ["-a VAL"], accept: /[A-Z]\w+/)
        assert_instance_of(Toys::Acceptor::Pattern, tool.flags.first.acceptor)
      end

      it "can be referenced by name in a flag" do
        tool.add_acceptor(acceptor_name, acceptor)
        tool.add_flag(:a, ["-a VAL"], accept: acceptor_name)
        assert_same(acceptor, tool.flags.first.acceptor)
      end

      it "can be referenced by name in a positional arg" do
        tool.add_acceptor(acceptor_name, acceptor)
        tool.add_required_arg(:a, accept: acceptor_name)
        assert_same(acceptor, tool.positional_args.first.acceptor)
      end

      it "can be referenced by name from a subtool" do
        tool.add_acceptor(acceptor_name, acceptor)
        subtool.add_flag(:a, ["-a VAL"], accept: acceptor_name)
        assert_same(acceptor, subtool.flags.first.acceptor)
      end

      it "can be added based on a spec" do
        tool.add_acceptor(acceptor_name, [:one, :two])
        tool.add_flag(:a, ["-a VAL"], accept: acceptor_name)
        assert_instance_of(Toys::Acceptor::Enum, tool.flags.first.acceptor)
      end

      it "raises if name not found" do
        assert_raises(Toys::ToolDefinitionError) do
          tool.add_flag(:a, ["-a VAL"], accept: "acc2")
        end
      end
    end
  end

  describe "completion" do
    let(:completion_name) { "comp1" }
    let(:completion_name2) { "comp2" }
    let(:completion) { Toys::Completion::Base.new }
    let(:completion2) { Toys::Completion::Base.new }

    describe "add and lookup" do
      it "finds a completion by name" do
        tool.add_completion(completion_name, completion)
        assert_same(completion, tool.lookup_completion(completion_name))
      end

      it "returns nil on an unknown name" do
        assert_nil(tool.lookup_completion(completion_name2))
      end

      it "does not do full resolution" do
        assert_nil(tool.lookup_completion(["one", "two"]))
      end

      it "finds an acceptor from a subtool" do
        tool.add_completion(completion_name, completion)
        assert_same(completion, subtool.lookup_completion(completion_name))
      end

      it "adds default" do
        tool.add_completion(completion_name, nil)
        assert_same(Toys::Completion::EMPTY, tool.lookup_completion(completion_name))
      end

      it "adds enum" do
        tool.add_completion(completion_name, ["one", "two", "three"])
        assert_instance_of(Toys::Completion::Enum, tool.lookup_completion(completion_name))
      end

      it "adds enum with an option" do
        tool.add_completion(completion_name, ["one", "two", "three"], prefix_constraint: "hi=")
        found_completion = tool.lookup_completion(completion_name)
        assert_instance_of(Toys::Completion::Enum, found_completion)
        assert_equal("hi=", found_completion.prefix_constraint)
      end

      it "adds block" do
        tool.add_completion(completion_name) { ["one", "two"] }
        assert_instance_of(Proc, tool.lookup_completion(completion_name))
      end
    end

    describe "usage in flags and args" do
      it "resolves the default completions" do
        tool.add_flag(:a, ["-a VAL"])
        assert_equal(Toys::Completion::EMPTY, tool.flags.first.value_completion)
        assert_instance_of(Toys::Flag::DefaultCompletion, tool.flags.first.flag_completion)
      end

      it "resolves the default completions by passing :default" do
        tool.add_flag(:a, ["-a VAL"], complete_flags: :default, complete_values: :default)
        assert_equal(Toys::Completion::EMPTY, tool.flags.first.value_completion)
        assert_instance_of(Toys::Flag::DefaultCompletion, tool.flags.first.flag_completion)
      end

      it "can be referenced by name in a flag" do
        tool.add_completion(completion_name, completion)
        tool.add_flag(:a, ["-a VAL"], complete_flags: completion, complete_values: completion2)
        assert_same(completion, tool.flags.first.flag_completion)
        assert_same(completion2, tool.flags.first.value_completion)
      end

      it "can be referenced by name in a positional arg" do
        tool.add_completion(completion_name, completion)
        tool.add_required_arg(:a, complete: completion)
        assert_same(completion, tool.positional_args.first.completion)
      end

      it "can be referenced by name from a subtool" do
        tool.add_completion(completion_name, completion)
        subtool.add_flag(:a, ["-a VAL"], complete_values: completion)
        assert_same(completion, subtool.flags.first.value_completion)
      end

      it "can be set based on a spec" do
        tool.add_flag(:a, ["-a VAL"],
                      complete_flags: ["three", "four"], complete_values: ["one", "two"])
        assert_instance_of(Toys::Completion::Enum, tool.flags.first.flag_completion)
        assert_equal("four", tool.flags.first.flag_completion.values.first.string)
        assert_instance_of(Toys::Completion::Enum, tool.flags.first.value_completion)
        assert_equal("one", tool.flags.first.value_completion.values.first.string)
      end

      it "can be set based on options" do
        tool.add_flag(:a, ["-a VAL"], complete_flags: {include_negative: false})
        assert_instance_of(Toys::Flag::DefaultCompletion, tool.flags.first.flag_completion)
        refute(tool.flags.first.flag_completion.include_negative?)
      end

      it "raises if name not found" do
        assert_raises(Toys::ToolDefinitionError) do
          tool.add_flag(:a, ["-a VAL"], complete_values: completion_name2)
        end
      end
    end
  end

  describe "source info" do
    let(:source_path) { File.expand_path(__FILE__) }
    let(:source_path2) { File.expand_path(__dir__) }
    let(:source_info) { Toys::SourceInfo.create_path_root(source_path) }
    let(:source_info2) { Toys::SourceInfo.create_path_root(source_path2) }

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
      tool.run_handler = proc do
        test.assert_equal(true, private_methods.include?(:rm_rf))
      end
      assert_equal(0, cli.run(tool_name))
    end

    it "defaults to nil if not set" do
      assert_nil(tool.lookup_mixin("mymixin"))
    end

    it "can be set and retrieved" do
      tool.add_mixin("mymixin", MyMixin)
      assert_equal(MyMixin, tool.lookup_mixin("mymixin"))
    end

    it "can be retrieved from a subtool" do
      tool.add_mixin("mymixin", MyMixin)
      assert_equal(MyMixin, subtool.lookup_mixin("mymixin"))
    end

    it "mixes into the executable tool" do
      test = self
      tool.add_mixin("mymixin", MyMixin)
      tool.include_mixin("mymixin")
      tool.run_handler = proc do
        test.assert_equal(:mixin1, mixin1)
      end
      assert_equal(0, cli.run(tool_name))
    end

    it "interprets add_mixin with a block" do
      test = self
      tool.add_mixin("mymixin") do
        def foo
          :bar
        end
      end
      tool.include_mixin("mymixin")
      tool.run_handler = proc do
        test.assert_equal(:bar, foo)
      end
      assert_equal(0, cli.run(tool_name))
    end
  end

  describe "template class" do
    it "defaults to nil if not set" do
      assert_nil(tool.lookup_template("mytemplate"))
    end

    it "can be set and retrieved" do
      tool.add_template("mytemplate", MyTemplate)
      assert_equal(MyTemplate, tool.lookup_template("mytemplate"))
    end

    it "can be retrieved from a subtool" do
      tool.add_template("mytemplate", MyTemplate)
      assert_equal(MyTemplate, subtool.lookup_template("mytemplate"))
    end

    it "interprets add_template with a block" do
      tool.add_template("mytemplate") do
        def initialize
          @foo = :bar
        end
        attr_reader :foo
      end
      assert_equal(:bar, tool.lookup_template("mytemplate").new.foo)
    end
  end

  describe "finish_definition" do
    it "runs middleware config" do
      assert_equal(true, full_tool.flags.empty?)
      full_tool.finish_definition(full_loader)
      assert_equal(false, full_tool.flags.empty?)
    end

    it "sorts flag groups" do
      full_tool.add_flag(:foo, ["--foo"])
      full_tool.add_flag(:bar, ["--bar"])
      full_tool.finish_definition(full_loader)
      assert_equal(:bar, full_tool.flag_groups.first.flags[0].key)
      assert_equal(:foo, full_tool.flag_groups.first.flags[1].key)
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
    let(:source_info) { Toys::SourceInfo.create_path_root(source_path) }

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

  describe "delegation" do
    it "disables argument parsing" do
      tool.delegate_to(["bar"])
      assert_equal(true, tool.argument_parsing_disabled?)
    end

    it "sets the description" do
      tool.delegate_to(["bar"])
      assert_equal('(Delegates to "bar")', tool.desc.to_s)
    end

    it "does not override an existing description" do
      tool.desc = "Existing description"
      tool.delegate_to(["bar"])
      assert_equal("Existing description", tool.desc.to_s)
    end

    it "errors if there is already an argument" do
      tool.add_required_arg(:foo)
      assert_raises(Toys::ToolDefinitionError) do
        tool.delegate_to(["bar"])
      end
    end

    it "errors if there is already a flag" do
      tool.add_flag(:foo)
      assert_raises(Toys::ToolDefinitionError) do
        tool.delegate_to(["bar"])
      end
    end

    it "errors if the tool is already runnable" do
      tool.run_handler = proc {}
      assert_raises(Toys::ToolDefinitionError) do
        tool.delegate_to(["bar"])
      end
    end

    it "executes the delegate" do
      subtool.run_handler = proc do
        exit(4)
      end
      tool.delegate_to([tool_name, subtool_name])
      assert_equal(4, cli.run(tool_name))
    end

    it "passes arguments to the delegate" do
      test = self
      subtool.add_flag(:foo, ["--foo=VAL"])
      subtool.run_handler = proc do
        test.assert_equal("hello", get(:foo))
        exit(4)
      end
      tool.delegate_to([tool_name, subtool_name])
      assert_equal(4, cli.run(tool_name, "--foo", "hello"))
    end

    it "delegates to a namespace" do
      subtool.run_handler = proc do
        exit(4)
      end
      tool2.delegate_to([tool_name])
      assert_equal(4, cli.run(tool2_name, subtool_name))
    end

    it "detects dangling references" do
      tool.delegate_to([tool2_name])
      _out, err = capture_subprocess_io do
        refute_equal(0, cli.run(tool_name))
      end
      assert_match(/Delegate target not found: "#{tool2_name}"/, err)
    end

    it "detects circular references" do
      tool.delegate_to([tool2_name])
      tool2.delegate_to([tool_name])
      _out, err = capture_subprocess_io do
        refute_equal(0, cli.run(tool_name))
      end
      assert_match(/Delegation loop: "#{tool_name}" <- "#{tool2_name}" <- "#{tool_name}"/, err)
    end
  end
end
