# frozen_string_literal: true

require "helper"

describe Toys::Compat do
  describe "#allow_fork?" do
    it "matches Process.respond_to(:fork)" do
      assert_equal(Toys::Compat.allow_fork?, Process.respond_to?(:fork))
    end
  end
end
