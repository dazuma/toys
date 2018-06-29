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
  end

  describe "desc directive" do
    it "sets the desc" do
      loader.add_block do
        desc "this is a desc"
      end
      tool, _remaining = loader.lookup(["foo", "hi"])
      assert_equal("this is a desc", tool.desc.to_s)
    end
  end

  describe "long_desc directive" do
    it "sets the long desc" do
      loader.add_block do
        long_desc "this is a desc", "with multiple lines"
      end
      tool, _remaining = loader.lookup(["foo", "hi"])
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
      tool, _remaining = loader.lookup(["foo", "hi"])
      ld = tool.long_desc
      assert_equal(3, ld.size)
      assert_equal("this is a desc", ld[0].to_s)
      assert_equal("with multiple lines", ld[1].to_s)
      assert_equal("and an append", ld[2].to_s)
    end
  end

  describe "flag directive" do
  end

  describe "required_arg directive" do
  end

  describe "optional_arg directive" do
  end

  describe "remaining_args directive" do
  end

  describe "set directive" do
  end

  describe "disable_argument_parsing directive" do
  end

  describe "disable_flag directive" do
  end
end
