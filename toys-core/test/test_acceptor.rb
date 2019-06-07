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
  let(:acceptor) { Toys::Acceptor::Base.new }

  it "accepts any string" do
    assert_equal([input_string], acceptor.match(input_string))
  end

  it "does no conversion" do
    assert_equal(input_string, acceptor.convert(input_string, "No one"))
  end

  it "accepts nil" do
    assert_equal([nil], acceptor.match(nil))
  end

  it "defaults type desc to DEFAULT_TYPE_DESC" do
    assert_equal(Toys::Acceptor::DEFAULT_TYPE_DESC, acceptor.type_desc)
  end

  it "returns no alternatives" do
    assert_equal([], acceptor.alternatives("Jon Snow"))
  end
end

describe Toys::Acceptor::Simple do
  let(:input_string) { "Arya Stark" }
  let(:upcase_string) { input_string.upcase }

  describe "with no function" do
    let(:acceptor) { Toys::Acceptor::Simple.new }

    it "accepts any string" do
      assert_equal([input_string, input_string], acceptor.match(input_string))
    end

    it "does no conversion" do
      assert_equal(input_string, acceptor.convert(input_string, input_string))
    end
  end

  describe "with proc function" do
    let(:acceptor) {
      Toys::Acceptor::Simple.new(:upcase.to_proc)
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
      Toys::Acceptor::Simple.new(&:upcase)
    }

    it "accepts any string" do
      assert_equal([input_string, upcase_string], acceptor.match(input_string))
    end

    it "converts" do
      assert_equal(upcase_string, acceptor.convert(input_string, upcase_string))
    end
  end

  describe "with failable function" do
    it "recognizes exceptions" do
      acceptor = Toys::Acceptor::Simple.new { |s| Integer(s) }
      assert_nil(acceptor.match(input_string))
    end

    it "recognizes reject sentinel" do
      acceptor = Toys::Acceptor::Simple.new { |_s| Toys::Acceptor::Simple::REJECT }
      assert_nil(acceptor.match(input_string))
    end
  end
end

describe Toys::Acceptor::Pattern do
  let(:acceptor) { Toys::Acceptor::Pattern.new(/^[A-Z][a-z]+\sStark$/) }

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
    Toys::Acceptor::Enum.new([:Robb, :Sansa, :Arya, :Bran, :Rickon])
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

  it "returns alternatives" do
    assert_equal(["Robb"], acceptor.alternatives("robb"))
  end
end

describe Toys::Acceptor::Range do
  describe "of integer" do
    let(:acceptor) {
      Toys::Acceptor::Range.new(1..10)
    }

    it "accepts integers in the range" do
      assert_equal(["1", 1], acceptor.match("1"))
    end

    it "rejects integers outside the range" do
      assert_nil(acceptor.match("0"))
    end

    it "rejects floats" do
      assert_nil(acceptor.match("2.0"))
    end

    it "rejects non-numerics" do
      assert_nil(acceptor.match("hi!"))
    end

    it "accepts nil" do
      assert_equal([nil, nil], acceptor.match(nil))
    end
  end

  describe "of float" do
    let(:acceptor) {
      Toys::Acceptor::Range.new(1.1..10.0)
    }

    it "accepts integers in the range" do
      assert_equal(["2", 2.0], acceptor.match("2"))
    end

    it "accepts floats in the range" do
      assert_equal(["2.0", 2.0], acceptor.match("2.0"))
    end

    it "rejects floats outside the range" do
      assert_nil(acceptor.match("1.0"))
    end

    it "rejects rationals" do
      assert_nil(acceptor.match("5/2"))
    end

    it "rejects non-numerics" do
      assert_nil(acceptor.match("hi!"))
    end

    it "accepts nil" do
      assert_equal([nil, nil], acceptor.match(nil))
    end
  end

  describe "of rational" do
    let(:acceptor) {
      Toys::Acceptor::Range.new(Rational(1, 1)..Rational(21, 2))
    }

    it "accepts integers in the range" do
      assert_equal(["2", Rational(2, 1)], acceptor.match("2"))
    end

    it "accepts floats in the range" do
      assert_equal(["2.0", Rational(2, 1)], acceptor.match("2.0"))
    end

    it "accepts rationals in the range" do
      assert_equal(["3/2", Rational(3, 2)], acceptor.match("3/2"))
    end

    it "rejects rationals outside the range" do
      assert_nil(acceptor.match("1/2"))
    end

    it "rejects non-numerics" do
      assert_nil(acceptor.match("hi!"))
    end

    it "accepts nil" do
      assert_equal([nil, nil], acceptor.match(nil))
    end
  end

  describe "of numeric" do
    let(:acceptor) {
      Toys::Acceptor::Range.new(1..9.9)
    }

    it "accepts integers in the range" do
      assert_equal(["2", 2], acceptor.match("2"))
    end

    it "accepts floats in the range" do
      assert_equal(["2.0", 2.0], acceptor.match("2.0"))
    end

    it "accepts rationals in the range" do
      assert_equal(["3/2", Rational(3, 2)], acceptor.match("3/2"))
    end

    it "rejects integers outside the range" do
      assert_nil(acceptor.match("10"))
    end

    it "rejects non-numerics" do
      assert_nil(acceptor.match("hi!"))
    end

    it "accepts nil" do
      assert_equal([nil, nil], acceptor.match(nil))
    end
  end

  describe "of string" do
    let(:acceptor) {
      Toys::Acceptor::Range.new("a".."f")
    }

    it "accepts strings" do
      assert_equal(["b", "b"], acceptor.match("b"))
    end

    it "rejects strings outside the range" do
      assert_nil(acceptor.match("A"))
    end

    it "accepts nil" do
      assert_equal([nil, nil], acceptor.match(nil))
    end
  end

  describe "of custom" do
    let(:acceptor) {
      Toys::Acceptor::Range.new(Time.new(10)..Time.new(20)) do |s|
        s.nil? ? nil : Time.new(Integer(s))
      end
    }

    it "accepts times" do
      assert_equal(["11", Time.new(11)], acceptor.match("11"))
    end

    it "rejects times outside the range" do
      assert_nil(acceptor.match("21"))
    end

    it "accepts nil" do
      assert_equal([nil, nil], acceptor.match(nil))
    end
  end
end

describe Toys::Acceptor do
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

  describe "create" do
    it "looks up well-known acceptors" do
      acceptor = Toys::Acceptor.create(Integer)
      assert_equal(Integer, acceptor.well_known_spec)
      assert_equal("integer", acceptor.type_desc)
    end

    it "passes through acceptor objects" do
      acceptor = Toys::Acceptor.create(Integer)
      acceptor2 = Toys::Acceptor.create(acceptor)
      assert_equal(acceptor, acceptor2)
    end

    it "recognizes a regex" do
      acceptor = Toys::Acceptor.create(/[A-Z]\w+/, type_desc: "module name") do |s|
        Object.const_get(s)
      end
      assert_instance_of(Toys::Acceptor::Pattern, acceptor)
      assert_equal("module name", acceptor.type_desc)
      assert_accept(acceptor, "Time", Time)
      refute_accept(acceptor, "time")
    end

    it "recognizes an array" do
      acceptor = Toys::Acceptor.create([:one, :two, :three], type_desc: "number")
      assert_instance_of(Toys::Acceptor::Enum, acceptor)
      assert_equal("number", acceptor.type_desc)
      assert_accept(acceptor, "two", :two)
      refute_accept(acceptor, "four")
    end

    it "recognizes a range" do
      acceptor = Toys::Acceptor.create(1..10, type_desc: "number")
      assert_instance_of(Toys::Acceptor::Range, acceptor)
      assert_equal("number", acceptor.type_desc)
      assert_accept(acceptor, "2", 2)
      refute_accept(acceptor, "11")
    end

    it "recognizes a proc" do
      acceptor = Toys::Acceptor.create(->(s) { Integer(s, 2) }, type_desc: "binary number")
      assert_instance_of(Toys::Acceptor::Simple, acceptor)
      assert_equal("binary number", acceptor.type_desc)
      assert_accept(acceptor, "101", 5)
      refute_accept(acceptor, "102")
    end

    it "recognizes a block" do
      acceptor = Toys::Acceptor.create(type_desc: "binary number") { |s| Integer(s, 2) }
      assert_instance_of(Toys::Acceptor::Simple, acceptor)
      assert_equal("binary number", acceptor.type_desc)
      assert_accept(acceptor, "101", 5)
      refute_accept(acceptor, "102")
    end

    it "recognizes nil" do
      acceptor = Toys::Acceptor.create(nil)
      assert_equal(Toys::Acceptor::DEFAULT, acceptor)
    end

    it "errors on unrecognized spec" do
      assert_raises(Toys::ToolDefinitionError) do
        Toys::Acceptor.create(:hiho)
      end
    end
  end

  describe "lookup_well_known" do
    describe "Object" do
      let(:acceptor) { Toys::Acceptor.lookup_well_known(Object) }

      it "accepts nonempty string" do
        assert_accept(acceptor, "hi", "hi")
      end

      it "accepts empty string" do
        assert_accept(acceptor, "", "")
      end

      it "converts nil to true" do
        assert_accept(acceptor, nil, true)
      end

      it "has the correct type desc" do
        assert_equal("string", acceptor.type_desc)
      end
    end

    describe "NilClass" do
      let(:acceptor) { Toys::Acceptor.lookup_well_known(NilClass) }

      it "accepts nonempty string" do
        assert_accept(acceptor, "hi", "hi")
      end

      it "accepts empty string" do
        assert_accept(acceptor, "", "")
      end

      it "converts nil to nil" do
        assert_accept(acceptor, nil, nil)
      end

      it "has the correct type desc" do
        assert_equal("string", acceptor.type_desc)
      end
    end

    describe "String" do
      let(:acceptor) { Toys::Acceptor.lookup_well_known(String) }

      it "accepts nonempty string" do
        assert_accept(acceptor, "hi", "hi")
      end

      it "does not accept empty string" do
        refute_accept(acceptor, "")
      end

      it "converts nil to nil" do
        assert_accept(acceptor, nil, nil)
      end

      it "has the correct type desc" do
        assert_equal("nonempty string", acceptor.type_desc)
      end
    end

    describe "Integer" do
      let(:acceptor) { Toys::Acceptor.lookup_well_known(Integer) }

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

      it "has the correct type desc" do
        assert_equal("integer", acceptor.type_desc)
      end
    end

    describe "Float" do
      let(:acceptor) { Toys::Acceptor.lookup_well_known(Float) }

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

      it "has the correct type desc" do
        assert_equal("floating point number", acceptor.type_desc)
      end
    end

    describe "Rational" do
      let(:acceptor) { Toys::Acceptor.lookup_well_known(Rational) }

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

      it "has the correct type desc" do
        assert_equal("rational number", acceptor.type_desc)
      end
    end

    describe "Numeric" do
      let(:acceptor) { Toys::Acceptor.lookup_well_known(Numeric) }

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

      it "has the correct type desc" do
        assert_equal("number", acceptor.type_desc)
      end
    end

    describe "TrueClass" do
      let(:acceptor) { Toys::Acceptor.lookup_well_known(TrueClass) }

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

      it "has the correct type desc" do
        assert_equal("boolean", acceptor.type_desc)
      end
    end

    describe "FalseClass" do
      let(:acceptor) { Toys::Acceptor.lookup_well_known(FalseClass) }

      it "accepts +" do
        assert_accept(acceptor, "+", true)
      end

      it "accepts -" do
        assert_accept(acceptor, "-", false)
      end

      it "converts nil to false" do
        assert_accept(acceptor, nil, false)
      end

      it "has the correct type desc" do
        assert_equal("boolean", acceptor.type_desc)
      end
    end

    describe "Array" do
      let(:acceptor) { Toys::Acceptor.lookup_well_known(Array) }

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

      it "has the correct type desc" do
        assert_equal("string array", acceptor.type_desc)
      end
    end

    describe "Regexp" do
      let(:acceptor) { Toys::Acceptor.lookup_well_known(Regexp) }

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

      it "has the correct type desc" do
        assert_equal("regular expression", acceptor.type_desc)
      end
    end

    describe "DecimalInteger" do
      let(:acceptor) { Toys::Acceptor.lookup_well_known(OptionParser::DecimalInteger) }

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

      it "has the correct type desc" do
        assert_equal("decimal integer", acceptor.type_desc)
      end
    end

    describe "OctalInteger" do
      let(:acceptor) { Toys::Acceptor.lookup_well_known(OptionParser::OctalInteger) }

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

      it "has the correct type desc" do
        assert_equal("octal integer", acceptor.type_desc)
      end
    end

    describe "DecimalNumeric" do
      let(:acceptor) { Toys::Acceptor.lookup_well_known(OptionParser::DecimalNumeric) }

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

      it "has the correct type desc" do
        assert_equal("decimal number", acceptor.type_desc)
      end
    end
  end
end
