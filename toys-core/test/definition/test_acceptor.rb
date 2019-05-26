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
  let(:input_string) { "Arya Stark" }
  let(:acceptor) { Toys::Definition::Acceptor.new("hello") }

  it "accepts any string" do
    assert_equal(input_string, acceptor.match(input_string))
  end

  it "does no conversion" do
    assert_equal(input_string, acceptor.convert(input_string, input_string))
  end
end

describe Toys::Definition::SimpleAcceptor do
  let(:input_string) { "Arya Stark" }
  let(:upcase_string) { input_string.upcase }

  describe "with no function" do
    let(:acceptor) { Toys::Definition::SimpleAcceptor.new("hello") }

    it "accepts any string" do
      assert_equal([input_string, input_string], acceptor.match(input_string))
    end

    it "does no conversion" do
      assert_equal(input_string, acceptor.convert(input_string, input_string))
    end
  end

  describe "with proc function" do
    let(:acceptor) {
      Toys::Definition::SimpleAcceptor.new("hello", :upcase.to_proc)
    }

    it "accepts any string" do
      assert_equal([input_string, upcase_string], acceptor.match(input_string))
    end

    it "converts" do
      assert_equal(upcase_string, acceptor.convert(input_string, upcase_string))
    end
  end

  describe "with block function" do
    let(:acceptor) {
      Toys::Definition::SimpleAcceptor.new("hello", &:upcase)
    }

    it "accepts any string" do
      assert_equal([input_string, upcase_string], acceptor.match(input_string))
    end

    it "converts" do
      assert_equal(upcase_string, acceptor.convert(input_string, upcase_string))
    end
  end

  describe "with failable function" do
    let(:acceptor) {
      Toys::Definition::SimpleAcceptor.new("hello") { |s| Integer(s) }
    }

    it "recognizes exceptions" do
      acceptor = Toys::Definition::SimpleAcceptor.new("hello") { |s| Integer(s) }
      assert_nil(acceptor.match(input_string))
    end

    it "recognizes reject sentinel" do
      acceptor = Toys::Definition::SimpleAcceptor.new("hello") do |_s|
        Toys::Definition::SimpleAcceptor::REJECT
      end
      assert_nil(acceptor.match(input_string))
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
