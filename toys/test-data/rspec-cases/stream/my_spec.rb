# frozen_string_literal: true

describe "streams" do
  it "returns foo" do
    expect($stdin.read.strip).to eql("foo")
  end
end
