# frozen_string_literal: true

require "helper"

describe Toys::PositionalArg do
  let(:acceptor) { Toys::Acceptor.lookup_well_known(Integer) }
  let(:arg) {
    Toys::PositionalArg.new(
      "hello-there!", :required, acceptor, -1, nil, "description", ["long", "description"], nil
    )
  }

  it "passes through attributes" do
    assert_equal("hello-there!", arg.key)
    assert_equal(:required, arg.type)
    assert_equal(acceptor, arg.acceptor)
    assert_equal(-1, arg.default)
  end

  it "computes descriptions" do
    assert_equal(Toys::WrappableString.new("description"), arg.desc)
    assert_equal([Toys::WrappableString.new("long"),
                  Toys::WrappableString.new("description")], arg.long_desc)
  end

  it "computes display name" do
    assert_equal("HELLO_THERE", arg.display_name)
  end

  describe ".create" do
    it "creates a required arg with minimal arguments" do
      arg = Toys::PositionalArg.create(:foo, :required)
      assert_equal(:foo, arg.key)
      assert_equal(:required, arg.type)
      assert_nil(arg.default)
      assert_same(Toys::Acceptor::DEFAULT, arg.acceptor)
      assert_same(Toys::Completion::EMPTY, arg.completion)
      assert_equal("FOO", arg.display_name)
      assert_equal(Toys::WrappableString.new, arg.desc)
      assert_empty(arg.long_desc)
    end

    it "creates an optional arg with a default value" do
      arg = Toys::PositionalArg.create(:bar, :optional, default: 42)
      assert_equal(:optional, arg.type)
      assert_equal(42, arg.default)
    end

    it "creates a remaining arg with an array default" do
      arg = Toys::PositionalArg.create(:rest, :remaining, default: [])
      assert_equal(:remaining, arg.type)
      assert_equal([], arg.default)
    end

    it "accepts a well-known acceptor spec" do
      arg = Toys::PositionalArg.create(:n, :required, accept: Integer)
      assert_equal(Integer, arg.acceptor.well_known_spec)
    end

    it "accepts a regexp acceptor spec" do
      arg = Toys::PositionalArg.create(:s, :required, accept: /\A\d+\z/)
      assert_instance_of(Toys::Acceptor::Pattern, arg.acceptor)
    end

    it "accepts a proc acceptor spec" do
      fn = proc(&:upcase)
      arg = Toys::PositionalArg.create(:s, :required, accept: fn)
      assert_instance_of(Toys::Acceptor::Simple, arg.acceptor)
    end

    it "accepts an array acceptor spec" do
      arg = Toys::PositionalArg.create(:s, :required, accept: [:a, :b, :c])
      assert_instance_of(Toys::Acceptor::Enum, arg.acceptor)
    end

    it "accepts an array completion spec" do
      arg = Toys::PositionalArg.create(:s, :required, complete: ["one", "two", "three"])
      assert_instance_of(Toys::Completion::Enum, arg.completion)
    end

    it "accepts a proc completion spec" do
      fn = proc { |_ctx| [] }
      arg = Toys::PositionalArg.create(:s, :required, complete: fn)
      assert_same(fn, arg.completion)
    end

    it "accepts an explicit display name" do
      arg = Toys::PositionalArg.create(:foo, :required, display_name: "MY_FOO")
      assert_equal("MY_FOO", arg.display_name)
    end

    it "accepts a short description" do
      arg = Toys::PositionalArg.create(:foo, :required, desc: "short desc")
      assert_equal("short desc", arg.desc.to_s)
    end

    it "accepts a long description" do
      arg = Toys::PositionalArg.create(:foo, :required, long_desc: ["line one", "line two"])
      assert_equal(2, arg.long_desc.size)
      assert_equal("line one", arg.long_desc[0].to_s)
      assert_equal("line two", arg.long_desc[1].to_s)
    end
  end

  describe "display name" do
    it "upcases a simple symbol key" do
      arg = Toys::PositionalArg.create(:hello, :required)
      assert_equal("HELLO", arg.display_name)
    end

    it "converts underscores to uppercase" do
      arg = Toys::PositionalArg.create(:foo_bar, :required)
      assert_equal("FOO_BAR", arg.display_name)
    end

    it "converts hyphens in symbol key to underscores" do
      arg = Toys::PositionalArg.create(:"foo-bar", :required)
      assert_equal("FOO_BAR", arg.display_name)
    end

    it "strips non-word characters other than hyphens" do
      arg = Toys::PositionalArg.create(:foo?, :required)
      assert_equal("FOO", arg.display_name)
    end

    it "explicit display_name overrides auto-generation" do
      arg = Toys::PositionalArg.create(:"foo-bar?", :required, display_name: "CUSTOM")
      assert_equal("CUSTOM", arg.display_name)
    end
  end

  describe "default acceptor" do
    it "is DEFAULT when accept is omitted" do
      arg = Toys::PositionalArg.create(:foo, :required)
      assert_same(Toys::Acceptor::DEFAULT, arg.acceptor)
    end

    it "is DEFAULT when accept is nil" do
      arg = Toys::PositionalArg.create(:foo, :required, accept: nil)
      assert_same(Toys::Acceptor::DEFAULT, arg.acceptor)
    end
  end

  describe "default completion" do
    it "is EMPTY when complete is omitted" do
      arg = Toys::PositionalArg.create(:foo, :required)
      assert_same(Toys::Completion::EMPTY, arg.completion)
    end

    it "is EMPTY when complete is nil" do
      arg = Toys::PositionalArg.create(:foo, :required, complete: nil)
      assert_same(Toys::Completion::EMPTY, arg.completion)
    end
  end

  describe "description setters" do
    let(:mutable_arg) { Toys::PositionalArg.create(:foo, :required) }

    it "desc= replaces the short description" do
      mutable_arg.desc = "new description"
      assert_equal("new description", mutable_arg.desc.to_s)
    end

    it "desc= accepts an array of words" do
      mutable_arg.desc = ["no", "breaks", "here"]
      assert_equal(Toys::WrappableString.new(["no", "breaks", "here"]), mutable_arg.desc)
    end

    it "long_desc= replaces the long description" do
      mutable_arg.long_desc = ["line one", "line two"]
      assert_equal(2, mutable_arg.long_desc.size)
      assert_equal("line one", mutable_arg.long_desc[0].to_s)
      assert_equal("line two", mutable_arg.long_desc[1].to_s)
    end

    it "long_desc= replaces a previously set long description" do
      mutable_arg.long_desc = ["old line"]
      mutable_arg.long_desc = ["new line"]
      assert_equal(1, mutable_arg.long_desc.size)
      assert_equal("new line", mutable_arg.long_desc[0].to_s)
    end

    it "append_long_desc appends to an existing long description" do
      mutable_arg.long_desc = ["line one"]
      mutable_arg.append_long_desc(["line two", "line three"])
      assert_equal(3, mutable_arg.long_desc.size)
      assert_equal("line one", mutable_arg.long_desc[0].to_s)
      assert_equal("line two", mutable_arg.long_desc[1].to_s)
      assert_equal("line three", mutable_arg.long_desc[2].to_s)
    end

    it "append_long_desc returns self" do
      result = mutable_arg.append_long_desc(["line"])
      assert_same(mutable_arg, result)
    end
  end
end
