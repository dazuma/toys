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
  end

  describe "method definition" do
    it "defaults a tool to not runnable" do
      loader.add_block do
        tool "foo" do
        end
      end
      tool, _remaining = loader.lookup(["foo"])
      assert_equal(false, tool.runnable?)
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

  describe "acceptor directive" do
    it "creates a pattern acceptor" do
      loader.add_block do
        acceptor("acc1", /^\d$/, &:to_i)
      end
      tool, _remaining = loader.lookup([])
      acc = tool.resolve_acceptor("acc1")
      assert_kind_of(Toys::Definition::PatternAcceptor, acc)
      assert_equal(["3"], acc.match("3").to_a)
      assert_equal(3, acc.convert("3"))
    end

    it "creates an enum acceptor" do
      loader.add_block do
        acceptor("acc1", [1, 2, 3])
      end
      tool, _remaining = loader.lookup([])
      acc = tool.resolve_acceptor("acc1")
      assert_kind_of(Toys::Definition::EnumAcceptor, acc)
      assert_equal(["3", 3], acc.match("3").to_a)
      assert_equal(3, acc.convert("3", 3))
    end

    it "creates a base acceptor" do
      loader.add_block do
        acceptor("acc1", &:upcase)
      end
      tool, _remaining = loader.lookup([])
      acc = tool.resolve_acceptor("acc1")
      assert_kind_of(Toys::Definition::Acceptor, acc)
      assert_equal("hello", acc.match("hello"))
      assert_equal("HELLO", acc.convert("hello"))
    end

    it "can be looked up in a subtool" do
      loader.add_block do
        acceptor("acc1", &:upcase)
        tool "foo" do
        end
      end
      tool, _remaining = loader.lookup(["foo"])
      acc = tool.resolve_acceptor("acc1")
      assert_kind_of(Toys::Definition::Acceptor, acc)
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
      acc = foo_tool.resolve_acceptor("acc1")
      assert_kind_of(Toys::Definition::Acceptor, acc)
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
      mixin = tool.resolve_mixin("mixin1")
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
      mixin = tool.resolve_mixin("mixin1")
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
      assert_nil(tool.resolve_mixin("mixin1"))
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
          to_expand do |t|
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
          to_expand do |t|
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
            to_expand do |t|
              tool t.name do
                def run
                  exit(2)
                end
              end
            end
          end
          tool "foo" do
            expand "t1", "hi"
          end
        end
      end
      host_tool, _remaining = loader.lookup(["host"])
      assert_equal("the one", host_tool.desc.to_s)
      loader.lookup(["host", "foo"]) # Should allow mixin1
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
        flag(:foo, "--bar",
             accept: Integer, default: -1,
             handler: proc { |s| s.to_i - 1 },
             desc: "short description",
             long_desc: ["long description", "in two lines"])
      end
      tool, _remaining = loader.lookup([])
      assert_equal(1, tool.flag_definitions.size)
      flag = tool.flag_definitions[0]
      assert_equal(:foo, flag.key)
      assert_equal("--bar VALUE", flag.flag_syntax[0].canonical_str)
      assert_equal(Integer, flag.accept)
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
          flags "--bar"
          accept Integer
          default(-1)
          handler do |s|
            s.to_i - 1
          end
          desc "short description"
          long_desc "long description", "in two lines"
        end
      end
      tool, _remaining = loader.lookup([])
      assert_equal(1, tool.flag_definitions.size)
      flag = tool.flag_definitions[0]
      assert_equal(:foo, flag.key)
      assert_equal("--bar VALUE", flag.flag_syntax[0].canonical_str)
      assert_equal(Integer, flag.accept)
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

  describe "required_arg directive" do
    it "recognizes keyword arguments" do
      loader.add_block do
        required(:foo,
                 accept: Integer,
                 display_name: "FOOOO",
                 desc: "short description",
                 long_desc: ["long description", "in two lines"])
      end
      tool, _remaining = loader.lookup([])
      assert_equal(1, tool.required_arg_definitions.size)
      arg = tool.required_arg_definitions[0]
      assert_equal(:foo, arg.key)
      assert_equal(:required, arg.type)
      assert_equal(Integer, arg.accept)
      assert_equal("short description", arg.desc.to_s)
      assert_equal("in two lines", arg.long_desc[1].to_s)
      assert_equal("FOOOO", arg.display_name)
    end

    it "recognizes block configuration" do
      loader.add_block do
        required(:foo) do
          accept Integer
          display_name "FOOOO"
          desc "short description"
          long_desc "long description", "in two lines"
        end
      end
      tool, _remaining = loader.lookup([])
      assert_equal(1, tool.required_arg_definitions.size)
      arg = tool.required_arg_definitions[0]
      assert_equal(:foo, arg.key)
      assert_equal(:required, arg.type)
      assert_equal(Integer, arg.accept)
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
      assert_equal(1, tool.optional_arg_definitions.size)
      arg = tool.optional_arg_definitions[0]
      assert_equal(:foo, arg.key)
      assert_equal(:optional, arg.type)
      assert_equal(-1, arg.default)
      assert_equal(Integer, arg.accept)
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
      assert_equal(1, tool.optional_arg_definitions.size)
      arg = tool.optional_arg_definitions[0]
      assert_equal(:foo, arg.key)
      assert_equal(:optional, arg.type)
      assert_equal(-1, arg.default)
      assert_equal(Integer, arg.accept)
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
      refute_nil(tool.remaining_args_definition)
      arg = tool.remaining_args_definition
      assert_equal(:foo, arg.key)
      assert_equal(:remaining, arg.type)
      assert_equal([-1], arg.default)
      assert_equal(Integer, arg.accept)
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
      refute_nil(tool.remaining_args_definition)
      arg = tool.remaining_args_definition
      assert_equal(:foo, arg.key)
      assert_equal(:remaining, arg.type)
      assert_equal([-1], arg.default)
      assert_equal(Integer, arg.accept)
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
      assert_equal(1, tool.flag_definitions.size)
      flag = tool.flag_definitions[0]
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
      assert_equal(2, tool.flag_definitions.size)
      flag = tool.flag_definitions[1]
      assert_equal(2, flag.flag_syntax.size)
    end
  end
end
