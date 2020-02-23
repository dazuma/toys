# frozen_string_literal: true

require "helper"

describe "toys version" do
  it "must be the same as the toys-core version" do
    assert_equal(Toys::CORE_VERSION, Toys::VERSION)
  end
end
