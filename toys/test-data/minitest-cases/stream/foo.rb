# frozen_string_literal: true

require "minitest/autorun"

describe "foo" do
  it "reads hello" do
    assert_equal("hello\n", $stdin.read)
  end
end
