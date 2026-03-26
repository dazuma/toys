# frozen_string_literal: true

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

    it "passes through an existing spec unchanged" do
      spec = Toys::Middleware.spec("hello")
      assert_same(spec, Toys::Middleware.spec(spec))
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

      it "returns a wrapped object directly without constructing a new one" do
        obj = Toys::Middleware::Base.new
        spec = Toys::Middleware.spec(obj)
        assert_same(obj, spec.build(nil))
      end
    end

    describe "equality" do
      let(:my_block) { proc { :foo } }
      let(:spec) { Toys::Middleware.spec(:hello, :a, :b, x: 1, y: 2, &my_block) }

      it "equals another spec with identical fields" do
        assert_equal(spec, Toys::Middleware.spec(:hello, :a, :b, x: 1, y: 2, &my_block))
      end

      it "is not equal to a spec with a different name" do
        refute_equal(spec, Toys::Middleware.spec(:world, :a, :b, x: 1, y: 2, &my_block))
      end

      it "is not equal to a spec with different args" do
        refute_equal(spec, Toys::Middleware.spec(:hello, :c, x: 1, y: 2, &my_block))
      end

      it "is not equal to a spec with different kwargs" do
        refute_equal(spec, Toys::Middleware.spec(:hello, :a, :b, x: 9, y: 2, &my_block))
      end

      it "is not equal to a spec with a different block" do
        refute_equal(spec, Toys::Middleware.spec(:hello, :a, :b, x: 1, y: 2) { :bar })
      end

      it "is not equal to a spec with no block" do
        refute_equal(spec, Toys::Middleware.spec(:hello, :a, :b, x: 1, y: 2))
      end

      it "equals an object-wrapping spec wrapping the same object" do
        obj = Toys::Middleware::Base.new
        assert_equal(Toys::Middleware.spec(obj), Toys::Middleware.spec(obj))
      end

      it "is not equal to a non-Spec" do
        refute_equal(spec, "hello")
      end

      it "has a hash consistent with equality" do
        assert_equal(spec.hash, Toys::Middleware.spec(:hello, :a, :b, x: 1, y: 2, &my_block).hash)
      end
    end
  end

  describe "::Stack" do
    describe "Middleware.stack" do
      it "creates a stack from an array, placing specs as default_specs" do
        spec = Toys::Middleware.spec(Toys::Middleware::Base)
        stack = Toys::Middleware.stack([spec])
        assert_instance_of(Toys::Middleware::Stack, stack)
        assert_equal([spec], stack.default_specs)
        assert_empty(stack.pre_specs)
        assert_empty(stack.post_specs)
      end

      it "normalizes raw array entries in the input" do
        stack = Toys::Middleware.stack([[Toys::Middleware::Base]])
        assert_equal(1, stack.default_specs.size)
        assert_equal(Toys::Middleware::Base, stack.default_specs.first.name)
      end

      it "passes through an existing stack unchanged" do
        stack = Toys::Middleware.stack([])
        assert_same(stack, Toys::Middleware.stack(stack))
      end

      it "raises on non-array, non-Stack input" do
        assert_raises(ArgumentError) do
          Toys::Middleware.stack("bad")
        end
      end
    end

    describe "#add" do
      let(:stack) { Toys::Middleware.stack([Toys::Middleware.spec(Toys::Middleware::Base)]) }

      it "appends to pre_specs" do
        stack.add(Toys::Middleware::Base)
        assert_equal(1, stack.pre_specs.size)
      end

      it "does not modify default_specs" do
        stack.add(Toys::Middleware::Base)
        assert_equal(1, stack.default_specs.size)
      end

      it "does not modify post_specs" do
        stack.add(Toys::Middleware::Base)
        assert_empty(stack.post_specs)
      end

      it "accepts the same argument forms as Middleware.spec" do
        stack.add(:show_root_version, version_string: "1.0")
        assert_equal(:show_root_version, stack.pre_specs.first.name)
        assert_equal({version_string: "1.0"}, stack.pre_specs.first.kwargs)
      end
    end

    describe "#build" do
      it "returns built middleware in pre, default, post order" do
        pre_mw = Toys::Middleware::Base.new
        default_mw = Toys::Middleware::Base.new
        post_mw = Toys::Middleware::Base.new
        stack = Toys::Middleware::Stack.new(
          pre_specs: [Toys::Middleware.spec(pre_mw)],
          default_specs: [Toys::Middleware.spec(default_mw)],
          post_specs: [Toys::Middleware.spec(post_mw)]
        )
        assert_equal([pre_mw, default_mw, post_mw], stack.build(nil))
      end

      it "returns an empty array for an empty stack" do
        assert_empty(Toys::Middleware.stack([]).build(nil))
      end
    end

    describe "#dup" do
      let(:spec) { Toys::Middleware.spec(Toys::Middleware::Base) }
      let(:stack) { Toys::Middleware.stack([spec]) }
      let(:duped) { stack.dup }

      it "returns a different object" do
        refute_same(stack, duped)
      end

      it "has the same default_specs content" do
        assert_equal(stack.default_specs, duped.default_specs)
      end

      it "has an independent pre_specs array" do
        duped.pre_specs << spec
        assert_empty(stack.pre_specs)
      end

      it "has an independent default_specs array" do
        duped.default_specs << spec
        assert_equal(1, stack.default_specs.size)
      end

      it "has an independent post_specs array" do
        duped.post_specs << spec
        assert_empty(stack.post_specs)
      end
    end

    describe "equality" do
      let(:spec) { Toys::Middleware.spec(Toys::Middleware::Base) }

      it "equals a stack with the same default_specs" do
        assert_equal(Toys::Middleware.stack([spec]), Toys::Middleware.stack([spec]))
      end

      it "is not equal to a stack with different default_specs" do
        refute_equal(Toys::Middleware.stack([spec]), Toys::Middleware.stack([]))
      end

      it "is not equal when pre_specs differ" do
        stack1 = Toys::Middleware.stack([])
        stack2 = Toys::Middleware.stack([])
        stack1.add(Toys::Middleware::Base)
        refute_equal(stack1, stack2)
      end

      it "is not equal when post_specs differ" do
        stack1 = Toys::Middleware::Stack.new(post_specs: [spec])
        stack2 = Toys::Middleware::Stack.new
        refute_equal(stack1, stack2)
      end

      it "is not equal to a non-Stack" do
        refute_equal(Toys::Middleware.stack([]), [])
      end

      it "has a hash consistent with equality" do
        assert_equal(
          Toys::Middleware.stack([spec]).hash,
          Toys::Middleware.stack([spec]).hash
        )
      end
    end
  end
end
