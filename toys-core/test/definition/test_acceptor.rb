# Copyright 2018 Daniel Azuma
#
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice,
#   this list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# * Neither the name of the copyright holder, nor the names of any other
#   contributors to this software, may be used to endorse or promote products
#   derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
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
