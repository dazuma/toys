# frozen_string_literal: true

# Copyright 2019 Daniel Azuma
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.
;

require "helper"

describe Toys::Definition::Acceptor do
  describe "without converter" do
    let(:acceptor) { Toys::Definition::Acceptor.new("hello") }

    it "accepts any string" do
      assert_equal("Arya Stark", acceptor.match("Arya Stark"))
    end

    it "does no conversion" do
      assert_equal("Arya Stark", acceptor.convert("Arya Stark"))
    end
  end

  describe "with proc converter" do
    let(:converter) { :upcase.to_proc }
    let(:acceptor) { Toys::Definition::Acceptor.new("hello", converter) }

    it "accepts any string" do
      assert_equal("Arya Stark", acceptor.match("Arya Stark"))
    end

    it "converts" do
      assert_equal("ARYA STARK", acceptor.convert("Arya Stark"))
    end
  end

  describe "with block converter" do
    let(:acceptor) {
      Toys::Definition::Acceptor.new("hello", &:upcase)
    }

    it "accepts any string" do
      assert_equal("Arya Stark", acceptor.match("Arya Stark"))
    end

    it "converts" do
      assert_equal("ARYA STARK", acceptor.convert("Arya Stark"))
    end
  end
end

describe Toys::Definition::PatternAcceptor do
  let(:acceptor) { Toys::Definition::PatternAcceptor.new("hello", /^[A-Z][a-z]+\sStark$/) }

  it "accepts matching strings" do
    assert_equal(["Arya Stark"], acceptor.match("Arya Stark").to_a)
  end

  it "does no conversion" do
    assert_equal("Arya Stark", acceptor.convert("Arya Stark"))
  end

  it "does not accept unmatching strings" do
    assert_nil(acceptor.match("Jon Snow"))
  end
end

describe Toys::Definition::EnumAcceptor do
  let(:acceptor) {
    Toys::Definition::EnumAcceptor.new("hello", [:Robb, :Sansa, :Arya, :Bran, :Rickon])
  }

  it "accepts matching strings" do
    assert_equal(["Arya", :Arya], acceptor.match("Arya"))
  end

  it "does not accept unmatching strings" do
    assert_nil(acceptor.match("Jon"))
  end

  it "converts to the enum value" do
    assert_equal(:Arya, acceptor.convert("Arya", :Arya))
  end
end
