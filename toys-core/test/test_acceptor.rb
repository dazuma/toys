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
require "optparse"

describe Toys::Acceptor::Base do
  let(:input_string) { "Arya Stark" }
  let(:acceptor) { Toys::Acceptor::Base.new("hello") }

  it "accepts any string" do
    assert_equal([input_string], acceptor.match(input_string))
  end

  it "does no conversion" do
    assert_equal(input_string, acceptor.convert(input_string, "No one"))
  end

  it "accepts nil" do
    assert_equal([nil], acceptor.match(nil))
  end
end

describe Toys::Acceptor::Simple do
  let(:input_string) { "Arya Stark" }
  let(:upcase_string) { input_string.upcase }

  describe "with no function" do
    let(:acceptor) { Toys::Acceptor::Simple.new("hello") }

    it "accepts any string" do
      assert_equal([input_string, input_string], acceptor.match(input_string))
    end

    it "does no conversion" do
      assert_equal(input_string, acceptor.convert(input_string, input_string))
    end
  end

  describe "with proc function" do
    let(:acceptor) {
      Toys::Acceptor::Simple.new("hello", :upcase.to_proc)
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
      Toys::Acceptor::Simple.new("hello", &:upcase)
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
      Toys::Acceptor::Simple.new("hello") { |s| Integer(s) }
    }

    it "recognizes exceptions" do
      acceptor = Toys::Acceptor::Simple.new("hello") { |s| Integer(s) }
      assert_nil(acceptor.match(input_string))
    end

    it "recognizes reject sentinel" do
      acceptor = Toys::Acceptor::Simple.new("hello") do |_s|
        Toys::Acceptor::Simple::REJECT
      end
      assert_nil(acceptor.match(input_string))
    end
  end
end

describe Toys::Acceptor::Pattern do
  let(:acceptor) { Toys::Acceptor::Pattern.new("hello", /^[A-Z][a-z]+\sStark$/) }

  it "accepts matching strings" do
    assert_equal(["Arya Stark"], acceptor.match("Arya Stark").to_a)
  end

  it "does no conversion" do
    assert_equal("Arya Stark", acceptor.convert("Arya Stark"))
  end

  it "does not accept unmatching strings" do
    assert_nil(acceptor.match("Jon Snow"))
  end

  it "accepts nil" do
    assert_equal([nil], acceptor.match(nil))
  end

  it "converts nil" do
    assert_nil(acceptor.convert(nil))
  end
end

describe Toys::Acceptor::Enum do
  let(:acceptor) {
    Toys::Acceptor::Enum.new("hello", [:Robb, :Sansa, :Arya, :Bran, :Rickon])
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

  it "accepts nil" do
    assert_equal([nil, nil], acceptor.match(nil))
  end

  it "converts nil" do
    assert_nil(acceptor.convert(nil, nil))
  end
end

describe "standard acceptor" do
  def assert_accept(acceptor, value, converted)
    match = acceptor.match(value)
    refute_nil(match, "Expected match to succeed")
    actual = acceptor.convert(*match)
    if converted.nil?
      assert_nil(actual)
    else
      assert_equal(converted, actual)
      assert_equal(converted.class, actual.class)
    end
  end

  def refute_accept(acceptor, value)
    match = acceptor.match(value)
    assert_nil(match, "Expected match to fail")
  end

  describe "Object" do
    let(:acceptor) { Toys::Acceptor.resolve_well_known(Object) }

    it "accepts nonempty string" do
      assert_accept(acceptor, "hi", "hi")
    end

    it "accepts empty string" do
      assert_accept(acceptor, "", "")
    end

    it "converts nil to true" do
      assert_accept(acceptor, nil, true)
    end
  end

  describe "NilClass" do
    let(:acceptor) { Toys::Acceptor.resolve_well_known(NilClass) }

    it "accepts nonempty string" do
      assert_accept(acceptor, "hi", "hi")
    end

    it "accepts empty string" do
      assert_accept(acceptor, "", "")
    end

    it "converts nil to nil" do
      assert_accept(acceptor, nil, nil)
    end
  end

  describe "String" do
    let(:acceptor) { Toys::Acceptor.resolve_well_known(String) }

    it "accepts nonempty string" do
      assert_accept(acceptor, "hi", "hi")
    end

    it "does not accept empty string" do
      refute_accept(acceptor, "")
    end

    it "converts nil to nil" do
      assert_accept(acceptor, nil, nil)
    end
  end

  describe "Integer" do
    let(:acceptor) { Toys::Acceptor.resolve_well_known(Integer) }

    it "accepts integer string" do
      assert_accept(acceptor, "123", 123)
    end

    it "accepts negative integer string" do
      assert_accept(acceptor, "-123", -123)
    end

    it "accepts octal string" do
      assert_accept(acceptor, "-0123", -83)
    end

    it "accepts hex string" do
      assert_accept(acceptor, "-0xabc", -2748)
    end

    it "accepts binary string" do
      assert_accept(acceptor, "-0b101", -5)
    end

    it "does not accept empty string" do
      refute_accept(acceptor, "")
    end

    it "does not accept noninteger string" do
      refute_accept(acceptor, "hi")
    end

    it "converts nil to nil" do
      assert_accept(acceptor, nil, nil)
    end
  end

  describe "Float" do
    let(:acceptor) { Toys::Acceptor.resolve_well_known(Float) }

    it "accepts integer string" do
      assert_accept(acceptor, "123", 123.0)
    end

    it "accepts fractional string" do
      assert_accept(acceptor, "123.456", 123.456)
    end

    it "accepts negative fractional string" do
      assert_accept(acceptor, "-123.456", -123.456)
    end

    it "does not accept empty string" do
      refute_accept(acceptor, "")
    end

    it "does not accept nonnumeric string" do
      refute_accept(acceptor, "hi")
    end

    it "converts nil to nil" do
      assert_accept(acceptor, nil, nil)
    end
  end

  describe "Rational" do
    let(:acceptor) { Toys::Acceptor.resolve_well_known(Rational) }

    it "accepts integer string" do
      assert_accept(acceptor, "123", Rational(123, 1))
    end

    it "accepts floating point string" do
      assert_accept(acceptor, "123.456", Rational(15_432, 125))
    end

    it "accepts negative string" do
      assert_accept(acceptor, "-123.0", Rational(-123, 1))
    end

    it "accepts fractional string" do
      assert_accept(acceptor, "-123/2", Rational(-123, 2))
    end

    it "does not accept empty string" do
      refute_accept(acceptor, "")
    end

    it "does not accept nonnumeric string" do
      refute_accept(acceptor, "hi")
    end

    it "converts nil to nil" do
      assert_accept(acceptor, nil, nil)
    end
  end

  describe "Numeric" do
    let(:acceptor) { Toys::Acceptor.resolve_well_known(Numeric) }

    it "accepts integer string" do
      assert_accept(acceptor, "123", 123)
    end

    it "accepts floating point string" do
      assert_accept(acceptor, "123.456", 123.456)
    end

    it "accepts scientific notation string" do
      assert_accept(acceptor, "2e-2", 0.02)
    end

    it "accepts hex string that looks like scientific notation" do
      assert_accept(acceptor, "0x2e2", 738)
    end

    it "accepts negative string" do
      assert_accept(acceptor, "-123.0", -123.0)
    end

    it "accepts fractional string" do
      assert_accept(acceptor, "-123/2", Rational(-123, 2))
    end

    it "does not accept empty string" do
      refute_accept(acceptor, "")
    end

    it "does not accept nonnumeric string" do
      refute_accept(acceptor, "hi")
    end

    it "converts nil to nil" do
      assert_accept(acceptor, nil, nil)
    end
  end

  describe "TrueClass" do
    let(:acceptor) { Toys::Acceptor.resolve_well_known(TrueClass) }

    it "accepts +" do
      assert_accept(acceptor, "+", true)
    end

    it "accepts -" do
      assert_accept(acceptor, "-", false)
    end

    it "accepts t" do
      assert_accept(acceptor, "t", true)
    end

    it "accepts tr" do
      assert_accept(acceptor, "tr", true)
    end

    it "accepts true" do
      assert_accept(acceptor, "true", true)
    end

    it "accepts yes" do
      assert_accept(acceptor, "yes", true)
    end

    it "accepts false" do
      assert_accept(acceptor, "false", false)
    end

    it "accepts no" do
      assert_accept(acceptor, "no", false)
    end

    it "accepts nil" do
      assert_accept(acceptor, "nil", false)
    end

    it "accepts n" do
      assert_accept(acceptor, "n", false)
    end

    it "does not accept empty string" do
      refute_accept(acceptor, "")
    end

    it "does not accept yessir" do
      refute_accept(acceptor, "yessir")
    end

    it "converts nil to true" do
      assert_accept(acceptor, nil, true)
    end
  end

  describe "FalseClass" do
    let(:acceptor) { Toys::Acceptor.resolve_well_known(FalseClass) }

    it "accepts +" do
      assert_accept(acceptor, "+", true)
    end

    it "accepts -" do
      assert_accept(acceptor, "-", false)
    end

    it "converts nil to false" do
      assert_accept(acceptor, nil, false)
    end
  end

  describe "Array" do
    let(:acceptor) { Toys::Acceptor.resolve_well_known(Array) }

    it "accepts empty string and converts to empty array" do
      assert_accept(acceptor, "", [])
    end

    it "accepts single element" do
      assert_accept(acceptor, "hi", ["hi"])
    end

    it "accepts multiple elements" do
      assert_accept(acceptor, "hi,ho,he", ["hi", "ho", "he"])
    end

    it "strips empty trailing elements" do
      assert_accept(acceptor, "hi,ho,", ["hi", "ho"])
    end

    it "converts empty leading and internal elements to nil" do
      assert_accept(acceptor, ",hi,,ho,he", [nil, "hi", nil, "ho", "he"])
    end

    it "converts nil to nil" do
      assert_accept(acceptor, nil, nil)
    end
  end

  describe "Regexp" do
    let(:acceptor) { Toys::Acceptor.resolve_well_known(Regexp) }

    it "accepts a bare regex" do
      assert_accept(acceptor, "hi", /hi/)
    end

    it "accepts a regex surrounded by slashes" do
      assert_accept(acceptor, "/hi/", /hi/)
    end

    it "accepts a bare regex including special characters" do
      assert_accept(acceptor, "^\\n(hi)*\\z", /^\n(hi)*\z/)
    end

    it "accepts a slashed regex including special characters" do
      assert_accept(acceptor, "/^\\n(hi)*\\z/", /^\n(hi)*\z/)
    end

    it "accepts a regex with m flag" do
      assert_accept(acceptor, "/hi/m", /hi/m)
    end

    it "accepts a regex ignoring o flag" do
      assert_accept(acceptor, "/hi/io", /hi/i)
    end

    it "converts nil to nil" do
      assert_accept(acceptor, nil, nil)
    end
  end

  describe "DecimalInteger" do
    let(:acceptor) { Toys::Acceptor.resolve_well_known(OptionParser::DecimalInteger) }

    it "accepts integer string" do
      assert_accept(acceptor, "123", 123)
    end

    it "accepts negative integer string" do
      assert_accept(acceptor, "-123", -123)
    end

    it "accepts octal string but interprets as decimal" do
      assert_accept(acceptor, "-0123", -123)
    end

    it "rejects hex string" do
      refute_accept(acceptor, "0xabc")
    end

    it "rejects binary string" do
      refute_accept(acceptor, "-0b101")
    end

    it "does not accept empty string" do
      refute_accept(acceptor, "")
    end

    it "does not accept noninteger string" do
      refute_accept(acceptor, "hi")
    end

    it "converts nil to nil" do
      assert_accept(acceptor, nil, nil)
    end
  end

  describe "OctalInteger" do
    let(:acceptor) { Toys::Acceptor.resolve_well_known(OptionParser::OctalInteger) }

    it "accepts integer string" do
      assert_accept(acceptor, "123", 83)
    end

    it "accepts negative integer string" do
      assert_accept(acceptor, "-123", -83)
    end

    it "accepts octal string format" do
      assert_accept(acceptor, "-0123", -83)
    end

    it "rejects hex string" do
      refute_accept(acceptor, "0xabc")
    end

    it "rejects binary string" do
      refute_accept(acceptor, "-0b101")
    end

    it "rejects digits 8 and 9" do
      refute_accept(acceptor, "8")
      refute_accept(acceptor, "9")
    end

    it "does not accept empty string" do
      refute_accept(acceptor, "")
    end

    it "does not accept noninteger string" do
      refute_accept(acceptor, "hi")
    end

    it "converts nil to nil" do
      assert_accept(acceptor, nil, nil)
    end
  end

  describe "DecimalNumeric" do
    let(:acceptor) { Toys::Acceptor.resolve_well_known(OptionParser::DecimalNumeric) }

    it "accepts integer string" do
      assert_accept(acceptor, "123", 123)
    end

    it "accepts floating point string" do
      assert_accept(acceptor, "123.456", 123.456)
    end

    it "accepts scientific notation string" do
      assert_accept(acceptor, "2e-2", 0.02)
    end

    it "rejects hex string that looks like scientific notation" do
      refute_accept(acceptor, "0x2e2")
    end

    it "accepts negative string" do
      assert_accept(acceptor, "-123.0", -123.0)
    end

    it "does not accept empty string" do
      refute_accept(acceptor, "")
    end

    it "does not accept nonnumeric string" do
      refute_accept(acceptor, "hi")
    end

    it "converts nil to nil" do
      assert_accept(acceptor, nil, nil)
    end
  end
end
