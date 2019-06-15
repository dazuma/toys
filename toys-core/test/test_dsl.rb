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

describe Toys::DSL::Tool do
  let(:logger) {
    Logger.new(StringIO.new).tap do |lgr|
      lgr.level = Logger::WARN
    end
  }
  let(:binary_name) { "toys" }
  let(:cli) { Toys::CLI.new(binary_name: binary_name, logger: logger, middleware_stack: []) }
  let(:loader) { cli.loader }

  describe "tool directive" do
    it "creates a tool" do
      loader.add_block do
        tool "foo" do
        end
      end
      tool, remaining = loader.lookup(["foo"])
      assert_equal(["foo"], tool.full_name)
      assert_equal([], remaining)
    end

    it "creates nested tools" do
      loader.add_block do
        tool "foo" do
          tool "bar" do
          end
        end
      end
      tool, remaining = loader.lookup(["foo", "bar", "baz"])
      assert_equal(["foo", "bar"], tool.full_name)
      assert_equal(["baz"], remaining)
    end

    it "supports arrays" do
      loader.add_block do
        tool ["foo", "bar"] do
        end
      end
      tool, remaining = loader.lookup(["foo", "bar", "baz"])
      assert_equal(["foo", "bar"], tool.full_name)
      assert_equal(["baz"], remaining)
    end

    it "combines tool information" do
      loader.add_block do
        tool "foo" do
          long_desc "hello", "world"
        end
        tool "foo" do
          long_desc "foo", "bar"
        end
      end
      tool, _remaining = loader.lookup(["foo"])
      ld = tool.long_desc
      assert_equal(4, ld.size)
      assert_equal("hello", ld[0].to_s)
      assert_equal("world", ld[1].to_s)
      assert_equal("foo", ld[2].to_s)
      assert_equal("bar", ld[3].to_s)
    end

    it "resets on redefinition" do
      loader.add_block do
        tool "foo" do
          long_desc "hello", "world"
        end
        tool "foo", if_defined: :reset do
          long_desc "foo", "bar"
        end
      end
      tool, _remaining = loader.lookup(["foo"])
      ld = tool.long_desc
      assert_equal(2, ld.size)
      assert_equal("foo", ld[0].to_s)
      assert_equal("bar", ld[1].to_s)
    end

    it "ignores on redefinition" do
      loader.add_block do
        tool "foo" do
          long_desc "hello", "world"
        end
        tool "foo", if_defined: :ignore do
          long_desc "foo", "bar"
        end
      end
      tool, _remaining = loader.lookup(["foo"])
      ld = tool.long_desc
      assert_equal(2, ld.size)
      assert_equal("hello", ld[0].to_s)
      assert_equal("world", ld[1].to_s)
    end
  end

  describe "method definition" do
    it "defaults a tool to not runnable" do
      loader.add_block do
        tool "foo" do
        end
      end
      tool, _remaining = loader.lookup(["foo"])
      assert_equal(false, tool.runnable?)
      assert_equal(false, tool.interruptible?)
    end

    it "makes a tool runnable when the run method is defined" do
      loader.add_block do
        tool "foo" do
          def run; end
        end
      end
      tool, _remaining = loader.lookup(["foo"])
      assert_equal(true, tool.runnable?)
    end

    it "allows other methods to be defined but not make the tool runnable" do
      loader.add_block do
        tool "foo" do
          def execute; end
        end
      end
      tool, _remaining = loader.lookup(["foo"])
      assert_equal(false, tool.runnable?)
    end

    it "makes a tool runnable when the to_run directive is given" do
      loader.add_block do
        tool "foo" do
          to_run do
          end
        end
      end
      tool, _remaining = loader.lookup(["foo"])
      assert_equal(true, tool.runnable?)
    end

    it "makes a tool interruptible when the interrupt method is defined" do
      loader.add_block do
        tool "foo" do
          def interrupt; end
        end
      end
      tool, _remaining = loader.lookup(["foo"])
      assert_equal(true, tool.interruptible?)
    end

    it "makes a tool interruptible when the to_interrupt directive is given" do
      loader.add_block do
        tool "foo" do
          to_interrupt do
          end
        end
      end
      tool, _remaining = loader.lookup(["foo"])
      assert_equal(true, tool.interruptible?)
    end

    it "makes callable methods" do
      loader.add_block do
        tool "foo" do
          def foo
            exit(2)
          end

          def run
            foo
          end
        end
      end
      assert_equal(2, cli.run(["foo"]))
    end
  end

  describe "completion directive" do
    it "creates an enum completion" do
      loader.add_block do
        completion("comp1", ["one", "two", "three"])
      end
      tool, _remaining = loader.lookup([])
      comp = tool.lookup_completion("comp1")
      assert_kind_of(Toys::Completion::Enum, comp)
    end

    it "creates an enum completion with options" do
      loader.add_block do
        completion("comp1", ["one", "two", "three"], prefix_constraint: /^hi=$/)
      end
      tool, _remaining = loader.lookup([])
      comp = tool.lookup_completion("comp1")
      assert_kind_of(Toys::Completion::Enum, comp)
      assert_equal(/^hi=$/, comp.prefix_constraint)
    end

    it "creates a file system completion" do
      loader.add_block do
        completion("comp1", :file_system)
      end
      tool, _remaining = loader.lookup([])
      comp = tool.lookup_completion("comp1")
      assert_kind_of(Toys::Completion::FileSystem, comp)
    end

    it "creates a file system completion with options" do
      loader.add_block do
        completion("comp1", :file_system, prefix_constraint: /^hi=$/)
      end
      tool, _remaining = loader.lookup([])
      comp = tool.lookup_completion("comp1")
      assert_kind_of(Toys::Completion::FileSystem, comp)
      assert_equal(/^hi=$/, comp.prefix_constraint)
    end

    it "creates a completion from a block" do
      loader.add_block do
        completion("comp1") do
          ["one", "two", "three"]
        end
      end
      tool, _remaining = loader.lookup([])
      comp = tool.lookup_completion("comp1")
      assert_equal(["one", "two", "three"], comp.call(:context))
    end

    it "can be looked up in a subtool" do
      loader.add_block do
        completion("comp1", :file_system)
        tool "foo" do
        end
      end
      tool, _remaining = loader.lookup(["foo"])
      comp = tool.lookup_completion("comp1")
      assert_kind_of(Toys::Completion::FileSystem, comp)
    end
  end

  describe "acceptor directive" do
    it "creates a pattern acceptor" do
      loader.add_block do
        acceptor("acc1", /^\d$/, &:to_i)
      end
      tool, _remaining = loader.lookup([])
      acc = tool.lookup_acceptor("acc1")
      assert_kind_of(Toys::Acceptor::Pattern, acc)
      assert_equal(3, acc.convert(*acc.match("3")))
    end

    it "creates an enum acceptor" do
      loader.add_block do
        acceptor("acc1", [1, 2, 3])
      end
      tool, _remaining = loader.lookup([])
      acc = tool.lookup_acceptor("acc1")
      assert_kind_of(Toys::Acceptor::Enum, acc)
      assert_equal(3, acc.convert(*acc.match("3")))
    end

    it "creates a simple acceptor from a block" do
      loader.add_block do
        acceptor("acc1", &:upcase)
      end
      tool, _remaining = loader.lookup([])
      acc = tool.lookup_acceptor("acc1")
      assert_kind_of(Toys::Acceptor::Simple, acc)
      assert_equal("HELLO", acc.convert(*acc.match("hello")))
    end

    it "can be looked up in a subtool" do
      loader.add_block do
        acceptor("acc1", &:upcase)
        tool "foo" do
        end
      end
      tool, _remaining = loader.lookup(["foo"])
      acc = tool.lookup_acceptor("acc1")
      assert_kind_of(Toys::Acceptor::Simple, acc)
    end

    it "works even when the hosting tool is not active" do
      loader.add_block do
        tool "host" do
          desc "the one"
        end
      end
      loader.add_block do
        tool "host" do
          desc "not the one"
          acceptor("acc1", &:upcase)
          tool "foo" do
          end
        end
      end
      host_tool, _remaining = loader.lookup(["host"])
      assert_equal("the one", host_tool.desc.to_s)
      foo_tool, _remaining = loader.lookup(["host", "foo"])
      acc = foo_tool.lookup_acceptor("acc1")
      assert_kind_of(Toys::Acceptor::Simple, acc)
    end
  end

  describe "include directive" do
    it "supports normal modules" do
      test = self
      loader.add_block do
        include ::FileUtils
        test.assert_equal(true, include?(::FileUtils))
      end
      tool, _remaining = loader.lookup([])
      assert_equal(true, tool.tool_class.include?(::FileUtils))
      assert_equal(false, tool.tool_class.include?(:fileutils))
    end

    it "supports builtin mixins" do
      loader.add_block do
        include :exec
      end
      tool, _remaining = loader.lookup([])
      assert_equal(true, tool.tool_class.include?(Toys::StandardMixins::Exec))
      assert_equal(true, tool.tool_class.include?(:exec))
    end

    it "does not allow multiple inclusion of the same module" do
      test = self
      loader.add_block do
        include :terminal, styled: true
        test.assert_raises(Toys::ToolDefinitionError) do
          include :terminal, styled: false
        end
        def run
          exit(1) if terminal.styled
          exit(2)
        end
      end
      tool, _remaining = loader.lookup([])
      assert_equal(true, tool.tool_class.include?(Toys::StandardMixins::Terminal))
      assert_equal(true, tool.tool_class.include?(:terminal))
      assert_equal(1, cli.run([]))
    end
  end

  describe "mixin directive" do
    it "creates a simple mixin" do
      loader.add_block do
        mixin("mixin1") do
          to_initialize do
            set(:foo, 1)
          end
          def foo
            :foo
          end
        end
        include "mixin1"
        def run
          exit(1) unless get(:foo) == 1
          exit(1) unless foo == :foo
          exit(2)
        end
      end
      tool, _remaining = loader.lookup([])
      mixin = tool.lookup_mixin("mixin1")
      assert_equal([Toys::Mixin], mixin.included_modules)
      assert_equal(true, mixin.public_method_defined?(:foo))
      assert_equal(2, cli.run([]))
    end

    it "can be looked up in a subtool" do
      loader.add_block do
        mixin("mixin1") do
          to_initialize do
            set(:foo, 1)
          end
          def foo
            :foo
          end
        end
        tool "foo" do
          tool "bar" do
            include "mixin1"
            def run
              exit(1) unless get(:foo) == 1
              exit(1) unless foo == :foo
              exit(2)
            end
          end
        end
      end
      tool, _remaining = loader.lookup(["foo", "bar"])
      mixin = tool.lookup_mixin("mixin1")
      assert_equal([Toys::Mixin], mixin.included_modules)
      assert_equal(2, cli.run(["foo", "bar"]))
    end

    it "cannot be looked up if defined in a different tool" do
      loader.add_block do
        tool "foo" do
          mixin("mixin1") do
            to_initialize do
              set(:foo, 1)
            end
            def foo
              :foo
            end
          end
        end
        tool "bar" do
        end
      end
      tool, _remaining = loader.lookup(["bar"])
      assert_nil(tool.lookup_mixin("mixin1"))
    end

    it "works even when the hosting tool is not active" do
      loader.add_block do
        tool "host" do
          desc "the one"
        end
      end
      loader.add_block do
        tool "host" do
          desc "not the one"
          mixin("mixin1") do
            to_initialize do
              set(:foo, 1)
            end
            def foo
              :foo
            end
          end
          tool "foo" do
            include "mixin1"
          end
        end
      end
      host_tool, _remaining = loader.lookup(["host"])
      assert_equal("the one", host_tool.desc.to_s)
      loader.lookup(["host", "foo"]) # Should allow mixin1
    end
  end

  describe "template directive" do
    it "creates a simple template" do
      loader.add_block do
        template("t1") do
          def initialize(name)
            @name = name
          end
          attr_reader :name
          expansion do |t|
            tool t.name do
              def run
                exit(2)
              end
            end
          end
        end
        expand("t1", "hi")
      end
      tool, _remaining = loader.lookup(["hi"])
      assert_equal(["hi"], tool.full_name)
      assert_equal(2, cli.run(["hi"]))
    end

    it "can be looked up in a subtool" do
      loader.add_block do
        template("t1") do
          def initialize(name)
            @name = name
          end
          attr_reader :name
          expansion do |t|
            tool t.name do
              def run
                exit(2)
              end
            end
          end
        end
        tool "foo" do
          expand("t1", "hi")
        end
      end
      tool, _remaining = loader.lookup(["foo", "hi"])
      assert_equal(["foo", "hi"], tool.full_name)
      assert_equal(2, cli.run(["foo", "hi"]))
    end

    it "works even when the hosting tool is not active" do
      loader.add_block do
        tool "host" do
          desc "the one"
        end
      end
      loader.add_block do
        tool "host" do
          desc "not the one"
          template("t1") do
            def initialize(name)
              @name = name
            end
            attr_reader :name
            expansion do |t|
              tool t.name do
                def run
                  exit(2)
                end
              end
            end
          end
          expand "t1", "subtool"
        end
      end
      host_tool, _remaining = loader.lookup(["host"])
      assert_equal("the one", host_tool.desc.to_s)
      tool, _remaining = loader.lookup(["host", "subtool"])
      assert_equal(["host", "subtool"], tool.full_name)
    end
  end

  describe "desc directive" do
    it "sets the desc" do
      loader.add_block do
        desc "this is a desc"
      end
      tool, _remaining = loader.lookup([])
      assert_equal("this is a desc", tool.desc.to_s)
    end
  end

  describe "long_desc directive" do
    it "sets the long desc" do
      loader.add_block do
        long_desc "this is a desc", "with multiple lines"
      end
      tool, _remaining = loader.lookup([])
      ld = tool.long_desc
      assert_equal(2, ld.size)
      assert_equal("this is a desc", ld[0].to_s)
      assert_equal("with multiple lines", ld[1].to_s)
    end

    it "appends to the long desc" do
      loader.add_block do
        long_desc "this is a desc", "with multiple lines"
        long_desc "and an append"
      end
      tool, _remaining = loader.lookup([])
      ld = tool.long_desc
      assert_equal(3, ld.size)
      assert_equal("this is a desc", ld[0].to_s)
      assert_equal("with multiple lines", ld[1].to_s)
      assert_equal("and an append", ld[2].to_s)
    end
  end

  describe "flag directive" do
    it "recognizes keyword arguments" do
      loader.add_block do
        flag(:foo, "--bar VALUE",
             accept: Integer,
             complete_values: ["1", "2", "3"],
             complete_flags: {include_negative: false},
             default: -1,
             handler: proc { |s| s.to_i - 1 },
             desc: "short description",
             long_desc: ["long description", "in two lines"])
      end
      tool, _remaining = loader.lookup([])
      assert_equal(1, tool.flags.size)
      flag = tool.flags[0]
      assert_equal(:foo, flag.key)
      assert_equal("--bar VALUE", flag.flag_syntax[0].canonical_str)
      assert_equal(Integer, flag.acceptor.well_known_spec)
      assert_instance_of(Toys::Completion::Enum, flag.value_completion)
      assert_equal(false, flag.flag_completion.include_negative?)
      assert_equal(-1, flag.default)
      assert_equal("short description", flag.desc.to_s)
      assert_equal("in two lines", flag.long_desc[1].to_s)
      assert_equal(3, flag.handler.call("4"))
      assert_equal(:value, flag.flag_type)
      assert_equal(:required, flag.value_type)
    end

    it "recognizes block configuration" do
      loader.add_block do
        flag(:foo) do
          flags "--bar VALUE"
          accept Integer
          complete_values ["1", "2", "3"], prefix_constraint: "hi="
          complete_flags include_negative: false
          default(-1)
          handler do |s|
            s.to_i - 1
          end
          desc "short description"
          long_desc "long description", "in two lines"
        end
      end
      tool, _remaining = loader.lookup([])
      assert_equal(1, tool.flags.size)
      flag = tool.flags[0]
      assert_equal(:foo, flag.key)
      assert_equal("--bar VALUE", flag.flag_syntax[0].canonical_str)
      assert_equal(Integer, flag.acceptor.well_known_spec)
      assert_instance_of(Toys::Completion::Enum, flag.value_completion)
      assert_equal("hi=", flag.value_completion.prefix_constraint)
      assert_equal(false, flag.flag_completion.include_negative?)
      assert_equal(-1, flag.default)
      assert_equal("short description", flag.desc.to_s)
      assert_equal("in two lines", flag.long_desc[1].to_s)
      assert_equal(3, flag.handler.call("4"))
      assert_equal(:value, flag.flag_type)
      assert_equal(:required, flag.value_type)
    end

    it "defines a getter for a valid symbol key" do
      loader.add_block do
        flag(:abc_2def?)
      end
      tool, _remaining = loader.lookup([])
      assert_equal(true, tool.tool_class.public_method_defined?(:abc_2def?))
      assert_equal(1, tool.tool_class.public_instance_methods(false).size)
    end

    it "defines a getter for another valid symbol key" do
      loader.add_block do
        flag(:_abc_2def!)
      end
      tool, _remaining = loader.lookup([])
      assert_equal(true, tool.tool_class.public_method_defined?(:_abc_2def!))
      assert_equal(1, tool.tool_class.public_instance_methods(false).size)
    end

    it "does not define a getter for a string key" do
      loader.add_block do
        flag("abc_def1?")
      end
      tool, _remaining = loader.lookup([])
      assert_equal(false, tool.tool_class.public_method_defined?(:abc_def1?))
      assert_equal(0, tool.tool_class.public_instance_methods(false).size)
    end

    it "does not define a getter for a symbol representing an invalid method name" do
      loader.add_block do
        flag(:"1abc")
      end
      tool, _remaining = loader.lookup([])
      assert_equal(false, tool.tool_class.public_method_defined?(:"1abc"))
      assert_equal(0, tool.tool_class.public_instance_methods(false).size)
    end
  end

  describe "flag_group directive" do
    it "recognizes keyword arguments" do
      loader.add_block do
        flag_group(type: :required, desc: "short description",
                   long_desc: ["long description", "in two lines"],
                   name: :my_group, report_collisions: false, prepend: true)
      end
      tool, _remaining = loader.lookup([])
      assert_equal(2, tool.flag_groups.size)
      assert_nil(tool.flag_groups.last.name)
      group = tool.flag_groups.first
      assert_equal(:my_group, group.name)
      assert_equal("short description", group.desc.to_s)
      assert_equal("in two lines", group.long_desc[1].to_s)
      assert_equal(Toys::FlagGroup::Required, group.class)
    end

    it "provides a block that defines flags" do
      loader.add_block do
        flag_group(name: :my_group) do
          flag(:inside_group)
        end
        flag(:outside_group)
      end
      tool, _remaining = loader.lookup([])
      assert_equal(2, tool.flag_groups.size)
      default_group, my_group = tool.flag_groups
      assert_equal(:my_group, my_group.name)
      assert_equal(1, my_group.flags.size)
      assert_equal(:inside_group, my_group.flags.first.key)
      assert_equal(1, default_group.flags.size)
      assert_equal(:outside_group, default_group.flags.first.key)
    end
  end

  describe "all_required directive" do
    it "recognizes keyword arguments" do
      loader.add_block do
        all_required(desc: "short description",
                     long_desc: ["long description", "in two lines"],
                     name: :my_group, report_collisions: false, prepend: true)
      end
      tool, _remaining = loader.lookup([])
      assert_equal(2, tool.flag_groups.size)
      assert_nil(tool.flag_groups.last.name)
      group = tool.flag_groups.first
      assert_equal(:my_group, group.name)
      assert_equal("short description", group.desc.to_s)
      assert_equal("in two lines", group.long_desc[1].to_s)
      assert_equal(Toys::FlagGroup::Required, group.class)
    end

    it "provides a block that defines flags" do
      loader.add_block do
        all_required(name: :my_group) do
          flag(:inside_group)
        end
        flag(:outside_group)
      end
      tool, _remaining = loader.lookup([])
      assert_equal(2, tool.flag_groups.size)
      default_group, my_group = tool.flag_groups
      assert_equal(:my_group, my_group.name)
      assert_equal(1, my_group.flags.size)
      assert_equal(:inside_group, my_group.flags.first.key)
      assert_equal(1, default_group.flags.size)
      assert_equal(:outside_group, default_group.flags.first.key)
    end
  end

  describe "at_most_one_required directive" do
    it "recognizes keyword arguments" do
      loader.add_block do
        at_most_one_required(desc: "short description",
                             long_desc: ["long description", "in two lines"],
                             name: :my_group, report_collisions: false, prepend: true)
      end
      tool, _remaining = loader.lookup([])
      assert_equal(2, tool.flag_groups.size)
      assert_nil(tool.flag_groups.last.name)
      group = tool.flag_groups.first
      assert_equal(:my_group, group.name)
      assert_equal("short description", group.desc.to_s)
      assert_equal("in two lines", group.long_desc[1].to_s)
      assert_equal(Toys::FlagGroup::AtMostOne, group.class)
    end

    it "provides a block that defines flags" do
      loader.add_block do
        at_most_one_required(name: :my_group) do
          flag(:inside_group)
        end
        flag(:outside_group)
      end
      tool, _remaining = loader.lookup([])
      assert_equal(2, tool.flag_groups.size)
      default_group, my_group = tool.flag_groups
      assert_equal(:my_group, my_group.name)
      assert_equal(1, my_group.flags.size)
      assert_equal(:inside_group, my_group.flags.first.key)
      assert_equal(1, default_group.flags.size)
      assert_equal(:outside_group, default_group.flags.first.key)
    end
  end

  describe "at_least_one_required directive" do
    it "recognizes keyword arguments" do
      loader.add_block do
        at_least_one_required(desc: "short description",
                              long_desc: ["long description", "in two lines"],
                              name: :my_group, report_collisions: false, prepend: true)
      end
      tool, _remaining = loader.lookup([])
      assert_equal(2, tool.flag_groups.size)
      assert_nil(tool.flag_groups.last.name)
      group = tool.flag_groups.first
      assert_equal(:my_group, group.name)
      assert_equal("short description", group.desc.to_s)
      assert_equal("in two lines", group.long_desc[1].to_s)
      assert_equal(Toys::FlagGroup::AtLeastOne, group.class)
    end

    it "provides a block that defines flags" do
      loader.add_block do
        at_least_one_required(name: :my_group) do
          flag(:inside_group)
        end
        flag(:outside_group)
      end
      tool, _remaining = loader.lookup([])
      assert_equal(2, tool.flag_groups.size)
      default_group, my_group = tool.flag_groups
      assert_equal(:my_group, my_group.name)
      assert_equal(1, my_group.flags.size)
      assert_equal(:inside_group, my_group.flags.first.key)
      assert_equal(1, default_group.flags.size)
      assert_equal(:outside_group, default_group.flags.first.key)
    end
  end

  describe "exactly_one_required directive" do
    it "recognizes keyword arguments" do
      loader.add_block do
        exactly_one_required(desc: "short description",
                             long_desc: ["long description", "in two lines"],
                             name: :my_group, report_collisions: false, prepend: true)
      end
      tool, _remaining = loader.lookup([])
      assert_equal(2, tool.flag_groups.size)
      assert_nil(tool.flag_groups.last.name)
      group = tool.flag_groups.first
      assert_equal(:my_group, group.name)
      assert_equal("short description", group.desc.to_s)
      assert_equal("in two lines", group.long_desc[1].to_s)
      assert_equal(Toys::FlagGroup::ExactlyOne, group.class)
    end

    it "provides a block that defines flags" do
      loader.add_block do
        exactly_one_required(name: :my_group) do
          flag(:inside_group)
        end
        flag(:outside_group)
      end
      tool, _remaining = loader.lookup([])
      assert_equal(2, tool.flag_groups.size)
      default_group, my_group = tool.flag_groups
      assert_equal(:my_group, my_group.name)
      assert_equal(1, my_group.flags.size)
      assert_equal(:inside_group, my_group.flags.first.key)
      assert_equal(1, default_group.flags.size)
      assert_equal(:outside_group, default_group.flags.first.key)
    end
  end

  describe "required_arg directive" do
    it "recognizes keyword arguments" do
      loader.add_block do
        required(:foo,
                 accept: Integer,
                 complete: ["1", "2", "3"],
                 display_name: "FOOOO",
                 desc: "short description",
                 long_desc: ["long description", "in two lines"])
      end
      tool, _remaining = loader.lookup([])
      assert_equal(1, tool.required_args.size)
      arg = tool.required_args[0]
      assert_equal(:foo, arg.key)
      assert_equal(:required, arg.type)
      assert_equal(Integer, arg.acceptor.well_known_spec)
      assert_instance_of(Toys::Completion::Enum, arg.completion)
      assert_equal("short description", arg.desc.to_s)
      assert_equal("in two lines", arg.long_desc[1].to_s)
      assert_equal("FOOOO", arg.display_name)
    end

    it "recognizes block configuration" do
      loader.add_block do
        required(:foo) do
          accept Integer
          complete ["1", "2", "3"], prefix_constraint: "hi="
          display_name "FOOOO"
          desc "short description"
          long_desc "long description", "in two lines"
        end
      end
      tool, _remaining = loader.lookup([])
      assert_equal(1, tool.required_args.size)
      arg = tool.required_args[0]
      assert_equal(:foo, arg.key)
      assert_equal(:required, arg.type)
      assert_equal(Integer, arg.acceptor.well_known_spec)
      assert_instance_of(Toys::Completion::Enum, arg.completion)
      assert_equal("hi=", arg.completion.prefix_constraint)
      assert_equal("short description", arg.desc.to_s)
      assert_equal("in two lines", arg.long_desc[1].to_s)
      assert_equal("FOOOO", arg.display_name)
    end

    it "defines a getter for a valid symbol key" do
      loader.add_block do
        required(:abc_2def?)
      end
      tool, _remaining = loader.lookup([])
      assert_equal(true, tool.tool_class.public_method_defined?(:abc_2def?))
      assert_equal(1, tool.tool_class.public_instance_methods(false).size)
    end

    it "defines a getter for another valid symbol key" do
      loader.add_block do
        required(:_abc_2def!)
      end
      tool, _remaining = loader.lookup([])
      assert_equal(true, tool.tool_class.public_method_defined?(:_abc_2def!))
      assert_equal(1, tool.tool_class.public_instance_methods(false).size)
    end

    it "does not define a getter for a string key" do
      loader.add_block do
        required("abc_def1?")
      end
      tool, _remaining = loader.lookup([])
      assert_equal(false, tool.tool_class.public_method_defined?(:abc_def1?))
      assert_equal(0, tool.tool_class.public_instance_methods(false).size)
    end

    it "does not define a getter for a symbol representing an invalid method name" do
      loader.add_block do
        required(:"1abc")
      end
      tool, _remaining = loader.lookup([])
      assert_equal(false, tool.tool_class.public_method_defined?(:"1abc"))
      assert_equal(0, tool.tool_class.public_instance_methods(false).size)
    end
  end

  describe "optional_arg directive" do
    it "recognizes keyword arguments" do
      loader.add_block do
        optional(:foo,
                 default: -1, accept: Integer,
                 display_name: "FOOOO",
                 desc: "short description",
                 long_desc: ["long description", "in two lines"])
      end
      tool, _remaining = loader.lookup([])
      assert_equal(1, tool.optional_args.size)
      arg = tool.optional_args[0]
      assert_equal(:foo, arg.key)
      assert_equal(:optional, arg.type)
      assert_equal(-1, arg.default)
      assert_equal(Integer, arg.acceptor.well_known_spec)
      assert_equal("short description", arg.desc.to_s)
      assert_equal("in two lines", arg.long_desc[1].to_s)
      assert_equal("FOOOO", arg.display_name)
    end

    it "recognizes block configuration" do
      loader.add_block do
        optional(:foo) do
          default(-1)
          accept Integer
          display_name "FOOOO"
          desc "short description"
          long_desc "long description", "in two lines"
        end
      end
      tool, _remaining = loader.lookup([])
      assert_equal(1, tool.optional_args.size)
      arg = tool.optional_args[0]
      assert_equal(:foo, arg.key)
      assert_equal(:optional, arg.type)
      assert_equal(-1, arg.default)
      assert_equal(Integer, arg.acceptor.well_known_spec)
      assert_equal("short description", arg.desc.to_s)
      assert_equal("in two lines", arg.long_desc[1].to_s)
      assert_equal("FOOOO", arg.display_name)
    end

    it "defines a getter for a valid symbol key" do
      loader.add_block do
        optional(:abc_2def?)
      end
      tool, _remaining = loader.lookup([])
      assert_equal(true, tool.tool_class.public_method_defined?(:abc_2def?))
      assert_equal(1, tool.tool_class.public_instance_methods(false).size)
    end

    it "defines a getter for another valid symbol key" do
      loader.add_block do
        optional(:_abc_2def!)
      end
      tool, _remaining = loader.lookup([])
      assert_equal(true, tool.tool_class.public_method_defined?(:_abc_2def!))
      assert_equal(1, tool.tool_class.public_instance_methods(false).size)
    end

    it "does not define a getter for a string key" do
      loader.add_block do
        optional("abc_def1?")
      end
      tool, _remaining = loader.lookup([])
      assert_equal(false, tool.tool_class.public_method_defined?(:abc_def1?))
      assert_equal(0, tool.tool_class.public_instance_methods(false).size)
    end

    it "does not define a getter for a symbol representing an invalid method name" do
      loader.add_block do
        optional(:"1abc")
      end
      tool, _remaining = loader.lookup([])
      assert_equal(false, tool.tool_class.public_method_defined?(:"1abc"))
      assert_equal(0, tool.tool_class.public_instance_methods(false).size)
    end
  end

  describe "remaining_args directive" do
    it "recognizes keyword arguments" do
      loader.add_block do
        remaining(:foo,
                  default: [-1], accept: Integer,
                  display_name: "FOOOO",
                  desc: "short description",
                  long_desc: ["long description", "in two lines"])
      end
      tool, _remaining = loader.lookup([])
      refute_nil(tool.remaining_arg)
      arg = tool.remaining_arg
      assert_equal(:foo, arg.key)
      assert_equal(:remaining, arg.type)
      assert_equal([-1], arg.default)
      assert_equal(Integer, arg.acceptor.well_known_spec)
      assert_equal("short description", arg.desc.to_s)
      assert_equal("in two lines", arg.long_desc[1].to_s)
      assert_equal("FOOOO", arg.display_name)
    end

    it "recognizes block configuration" do
      loader.add_block do
        remaining(:foo) do
          default([-1])
          accept Integer
          display_name "FOOOO"
          desc "short description"
          long_desc "long description", "in two lines"
        end
      end
      tool, _remaining = loader.lookup([])
      refute_nil(tool.remaining_arg)
      arg = tool.remaining_arg
      assert_equal(:foo, arg.key)
      assert_equal(:remaining, arg.type)
      assert_equal([-1], arg.default)
      assert_equal(Integer, arg.acceptor.well_known_spec)
      assert_equal("short description", arg.desc.to_s)
      assert_equal("in two lines", arg.long_desc[1].to_s)
      assert_equal("FOOOO", arg.display_name)
    end

    it "defines a getter for a valid symbol key" do
      loader.add_block do
        remaining(:abc_2def?)
      end
      tool, _remaining = loader.lookup([])
      assert_equal(true, tool.tool_class.public_method_defined?(:abc_2def?))
      assert_equal(1, tool.tool_class.public_instance_methods(false).size)
    end

    it "defines a getter for another valid symbol key" do
      loader.add_block do
        remaining(:_abc_2def!)
      end
      tool, _remaining = loader.lookup([])
      assert_equal(true, tool.tool_class.public_method_defined?(:_abc_2def!))
      assert_equal(1, tool.tool_class.public_instance_methods(false).size)
    end

    it "does not define a getter for a string key" do
      loader.add_block do
        remaining("abc_def1?")
      end
      tool, _remaining = loader.lookup([])
      assert_equal(false, tool.tool_class.public_method_defined?(:abc_def1?))
      assert_equal(0, tool.tool_class.public_instance_methods(false).size)
    end

    it "does not define a getter for a symbol representing an invalid method name" do
      loader.add_block do
        remaining(:"1abc")
      end
      tool, _remaining = loader.lookup([])
      assert_equal(false, tool.tool_class.public_method_defined?(:"1abc"))
      assert_equal(0, tool.tool_class.public_instance_methods(false).size)
    end
  end

  describe "static directive" do
    it "sets a single key" do
      loader.add_block do
        static(:foo, "bar")
      end
      tool, _remaining = loader.lookup([])
      assert_equal("bar", tool.default_data[:foo])
    end

    it "sets multiple keys" do
      loader.add_block do
        static(foo: "bar", hello: "world", one: 2)
      end
      tool, _remaining = loader.lookup([])
      assert_equal("bar", tool.default_data[:foo])
      assert_equal("world", tool.default_data[:hello])
      assert_equal(2, tool.default_data[:one])
    end

    it "defines a getter for a valid symbol key" do
      loader.add_block do
        static(:abc_2def?, "hi")
      end
      tool, _remaining = loader.lookup([])
      assert_equal(true, tool.tool_class.public_method_defined?(:abc_2def?))
      assert_equal(1, tool.tool_class.public_instance_methods(false).size)
    end

    it "defines a getter for another valid symbol key" do
      loader.add_block do
        static(:_abc_2def!, "hi")
      end
      tool, _remaining = loader.lookup([])
      assert_equal(true, tool.tool_class.public_method_defined?(:_abc_2def!))
      assert_equal(1, tool.tool_class.public_instance_methods(false).size)
    end

    it "does not define a getter for a string key" do
      loader.add_block do
        static("abc_def1?", "hi")
      end
      tool, _remaining = loader.lookup([])
      assert_equal(false, tool.tool_class.public_method_defined?(:abc_def1?))
      assert_equal(0, tool.tool_class.public_instance_methods(false).size)
    end

    it "does not define a getter for a symbol representing an invalid method name" do
      loader.add_block do
        static(:"1abc", "hi")
      end
      tool, _remaining = loader.lookup([])
      assert_equal(false, tool.tool_class.public_method_defined?(:"1abc"))
      assert_equal(0, tool.tool_class.public_instance_methods(false).size)
    end
  end

  describe "complete_tool_args directive" do
    it "sets a named completion" do
      loader.add_block do
        completion "mycomp", ["one", "two"]
        complete_tool_args "mycomp"
      end
      tool, _remaining = loader.lookup([])
      assert_instance_of(Toys::Completion::Enum, tool.completion)
    end

    it "sets a completion from an options hash" do
      loader.add_block do
        complete_tool_args include_hidden_subtools: true
      end
      tool, _remaining = loader.lookup([])
      assert(tool.completion.include_hidden_subtools?)
    end

    it "sets a completion from a standard spec" do
      loader.add_block do
        complete_tool_args ["one", "two"]
      end
      tool, _remaining = loader.lookup([])
      assert_instance_of(Toys::Completion::Enum, tool.completion)
    end
  end

  describe "disable_argument_parsing directive" do
    it "disables argument parsing" do
      loader.add_block do
        disable_argument_parsing
      end
      tool, _remaining = loader.lookup([])
      assert_equal(true, tool.argument_parsing_disabled?)
    end

    it "prevents invoking flag and arg directives" do
      test = self
      loader.add_block do
        disable_argument_parsing
        test.assert_raises(Toys::ToolDefinitionError) do
          flag :hello
        end
        test.assert_raises(Toys::ToolDefinitionError) do
          required_arg :hello
        end
        test.assert_raises(Toys::ToolDefinitionError) do
          optional_arg :hello
        end
        test.assert_raises(Toys::ToolDefinitionError) do
          remaining_args :hello
        end
      end
      loader.lookup([])
    end

    it "cannot be invoked if a flag already exists" do
      test = self
      loader.add_block do
        flag :hello
        test.assert_raises(Toys::ToolDefinitionError) do
          disable_argument_parsing
        end
      end
      loader.lookup([])
    end

    it "cannot be invoked if an arg already exists" do
      test = self
      loader.add_block do
        required_arg :hello
        test.assert_raises(Toys::ToolDefinitionError) do
          disable_argument_parsing
        end
      end
      loader.lookup([])
    end
  end

  describe "enforce_flags_before_args directive" do
    it "modifies the setting on the tool" do
      loader.add_block do
        enforce_flags_before_args
      end
      tool, _remaining = loader.lookup([])
      assert_equal(true, tool.flags_before_args_enforced?)
    end

    it "cannot be invoked if argument parsing is disabled" do
      test = self
      loader.add_block do
        disable_argument_parsing
        test.assert_raises(Toys::ToolDefinitionError) do
          enforce_flags_before_args
        end
      end
      loader.lookup([])
    end
  end

  describe "disable_flag directive" do
    it "adds a flag to the used list" do
      loader.add_block do
        disable_flag "-a", "--bb"
      end
      tool, _remaining = loader.lookup([])
      assert_equal(["-a", "--bb"], tool.used_flags)
    end

    it "prevents flags from being defined" do
      loader.add_block do
        disable_flag "-a", "--bb"
        flag :foo, "-a", report_collisions: false
        flag :bar, "--bb", "--baa", report_collisions: false
      end
      tool, _remaining = loader.lookup([])
      assert_equal(1, tool.flags.size)
      flag = tool.flags[0]
      assert_equal(1, flag.flag_syntax.size)
      assert_equal("--baa", flag.flag_syntax[0].canonical_str)
    end

    it "cannot disable already-defined flags" do
      test = self
      loader.add_block do
        flag :foo, "-a"
        flag :bar, "--bb", "--baa"
        test.assert_raises(Toys::ToolDefinitionError) do
          disable_flag "-a"
        end
        test.assert_raises(Toys::ToolDefinitionError) do
          disable_flag "--bb"
        end
      end
      tool, _remaining = loader.lookup([])
      assert_equal(2, tool.flags.size)
      flag = tool.flags[1]
      assert_equal(2, flag.flag_syntax.size)
    end
  end
end
