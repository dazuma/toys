# frozen_string_literal: true

require "helper"

describe Toys::Mixin do
  it "provides module methods" do
    mod = Toys::Mixin.create
    assert_equal(true, mod.respond_to?(:on_initialize))
    assert_equal(true, mod.respond_to?(:initializer))
    assert_equal(true, mod.respond_to?(:initializer=))
    assert_equal(true, mod.respond_to?(:on_include))
    assert_equal(true, mod.respond_to?(:inclusion))
    assert_equal(true, mod.respond_to?(:inclusion=))
  end

  it "allows block configuration" do
    mod = Toys::Mixin.create do
      def mithrandir
        :mithrandir
      end
      on_initialize do
        :gandalf
      end
      on_include do
        :frodo
      end
    end
    assert_equal(:gandalf, mod.initializer.call)
    assert_equal(:frodo, mod.inclusion.call)
    klass = ::Class.new do
      include mod
    end
    assert_equal(:mithrandir, klass.new.mithrandir)
  end
end
