# frozen_string_literal: true

require "helper"

describe Toys::Template do
  it "provides class methods" do
    klass = Toys::Template.create
    assert_equal(true, klass.respond_to?(:on_expand))
    assert_equal(true, klass.respond_to?(:expansion))
    assert_equal(true, klass.respond_to?(:expansion=))
  end

  it "acts on inclusion" do
    klass = Class.new do
      include Toys::Template
      def mithrandir
        :mithrandir
      end
      on_expand do
        :gandalf
      end
    end
    assert_equal(:mithrandir, klass.new.mithrandir)
    assert_equal(:gandalf, klass.expansion.call)
  end

  it "allows block configuration" do
    klass = Toys::Template.create do
      def mithrandir
        :mithrandir
      end
      on_expand do
        :gandalf
      end
    end
    assert_equal(:mithrandir, klass.new.mithrandir)
    assert_equal(:gandalf, klass.expansion.call)
  end
end
