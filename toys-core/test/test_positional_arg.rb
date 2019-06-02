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

describe Toys::PositionalArg do
  let(:acceptor) { Toys::Acceptor.lookup_well_known(Integer) }
  let(:arg) {
    Toys::PositionalArg.new(
      "hello-there!", :required, acceptor, -1, nil, "description", ["long", "description"], nil
    )
  }

  it "passes through attributes" do
    assert_equal("hello-there!", arg.key)
    assert_equal(:required, arg.type)
    assert_equal(acceptor, arg.acceptor)
    assert_equal(-1, arg.default)
  end

  it "computes descriptions" do
    assert_equal(Toys::WrappableString.new("description"), arg.desc)
    assert_equal([Toys::WrappableString.new("long"),
                  Toys::WrappableString.new("description")], arg.long_desc)
  end

  it "computes display name" do
    assert_equal("HELLO_THERE", arg.display_name)
  end
end
