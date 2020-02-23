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
end
