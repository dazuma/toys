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

describe Toys::Mixin do
  it "provides module methods" do
    mod = Toys::Mixin.create
    assert_equal(true, mod.respond_to?(:to_initialize))
    assert_equal(true, mod.respond_to?(:to_include))
    assert_equal(true, mod.respond_to?(:initialization_callback))
    assert_equal(true, mod.respond_to?(:initialization_callback=))
    assert_equal(true, mod.respond_to?(:inclusion_callback))
    assert_equal(true, mod.respond_to?(:inclusion_callback=))
  end

  it "allows block configuration" do
    mod = Toys::Mixin.create do
      def mithrandir
        :mithrandir
      end
      to_initialize do
        :gandalf
      end
      to_include do
        :frodo
      end
    end
    assert_equal(:gandalf, mod.initialization_callback.call)
    assert_equal(:frodo, mod.inclusion_callback.call)
    klass = ::Class.new do
      include mod
    end
    assert_equal(:mithrandir, klass.new.mithrandir)
  end
end
