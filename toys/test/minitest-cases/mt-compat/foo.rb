# frozen_string_literal: true

require "minitest/autorun"

describe "foo" do
  it "sets MT_COMPAT" do
    assert_equal("true", ENV["MT_COMPAT"])
  end
end
