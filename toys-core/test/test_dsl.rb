# frozen_string_literal: true

require "helper"
require "logger"
require "stringio"

describe Toys::DSL::Tool do
  let(:logger) {
    Logger.new(StringIO.new).tap do |lgr|
      lgr.level = Logger::WARN
    end
  }
  let(:executable_name) { "toys" }
  let(:extra_delimiters) { ":" }
  let(:cli) {
    Toys::CLI.new(executable_name: executable_name, logger: logger,
                  middleware_stack: [], extra_delimiters: extra_delimiters,
                  index_file_name: ".toys.rb", data_dir_name: ".data")
  }
  let(:loader) { cli.loader }
  let(:cases_dir) {
    File.join(__dir__, "lookup-cases")
  }

  describe "tool directive" do
    it "creates a tool" do
      loader.add_block do
        tool "foo" do
          # Empty tool
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
            # Empty tool
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
          # Empty tool
        end
      end
      tool, remaining = loader.lookup(["foo", "bar", "baz"])
      assert_equal(["foo", "bar"], tool.full_name)
      assert_equal(["baz"], remaining)
    end

    it "supports delimiters" do
      loader.add_block do
        tool "foo:bar" do
          # Empty tool
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

    it "recognizes delegate_to" do
      loader.add_block do
        tool "foo", delegate_to: "bar"
        tool "bar" do
          def run
            exit(3)
          end
        end
      end
      tool, _remaining = loader.lookup(["foo"])
      assert_equal(["bar"], tool.delegate_target)
      assert_equal(3, cli.run(["foo"]))
    end

    it "recognizes delegate_relative" do
      loader.add_block do
        tool "namespace" do
          tool "foo", delegate_relative: "bar"
          tool "bar" do
            def run
              exit(3)
            end
          end
        end
      end
      tool, _remaining = loader.lookup(["namespace", "foo"])
      assert_equal(["namespace", "bar"], tool.delegate_target)
      assert_equal(3, cli.run(["namespace", "foo"]))
    end

    it "allows delegate_to, delegate_relative, and a block together" do
      loader.add_block do
        tool "namespace" do
          tool "foo", delegate_relative: "bar", delegate_to: "namespace:bar" do
            desc "this is foo"
          end
          tool "bar" do
            def run
              exit(3)
            end
          end
        end
      end
      tool, _remaining = loader.lookup(["namespace", "foo"])
      assert_equal(["namespace", "bar"], tool.delegate_target)
      assert_equal("this is foo", tool.desc.to_s)
      assert_equal(3, cli.run(["namespace", "foo"]))
    end

    it "doesn't execute the block if not needed" do
      t = self
      loader.add_block do
        tool "foo" do
          long_desc "hello", "world"
        end
        tool "bar" do
          t.flunk
        end
      end
      tool, remaining = loader.lookup(["foo"])
      assert_equal(["foo"], tool.full_name)
      assert_equal([], remaining)
    end
  end

  describe "method definition" do
    it "defaults a tool to not runnable" do
      loader.add_block do
        tool "foo" do
          # Empty tool
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

    it "changes the run method name" do
      loader.add_block do
        tool "foo" do
          to_run :run2
          def run2; end
        end
      end
      tool, _remaining = loader.lookup(["foo"])
      assert_equal(true, tool.runnable?)
    end

    it "causes a tool to be non-runnable when to_run is set to nil" do
      loader.add_block do
        tool "foo" do
          to_run nil
          def run; end
        end
      end
      tool, _remaining = loader.lookup(["foo"])
      assert_equal(false, tool.runnable?)
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
            # Do nothing
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
          # Empty tool
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
          # Empty tool
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
            # Empty tool
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
      t = self
      loader.add_block do
        include ::FileUtils
        t.assert_equal(true, include?(::FileUtils))
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
      t = self
      loader.add_block do
        include :terminal, styled: true
        t.assert_raises(Toys::ToolDefinitionError) do
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
          on_initialize do
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
          on_initialize do
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
            on_initialize do
              set(:foo, 1)
            end
            def foo
              :foo
            end
          end
        end
        tool "bar" do
          # Empty tool
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
            on_initialize do
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
          on_expand do |t|
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
          on_expand do |t|
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
            on_expand do |t|
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

    it "reads from a file" do
      loader.add_path(File.join(cases_dir, "long-desc-files"))
      tool, _remaining = loader.lookup(["foo"])
      ld = tool.long_desc
      assert_equal(2, ld.size)
      assert_equal("This is a foo line.", ld[0].to_s)
      assert_equal("This is another foo line.", ld[1].to_s)
    end

    it "reads from data" do
      loader.add_path(File.join(cases_dir, "long-desc-files"))
      tool, _remaining = loader.lookup(["bar"])
      ld = tool.long_desc
      assert_equal(2, ld.size)
      assert_equal("This is a bar line.", ld[0].to_s)
      assert_equal(" This is another bar line.", ld[1].to_s)
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
          long_desc "and another line"
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
      assert_equal("and another line", flag.long_desc[2].to_s)
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
      context = tool.tool_class.new(abc_2def?: 10)
      assert_equal(10, context.abc_2def?)
    end

    it "does not define a getter if the name begins with underscore" do
      loader.add_block do
        flag(:_abc_2def!)
      end
      tool, _remaining = loader.lookup([])
      assert_equal(false, tool.tool_class.public_method_defined?(:_abc_2def!))
      assert_equal(0, tool.tool_class.public_instance_methods(false).size)
    end

    it "defines a getter for a single capital letter symbol key" do
      loader.add_block do
        flag(:A)
      end
      tool, _remaining = loader.lookup([])
      assert_equal(true, tool.tool_class.public_method_defined?(:A))
      assert_equal(1, tool.tool_class.public_instance_methods(false).size)
      context = tool.tool_class.new(A: 10)
      assert_equal(10, context.A())
    end

    it "defines a getter that overrides a method in Context" do
      loader.add_block do
        flag(:options)
      end
      tool, _remaining = loader.lookup([])
      assert_equal(true, tool.tool_class.public_method_defined?(:options))
      assert_equal(1, tool.tool_class.public_instance_methods(false).size)
      context = tool.tool_class.new(options: 10)
      assert_equal(10, context.options)
      assert_equal(10, context.__options[:options])
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

    it "does not define a getter if the name collides with an Object method" do
      loader.add_block do
        flag(:object_id)
      end
      tool, _remaining = loader.lookup([])
      assert_equal(true, tool.tool_class.public_method_defined?(:object_id))
      assert_equal(0, tool.tool_class.public_instance_methods(false).size)
    end

    it "does not define a getter for the run method" do
      loader.add_block do
        flag(:run)
      end
      tool, _remaining = loader.lookup([])
      assert_equal(false, tool.tool_class.public_method_defined?(:run))
      assert_equal(0, tool.tool_class.public_instance_methods(false).size)
    end

    it "does not define a getter for the initialize method" do
      loader.add_block do
        flag(:initialize)
      end
      tool, _remaining = loader.lookup([])
      assert_equal(false, tool.tool_class.public_method_defined?(:initialize))
      assert_equal(0, tool.tool_class.public_instance_methods(false).size)
    end

    it "does not define a getter if the method already exists" do
      loader.add_block do
        def hello
          20
        end
        flag(:hello)
      end
      tool, _remaining = loader.lookup([])
      context = tool.tool_class.new(hello: 10)
      assert_equal(20, context.hello)
    end

    it "does not define a getter if a private method already exists" do
      loader.add_block do
        def hello
          20
        end
        private :hello
        flag(:hello)
      end
      tool, _remaining = loader.lookup([])
      context = tool.tool_class.new(hello: 10)
      assert_equal(20, context.send(:hello))
    end

    it "forces defining a getter" do
      loader.add_block do
        flag(:object_id, add_method: true)
      end
      tool, _remaining = loader.lookup([])
      assert_equal(true, tool.tool_class.public_method_defined?(:object_id))
      assert_equal(1, tool.tool_class.public_instance_methods(false).size)
    end

    it "forces not defining a getter" do
      loader.add_block do
        flag(:abc_2def?, add_method: false)
      end
      tool, _remaining = loader.lookup([])
      assert_equal(false, tool.tool_class.public_method_defined?(:abc_2def?))
      assert_equal(0, tool.tool_class.public_instance_methods(false).size)
    end

    it "recognizes require_exact_flag_match" do
      loader.add_block do
        tool "foo" do
          require_exact_flag_match
        end
        tool "bar" do
          # Empty tool
        end
      end
      tool, _remaining = loader.lookup(["foo"])
      assert(tool.exact_flag_match_required?)
      tool, _remaining = loader.lookup(["bar"])
      refute(tool.exact_flag_match_required?)
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
          desc "short description"
          long_desc "long description", "in two lines"
          long_desc "and another line"
        end
        flag(:outside_group)
      end
      tool, _remaining = loader.lookup([])
      assert_equal(2, tool.flag_groups.size)
      default_group, my_group = tool.flag_groups
      assert_equal(:my_group, my_group.name)
      assert_equal("short description", my_group.desc.to_s)
      assert_equal("and another line", my_group.long_desc[2].to_s)
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
          desc "short description"
          long_desc "long description", "in two lines"
          long_desc "and another line"
          flag(:inside_group)
        end
        flag(:outside_group)
      end
      tool, _remaining = loader.lookup([])
      assert_equal(2, tool.flag_groups.size)
      default_group, my_group = tool.flag_groups
      assert_equal(:my_group, my_group.name)
      assert_equal("short description", my_group.desc.to_s)
      assert_equal("and another line", my_group.long_desc[2].to_s)
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
          long_desc "and another line"
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
      assert_equal("and another line", arg.long_desc[2].to_s)
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

    it "does not define a getter if the name begins with underscore" do
      loader.add_block do
        required(:_abc_2def!)
      end
      tool, _remaining = loader.lookup([])
      assert_equal(false, tool.tool_class.public_method_defined?(:_abc_2def!))
      assert_equal(0, tool.tool_class.public_instance_methods(false).size)
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

    it "forces defining a getter" do
      loader.add_block do
        required(:object_id, add_method: true)
      end
      tool, _remaining = loader.lookup([])
      assert_equal(true, tool.tool_class.public_method_defined?(:object_id))
      assert_equal(1, tool.tool_class.public_instance_methods(false).size)
    end

    it "forces not defining a getter" do
      loader.add_block do
        required(:abc_2def?, add_method: false)
      end
      tool, _remaining = loader.lookup([])
      assert_equal(false, tool.tool_class.public_method_defined?(:abc_2def?))
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

    it "does not define a getter if the name begins with underscore" do
      loader.add_block do
        optional(:_abc_2def!)
      end
      tool, _remaining = loader.lookup([])
      assert_equal(false, tool.tool_class.public_method_defined?(:_abc_2def!))
      assert_equal(0, tool.tool_class.public_instance_methods(false).size)
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

    it "forces defining a getter" do
      loader.add_block do
        optional(:object_id, add_method: true)
      end
      tool, _remaining = loader.lookup([])
      assert_equal(true, tool.tool_class.public_method_defined?(:object_id))
      assert_equal(1, tool.tool_class.public_instance_methods(false).size)
    end

    it "forces not defining a getter" do
      loader.add_block do
        optional(:abc_2def?, add_method: false)
      end
      tool, _remaining = loader.lookup([])
      assert_equal(false, tool.tool_class.public_method_defined?(:abc_2def?))
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

    it "does not define a getter if the name begins with underscore" do
      loader.add_block do
        remaining(:_abc_2def!)
      end
      tool, _remaining = loader.lookup([])
      assert_equal(false, tool.tool_class.public_method_defined?(:_abc_2def!))
      assert_equal(0, tool.tool_class.public_instance_methods(false).size)
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

    it "forces defining a getter" do
      loader.add_block do
        remaining(:object_id, add_method: true)
      end
      tool, _remaining = loader.lookup([])
      assert_equal(true, tool.tool_class.public_method_defined?(:object_id))
      assert_equal(1, tool.tool_class.public_instance_methods(false).size)
    end

    it "forces not defining a getter" do
      loader.add_block do
        remaining(:abc_2def?, add_method: false)
      end
      tool, _remaining = loader.lookup([])
      assert_equal(false, tool.tool_class.public_method_defined?(:abc_2def?))
      assert_equal(0, tool.tool_class.public_instance_methods(false).size)
    end
  end

  describe "set directive" do
    it "sets a single key" do
      loader.add_block do
        set(:foo, "bar")
      end
      tool, _remaining = loader.lookup([])
      assert_equal("bar", tool.default_data[:foo])
    end

    it "sets multiple keys" do
      loader.add_block do
        set(foo: "bar", hello: "world", one: 2)
      end
      tool, _remaining = loader.lookup([])
      assert_equal("bar", tool.default_data[:foo])
      assert_equal("world", tool.default_data[:hello])
      assert_equal(2, tool.default_data[:one])
    end

    it "does not define a getter for a valid symbol key" do
      loader.add_block do
        set(:hello, "hi")
      end
      tool, _remaining = loader.lookup([])
      assert_equal(false, tool.tool_class.public_method_defined?(:hello))
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

    it "defines a getter even if the key starts with an underscore" do
      loader.add_block do
        static(:_abc_2def!, "hi")
      end
      tool, _remaining = loader.lookup([])
      assert_equal(true, tool.tool_class.public_method_defined?(:_abc_2def!))
      assert_equal(1, tool.tool_class.public_instance_methods(false).size)
    end

    it "defines a getter even if the key collides with an Object method" do
      loader.add_block do
        static(:object_id, "hi")
      end
      tool, _remaining = loader.lookup([])
      assert_equal(true, tool.tool_class.public_method_defined?(:object_id))
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
      t = self
      loader.add_block do
        disable_argument_parsing
        t.assert_raises(Toys::ToolDefinitionError) do
          flag :hello
        end
        t.assert_raises(Toys::ToolDefinitionError) do
          required_arg :hello
        end
        t.assert_raises(Toys::ToolDefinitionError) do
          optional_arg :hello
        end
        t.assert_raises(Toys::ToolDefinitionError) do
          remaining_args :hello
        end
      end
      loader.lookup([])
    end

    it "cannot be invoked if a flag already exists" do
      t = self
      loader.add_block do
        flag :hello
        t.assert_raises(Toys::ToolDefinitionError) do
          disable_argument_parsing
        end
      end
      loader.lookup([])
    end

    it "cannot be invoked if an arg already exists" do
      t = self
      loader.add_block do
        required_arg :hello
        t.assert_raises(Toys::ToolDefinitionError) do
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
      t = self
      loader.add_block do
        disable_argument_parsing
        t.assert_raises(Toys::ToolDefinitionError) do
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
      t = self
      loader.add_block do
        flag :foo, "-a"
        flag :bar, "--bb", "--baa"
        t.assert_raises(Toys::ToolDefinitionError) do
          disable_flag "-a"
        end
        t.assert_raises(Toys::ToolDefinitionError) do
          disable_flag "--bb"
        end
      end
      tool, _remaining = loader.lookup([])
      assert_equal(2, tool.flags.size)
      flag = tool.flags[1]
      assert_equal(2, flag.flag_syntax.size)
    end
  end

  describe "delegate_to directive" do
    it "supports delimited string paths" do
      loader.add_block do
        tool "foo" do
          delegate_to "bar:baz"
        end
      end
      tool, _remaining = loader.lookup(["foo"])
      assert_equal(["bar", "baz"], tool.delegate_target)
    end

    it "supports array of strings paths" do
      loader.add_block do
        tool "foo" do
          delegate_to ["bar", "baz"]
        end
      end
      tool, _remaining = loader.lookup(["foo"])
      assert_equal(["bar", "baz"], tool.delegate_target)
    end

    it "supports simple symbols paths" do
      loader.add_block do
        tool :foo do
          delegate_to :bar
        end
      end
      tool, _remaining = loader.lookup(["foo"])
      assert_equal(["bar"], tool.delegate_target)
    end

    it "supports complex symbols paths" do
      loader.add_block do
        tool :foo do
          delegate_to :'bar:baz'
        end
      end
      tool, _remaining = loader.lookup(["foo"])
      assert_equal(["bar", "baz"], tool.delegate_target)
    end

    describe "without `extra_delimiters`" do
      let(:extra_delimiters) { "" }

      it "supports simple symbols paths" do
        loader.add_block do
          tool :foo do
            delegate_to :bar
          end
        end
        tool, _remaining = loader.lookup(["foo"])
        assert_equal(["bar"], tool.delegate_target)
      end
    end

    it "supports array of symbols paths" do
      loader.add_block do
        tool "foo" do
          delegate_to [:bar, :baz]
        end
      end
      tool, _remaining = loader.lookup(["foo"])
      assert_equal(["bar", "baz"], tool.delegate_target)
    end

    it "executes the delegate" do
      loader.add_block do
        tool "foo" do
          delegate_to "bar"
        end
        tool "bar" do
          def run
            exit(3)
          end
        end
      end
      assert_equal(3, cli.run(["foo"]))
    end
  end

  describe "alias_tool directive" do
    it "delegates using a relative path" do
      loader.add_block do
        tool "foo" do
          tool "bar" do
            def run
              exit(3)
            end
          end
          alias_tool "baz", "bar"
        end
      end
      assert_equal(3, cli.run(["foo", "baz"]))
    end

    it "delegates using a symbol" do
      loader.add_block do
        tool :foo do
          tool :bar do
            def run
              exit(3)
            end
          end
          alias_tool :baz, :bar
        end
      end
      assert_equal(3, cli.run(["foo", "baz"]))
    end
  end

  describe "subtool_apply directive" do
    it "applies to subtools" do
      loader.add_block do
        tool "foo" do
          subtool_apply do
            desc "hello"
          end
          tool "bar" do
            # Empty tool
          end
          tool "baz" do
            desc "ahoy"
          end
        end
      end
      tool, _remaining = loader.lookup(["foo", "bar"])
      assert_equal("hello", tool.desc.to_s)
      tool, _remaining = loader.lookup(["foo", "baz"])
      assert_equal("hello", tool.desc.to_s)
    end

    it "does not affect the current tool" do
      loader.add_block do
        tool "foo" do
          subtool_apply do
            desc "hello"
          end
        end
      end
      tool, _remaining = loader.lookup(["foo"])
      assert_equal("", tool.desc.to_s)
    end

    it "sets the source info within the block" do
      t = self
      loader.add_block do
        tool "foo" do
          parent_source = source_info
          subtool_apply do
            t.assert_equal(:proc, source_info.source_type)
            t.assert_same(parent_source, source_info.parent)
          end
          tool "bar" do
            # Empty tool
          end
        end
      end
      loader.lookup(["foo", "bar"])
    end
  end

  describe "truncate_load_path! directive" do
    it "removes lower-priority load paths" do
      t = self
      loader.add_block do
        truncate_load_path!
      end
      loader.add_block do
        t.flunk("Search was not stopped!")
      end

      loader.lookup(["tool-1"])
    end

    it "fails if a lower-priority tool is already loaded" do
      loader.add_block do
        tool "tool-2" do
          truncate_load_path!
        end
      end
      loader.add_block do
        tool "tool-1" do
          desc "hello"
        end
      end

      loader.lookup(["tool-1"])
      assert_raises("Cannot truncate load path because tools have already been loaded") do
        loader.lookup(["tool-2"])
      end
    end
  end

  describe "load directive" do
    let(:config_items_dir) { File.join(cases_dir, "config-items") }

    it "loads a file into the current namespace" do
      file_to_load = File.join(config_items_dir, ".toys.rb")
      loader.add_block do
        tool "ns-1" do
          load(file_to_load)
        end
      end
      tool, remaining = loader.lookup(["ns-1", "tool-1", "hello"])
      assert_equal("file tool-1 short description", tool.desc.to_s)
      assert_equal(["hello"], remaining)
    end

    it "loads a directory into the current namespace" do
      dir_to_load = File.join(config_items_dir, ".toys")
      loader.add_block do
        tool "ns-1" do
          load(dir_to_load)
        end
      end
      tool, remaining = loader.lookup(["ns-1", "tool-2", "hello"])
      assert_equal("directory tool-2 short description", tool.desc.to_s)
      assert_equal(["hello"], remaining)
    end

    it "loads a file as a name" do
      file_to_load = File.join(config_items_dir, ".toys.rb")
      loader.add_block do
        load(file_to_load, as: "ns1 ns2")
      end
      tool, remaining = loader.lookup(["ns1", "ns2", "tool-1", "hello"])
      assert_equal("file tool-1 short description", tool.desc.to_s)
      assert_equal(["hello"], remaining)
    end

    it "loads a directory as a name" do
      dir_to_load = File.join(config_items_dir, ".toys")
      loader.add_block do
        load(dir_to_load, as: "ns1 ns2")
      end
      tool, remaining = loader.lookup(["ns1", "ns2", "tool-2", "hello"])
      assert_equal("directory tool-2 short description", tool.desc.to_s)
      assert_equal(["hello"], remaining)
    end
  end

  describe "load_git directive" do
    before do
      skip unless ENV["TOYS_TEST_INTEGRATION"]
    end

    let(:git_remote) { "https://github.com/dazuma/toys.git" }
    let(:git_file_path) { "toys-core/test/lookup-cases/config-items/.toys.rb" }
    let(:git_dir_path) { "toys-core/test/lookup-cases/config-items/.toys" }

    it "loads a file into the current namespace" do
      remote = git_remote
      path = git_file_path
      loader.add_block do
        tool "ns-1" do
          load_git(remote: remote, path: path, update: true)
        end
      end
      tool, remaining = loader.lookup(["ns-1", "tool-1", "hello"])
      assert_equal("file tool-1 short description", tool.desc.to_s)
      assert_equal(["hello"], remaining)
    end

    it "loads a directory into the current namespace" do
      remote = git_remote
      path = git_dir_path
      loader.add_block do
        tool "ns-1" do
          load_git(remote: remote, path: path, update: true)
        end
      end
      tool, remaining = loader.lookup(["ns-1", "tool-2", "hello"])
      assert_equal("directory tool-2 short description", tool.desc.to_s)
      assert_equal(["hello"], remaining)
    end

    it "loads a file as a name" do
      remote = git_remote
      path = git_file_path
      loader.add_block do
        load_git(remote: remote, path: path, update: true, as: "ns1 ns2")
      end
      tool, remaining = loader.lookup(["ns1", "ns2", "tool-1", "hello"])
      assert_equal("file tool-1 short description", tool.desc.to_s)
      assert_equal(["hello"], remaining)
    end

    it "loads a directory as a name" do
      remote = git_remote
      path = git_dir_path
      loader.add_block do
        load_git(remote: remote, path: path, update: true, as: "ns1 ns2")
      end
      tool, remaining = loader.lookup(["ns1", "ns2", "tool-2", "hello"])
      assert_equal("directory tool-2 short description", tool.desc.to_s)
      assert_equal(["hello"], remaining)
    end
  end

  describe "settings directive" do
    it "returns the settings" do
      t = self
      loader.add_block do
        t.assert_equal(false, settings.propagate_helper_methods)
        settings.propagate_helper_methods = true
        t.assert_equal(true, settings.propagate_helper_methods)
      end
      loader.lookup(["blah"])
    end

    it "inherits settings of parent tool" do
      t = self
      loader.add_block do
        settings.propagate_helper_methods = true
        tool "tool-1" do
          t.assert_equal(true, settings.propagate_helper_methods)
        end
      end
      loader.lookup(["blah"])
    end
  end

  describe "toys_version directives" do
    it "checks versions" do
      t = self
      loader.add_block do
        t.assert(toys_version?("> 0.9", "< 100.0"))
        t.refute(toys_version?("< 0.9"))
      end
      loader.lookup([])
    end

    it "asserts versions" do
      t = self
      loader.add_block do
        toys_version!("> 0.9", "< 100.0")
        ex = t.assert_raises(Toys::ToolDefinitionError) do
          toys_version!("< 0.9")
        end
        t.assert_equal("Toys version requirements < 0.9 not satisfied by #{Toys::Core::VERSION}",
                       ex.message)
      end
      loader.lookup([])
    end
  end

  describe "Toys::Tool subclassing" do
    it "creates a tool" do
      loader.add_path(File.join(cases_dir, "tool-subclasses"))
      tool, _remaining = loader.lookup(["foo"])
      assert_equal("description of foo", tool.desc.to_s)
    end

    it "creates a tool with a hyphenated name" do
      loader.add_path(File.join(cases_dir, "tool-subclasses"))
      tool, _remaining = loader.lookup(["foo-bar"])
      assert_equal("description of foo-bar", tool.desc.to_s)
    end

    it "creates a nested tool using a nested class" do
      loader.add_path(File.join(cases_dir, "tool-subclasses"))
      tool, _remaining = loader.lookup(["foo-bar", "baz"])
      assert_equal("description of foo-bar baz", tool.desc.to_s)
    end

    it "creates a nested tool using a block" do
      loader.add_path(File.join(cases_dir, "tool-subclasses"))
      tool, _remaining = loader.lookup(["foo-bar", "qux"])
      assert_equal("description of foo-bar qux", tool.desc.to_s)
    end

    it "creates a tool with a custom name" do
      loader.add_path(File.join(cases_dir, "tool-subclasses"))
      tool, _remaining = loader.lookup(["qu_ux"])
      assert_equal("description of qu_ux", tool.desc.to_s)
    end

    it "creates a tool subclassing an existing tool" do
      loader.add_path(File.join(cases_dir, "tool-subclasses"))
      tool, _remaining = loader.lookup(["foo-child1"])
      assert_equal("description of foo-child1", tool.desc.to_s)
      assert_equal(9, cli.run(["foo-child1"]))
    end

    it "creates a custom-named tool subclassing an existing tool" do
      loader.add_path(File.join(cases_dir, "tool-subclasses"))
      tool, _remaining = loader.lookup(["foo_child2"])
      assert_equal("description of foo_child2", tool.desc.to_s)
      assert_equal(9, cli.run(["foo_child2"]))
    end

    it "creates a tool subclassing an existing custom-named tool" do
      loader.add_path(File.join(cases_dir, "tool-subclasses"))
      tool, _remaining = loader.lookup(["quux-child1"])
      assert_equal("description of quux-child1", tool.desc.to_s)
      assert_equal(8, cli.run(["quux-child1"]))
    end

    it "creates a custom-named tool subclassing an existing custom-named tool" do
      loader.add_path(File.join(cases_dir, "tool-subclasses"))
      tool, _remaining = loader.lookup(["quux_child2"])
      assert_equal("description of quux_child2", tool.desc.to_s)
      assert_equal(8, cli.run(["quux_child2"]))
    end

    it "is not allowed outside the DSL" do
      ex = assert_raises(Toys::ToolDefinitionError) do
        class Hello1 < Toys::Tool; end
      end
      assert_match(/Toys::Tool can be subclassed only from the Toys DSL/, ex.message)
    end

    it "is not allowed from a block" do
      t = self
      loader.add_block do
        ex = t.assert_raises(Toys::ToolDefinitionError) do
          class Hello1 < Toys::Tool; end
        end
        t.assert_match(/Toys::Tool cannot be subclassed inside a tool block/, ex.message)
      end
    end

    it "is not allowed from a tool block" do
      loader.add_path(File.join(cases_dir, "tool-subclass-under-block"))
      ex = assert_raises(Toys::ContextualError) do
        loader.lookup(["foo"])
      end
      assert_match(/Toys::Tool cannot be subclassed inside a tool block/, ex.cause.message)
    end
  end
end
