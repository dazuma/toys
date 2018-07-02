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

describe Toys::Utils::WrappableString do
  describe "wrap string" do
    it "handles empty string" do
      result = Toys::Utils::WrappableString.new("").wrap(10)
      assert_equal([], result)
    end

    it "handles whitespace string" do
      result = Toys::Utils::WrappableString.new(" \n ").wrap(10)
      assert_equal([], result)
    end

    it "handles single line" do
      result = Toys::Utils::WrappableString.new("a bcd e").wrap(10)
      assert_equal(["a bcd e"], result)
    end

    it "handles leading and trailing spaces" do
      result = Toys::Utils::WrappableString.new("  a bcd e\n").wrap(10)
      assert_equal(["a bcd e"], result)
    end

    it "splits lines" do
      result = Toys::Utils::WrappableString.new("a b cd efg\n").wrap(5)
      assert_equal(["a b", "cd", "efg"], result)
    end

    it "allows a long word" do
      result = Toys::Utils::WrappableString.new("a b cdefghij kl\n").wrap(5)
      assert_equal(["a b", "cdefghij", "kl"], result)
    end

    it "honors the width exactly" do
      result = Toys::Utils::WrappableString.new("a bcd ef ghi j").wrap(5)
      assert_equal(["a bcd", "ef", "ghi j"], result)
    end

    it "honors different width2" do
      result = Toys::Utils::WrappableString.new("a b cd ef\n").wrap(3, 5)
      assert_equal(["a b", "cd ef"], result)
    end

    it "doesn't get confused by ansi style codes" do
      str = Toys::Utils::Terminal.new(styled: true).apply_styles("a b", :bold)
      result = Toys::Utils::WrappableString.new(str).wrap(3)
      assert_equal([str], result)
      result2 = Toys::Utils::WrappableString.new(str).wrap(2)
      assert_equal(2, result2.size)
    end
  end

  describe "wrap fragments" do
    it "handles empty fragments" do
      result = Toys::Utils::WrappableString.new([]).wrap(10)
      assert_equal([], result)
    end

    it "does not split fragments" do
      result = Toys::Utils::WrappableString.new(["ab cd", "ef gh", "ij kl"]).wrap(10)
      assert_equal(["ab cd", "ef gh", "ij kl"], result)
    end

    it "combines fragments" do
      result = Toys::Utils::WrappableString.new(["ab cd", "ef gh", "ij kl"]).wrap(13)
      assert_equal(["ab cd ef gh", "ij kl"], result)
    end

    it "preserves spaces in fragments" do
      result = Toys::Utils::WrappableString.new([" ab cd\n", "\nef gh ", "ij   kl"]).wrap(15)
      assert_equal([" ab cd\n \nef gh ", "ij   kl"], result)
    end
  end
end
