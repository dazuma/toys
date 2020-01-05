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

describe Toys::Middleware do
  describe ".spec" do
    it "handles a string name with no arguments" do
      spec = Toys::Middleware.spec("hello")
      assert_nil(spec.object)
      assert_equal("hello", spec.name)
      assert_empty(spec.args)
      assert_empty(spec.kwargs)
      assert_nil(spec.block)
    end

    it "handles a symbol name with arguments" do
      spec = Toys::Middleware.spec(:hello, :ruby, :world, a: 1, b: 2) { :foo }
      assert_nil(spec.object)
      assert_equal(:hello, spec.name)
      assert_equal([:ruby, :world], spec.args)
      assert_equal({a: 1, b: 2}, spec.kwargs)
      assert_equal(:foo, spec.block.call)
    end

    it "handles a class name with no arguments" do
      spec = Toys::Middleware.spec(Toys::Middleware::Base)
      assert_nil(spec.object)
      assert_equal(Toys::Middleware::Base, spec.name)
      assert_empty(spec.args)
      assert_empty(spec.kwargs)
      assert_nil(spec.block)
    end

    it "handles an ordinary object" do
      spec = Toys::Middleware.spec(1)
      assert_equal(1, spec.object)
      assert_nil(spec.name)
      assert_nil(spec.args)
      assert_nil(spec.kwargs)
      assert_nil(spec.block)
    end
  end

  describe ".spec_from_array" do
    it "handles only a string name" do
      spec = Toys::Middleware.spec_from_array(["hello"])
      assert_nil(spec.object)
      assert_equal("hello", spec.name)
      assert_empty(spec.args)
      assert_empty(spec.kwargs)
      assert_nil(spec.block)
    end

    it "handles a symbol name and params out of order" do
      spec = Toys::Middleware.spec_from_array([:hello, proc { :ruby }, {a: 1, b: 2}, [:foo, :bar]])
      assert_nil(spec.object)
      assert_equal(:hello, spec.name)
      assert_equal([:foo, :bar], spec.args)
      assert_equal({a: 1, b: 2}, spec.kwargs)
      assert_equal(:ruby, spec.block.call)
    end

    it "handles a class name with repeated args" do
      spec = Toys::Middleware.spec_from_array([Toys::Middleware::Base, [:foo], [:bar, :baz]])
      assert_nil(spec.object)
      assert_equal(Toys::Middleware::Base, spec.name)
      assert_equal([:foo, :bar, :baz], spec.args)
      assert_empty(spec.kwargs)
      assert_nil(spec.block)
    end

    it "handles a class name with repeated kwargs" do
      spec = Toys::Middleware.spec_from_array([Toys::Middleware::Base, {a: 1, b: 2}, {c: 3}])
      assert_nil(spec.object)
      assert_equal(Toys::Middleware::Base, spec.name)
      assert_empty(spec.args)
      assert_equal({a: 1, b: 2, c: 3}, spec.kwargs)
      assert_nil(spec.block)
    end

    it "errors on illegal name" do
      assert_raises(ArgumentError) do
        Toys::Middleware.spec_from_array([1])
      end
    end

    it "errors on illegal param" do
      assert_raises(ArgumentError) do
        Toys::Middleware.spec_from_array([:hello, 1])
      end
    end
  end

  describe "::Spec" do
    describe "#build" do
      let(:standard_lookup) { Toys::CLI.default_middleware_lookup }

      it "builds a standard middleware by name" do
        spec = Toys::Middleware.spec(:show_root_version, version_string: "hi")
        middleware = spec.build(standard_lookup)
        assert_instance_of(Toys::StandardMiddleware::ShowRootVersion, middleware)
      end

      it "fails to build middleware by name when no lookup is provided" do
        spec = Toys::Middleware.spec(:show_root_version, version_string: "hi")
        assert_raises(NameError) do
          spec.build(nil)
        end
      end

      it "builds base middleware by class even though there is no initialize method" do
        spec = Toys::Middleware.spec(Toys::Middleware::Base)
        middleware = spec.build(nil)
        assert_instance_of(Toys::Middleware::Base, middleware)
      end
    end
  end
end
