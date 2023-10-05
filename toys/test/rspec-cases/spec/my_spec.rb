# frozen_string_literal: true

require "spec_fixture"

describe SpecFixture do
  it "returns foo" do
    expect(SpecFixture.foo).to eql("foo")
  end
end
