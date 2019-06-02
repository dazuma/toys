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

describe Toys::Template do
  it "provides class methods" do
    klass = Toys::Template.create
    assert_equal(true, klass.respond_to?(:to_expand))
    assert_equal(true, klass.respond_to?(:expander))
    assert_equal(true, klass.respond_to?(:expander=))
  end

  it "includes context key constants" do
    klass = Toys::Template.create
    assert_equal(Toys::Context::Key::TOOL, klass::TOOL)
  end

  it "allows block configuration" do
    klass = Toys::Template.create do
      def mithrandir
        :mithrandir
      end
      to_expand do
        :gandalf
      end
    end
    assert_equal(:mithrandir, klass.new.mithrandir)
    assert_equal(:gandalf, klass.expander.call)
  end
end
