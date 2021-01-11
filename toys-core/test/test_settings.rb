# frozen_string_literal: true

require "helper"

describe Toys::Settings do
  let(:settings_class) { Class.new(Toys::Settings) }
  let(:settings) { settings_class.new }

  describe "attribute" do
    it "defines an attribute" do
      settings_class.settings_attr(:foo)
      assert_nil(settings.foo)
      refute(settings.foo_set?)
      settings.foo = "hi"
      assert_equal("hi", settings.foo)
      assert(settings.foo_set?)
      settings.foo_unset!
      assert_nil(settings.foo)
      refute(settings.foo_set?)
    end

    it "uses defaults" do
      settings_class.settings_attr(:foo, default: "hi")
      assert_equal("hi", settings.foo)
      refute(settings.foo_set?)
      settings.foo = "bye"
      assert_equal("bye", settings.foo)
      assert(settings.foo_set?)
      settings.foo_unset!
      assert_equal("hi", settings.foo)
      refute(settings.foo_set?)
    end

    it "catches illegal attribute names" do
      err = assert_raises(::ArgumentError) do
        settings_class.settings_attr(:_underscore)
      end
      assert_equal("Illegal settings field name: _underscore", err.message)
      err = assert_raises(::ArgumentError) do
        settings_class.settings_attr(:method_missing)
      end
      assert_equal("Illegal settings field name: method_missing", err.message)
    end

    it "catches duplicate attribute names" do
      settings_class.settings_attr(:foo_bar)
      err = assert_raises(::ArgumentError) do
        settings_class.settings_attr(:foo_bar)
      end
      assert_equal("Settings field already exists: foo_bar", err.message)
    end

    describe "type specification" do
      it "matches nil defaults" do
        settings_class.settings_attr(:foo)
        obj = Object.new
        settings.foo = obj
        assert_same(obj, settings.foo)
        settings.foo = nil
        assert_nil(settings.foo)
        assert(settings.foo_set?)
      end

      it "matches boolean defaults" do
        settings_class.settings_attr(:foo, default: false)
        assert_same(false, settings.foo)
        settings.foo = true
        assert_same(true, settings.foo)
        settings.foo = false
        assert_same(false, settings.foo)
        err = assert_raises(::ArgumentError) do
          settings.foo = nil
        end
        assert_equal("Value nil does not match type [true, false] for settings field foo",
                     err.message)
        settings.foo_unset!
        assert_same(false, settings.foo)
      end

      it "matches string defaults" do
        settings_class.settings_attr(:foo, default: "")
        assert_equal("", settings.foo)
        settings.foo = "hi"
        assert_equal("hi", settings.foo)
        err = assert_raises(::ArgumentError) do
          settings.foo = nil
        end
        assert_equal("Value nil does not match type String for settings field foo", err.message)
        err = assert_raises(::ArgumentError) do
          settings.foo = :hi
        end
        assert_equal("Value :hi does not match type String for settings field foo", err.message)
        settings.foo_unset!
        assert_equal("", settings.foo)
      end

      it "matches class type spec" do
        settings_class.settings_attr(:foo, type: Numeric, default: 0)
        assert_equal(0, settings.foo)
        settings.foo = 3
        assert_equal(3, settings.foo)
        settings.foo = 3.14
        assert_equal(3.14, settings.foo)
        err = assert_raises(::ArgumentError) do
          settings.foo = nil
        end
        assert_equal("Value nil does not match type Numeric for settings field foo", err.message)
        err = assert_raises(::ArgumentError) do
          settings.foo = "3"
        end
        assert_equal("Value \"3\" does not match type Numeric for settings field foo", err.message)
        settings.foo_unset!
        assert_equal(0, settings.foo)
      end

      it "matches integer range type spec" do
        settings_class.settings_attr(:foo, type: 1..5, default: 3)
        assert_equal(3, settings.foo)
        settings.foo = 1
        assert_equal(1, settings.foo)
        err = assert_raises(::ArgumentError) do
          settings.foo = nil
        end
        assert_equal("Value nil does not match type (1..5) for settings field foo", err.message)
        err = assert_raises(::ArgumentError) do
          settings.foo = 6
        end
        assert_equal("Value 6 does not match type (1..5) for settings field foo", err.message)
        settings.foo_unset!
        assert_equal(3, settings.foo)
      end

      it "matches regex type spec" do
        settings_class.settings_attr(:foo, type: /^\w+$/, default: "a")
        assert_equal("a", settings.foo)
        settings.foo = "b_2"
        assert_equal("b_2", settings.foo)
        err = assert_raises(::ArgumentError) do
          settings.foo = nil
        end
        assert_equal("Value nil does not match type /^\\w+$/ for settings field foo", err.message)
        err = assert_raises(::ArgumentError) do
          settings.foo = ":"
        end
        assert_equal("Value \":\" does not match type /^\\w+$/ for settings field foo", err.message)
        settings.foo_unset!
        assert_equal("a", settings.foo)
      end

      it "matches scalar type spec" do
        settings_class.settings_attr(:foo, type: nil)
        assert_nil(settings.foo)
        settings.foo = nil
        assert_nil(settings.foo)
        err = assert_raises(::ArgumentError) do
          settings.foo = 0
        end
        assert_equal("Value 0 does not match type nil for settings field foo", err.message)
        settings.foo_unset!
        assert_nil(settings.foo)
      end

      it "matches union type spec" do
        settings_class.settings_attr(:foo, type: [:a, :b, String, nil])
        assert_nil(settings.foo)
        settings.foo = :b
        assert_equal(:b, settings.foo)
        settings.foo = nil
        assert_nil(settings.foo)
        settings.foo = "b"
        assert_equal("b", settings.foo)
        err = assert_raises(::ArgumentError) do
          settings.foo = :c
        end
        assert_equal("Value :c does not match type [:a, :b, String, nil] for settings field foo",
                     err.message)
        settings.foo_unset!
        assert_nil(settings.foo)
      end

      it "recognizes a block type spec" do
        settings_class.settings_attr(:foo, default: 0) { |val| val >= 0 }
        assert_equal(0, settings.foo)
        settings.foo = 0.1
        assert_equal(0.1, settings.foo)
        err = assert_raises(::ArgumentError) do
          settings.foo = -1
        end
        assert_equal("Value -1 does not match type (opaque function) for settings field foo",
                     err.message)
        settings.foo_unset!
        assert_equal(0, settings.foo)
      end

      it "checks the default against the type spec" do
        err = assert_raises(::ArgumentError) do
          settings_class.settings_attr(:foo, type: String)
        end
        assert_equal("Default value nil does not match type String for settings field foo",
                     err.message)
      end

      it "errors on illegal type spec" do
        err = assert_raises(::ArgumentError) do
          settings_class.settings_attr(:foo, type: {})
        end
        assert_equal("Illegal type spec: {}", err.message)
      end
    end

    describe "parentage" do
      let(:child_class) { Class.new(Toys::Settings) }

      it "defines a fallback" do
        settings_class.settings_attr(:foo, default: "default")
        settings.foo = "hi"
        child_settings = settings_class.new(settings)
        assert_equal("hi", child_settings.foo)
        child_settings.foo = "bye"
        assert_equal("bye", child_settings.foo)
        child_settings.foo_unset!
        assert_equal("hi", child_settings.foo)
        settings.foo_unset!
        assert_equal("default", child_settings.foo)
      end

      it "checks that the parent attribute is defined" do
        child_class.settings_attr(:foo, default: "default")
        child_settings = child_class.new(settings)
        refute_respond_to(settings, :foo)
        assert_respond_to(child_settings, :foo)
        assert_equal("default", child_settings.foo)
        child_settings.foo = "bye"
        assert_equal("bye", child_settings.foo)
        child_settings.foo_unset!
        assert_equal("default", child_settings.foo)
      end

      it "checks that the parent attribute type matches" do
        settings_class.settings_attr(:foo, default: "default")
        child_class.settings_attr(:foo, default: 0)
        child_settings = child_class.new(settings)
        assert_equal(0, child_settings.foo)
        child_settings.foo = 1
        assert_equal(1, child_settings.foo)
        child_settings.foo_unset!
        assert_equal(0, child_settings.foo)
      end

      it "searches through undefined parents" do
        settings_class.settings_attr(:foo, default: "default")
        child_settings = child_class.new(settings)
        grandchild_settings = settings_class.new(child_settings)
        settings.foo = "hi"
        assert_equal("hi", grandchild_settings.foo)
      end
    end
  end

  describe "group" do
    let(:group_class) do
      Class.new(Toys::Settings) do
        settings_attr(:bar, default: "default")
      end
    end

    it "defines a group" do
      settings_class.settings_group(:foo, group_class)
      assert_kind_of(group_class, settings.foo)
      assert_equal("default", settings.foo.bar)
      settings.foo.bar = "hi"
      assert_equal("hi", settings.foo.bar)
    end

    it "defines an anonymous group" do
      settings_class.settings_group(:foo) do
        settings_attr(:bar, default: "default")
      end
      assert_equal("default", settings.foo.bar)
      settings.foo.bar = "hi"
      assert_equal("hi", settings.foo.bar)
    end

    it "catches illegal group names" do
      err = assert_raises(::ArgumentError) do
        settings_class.settings_group(:_underscore, group_class)
      end
      assert_equal("Illegal settings field name: _underscore", err.message)
      err = assert_raises(::ArgumentError) do
        settings_class.settings_group(:method_missing, group_class)
      end
      assert_equal("Illegal settings field name: method_missing", err.message)
    end

    it "catches duplicate group names" do
      settings_class.settings_attr(:foo_bar)
      err = assert_raises(::ArgumentError) do
        settings_class.settings_group(:foo_bar, group_class)
      end
      assert_equal("Settings field already exists: foo_bar", err.message)
    end

    describe "parentage" do
      let(:child_class) { Class.new(Toys::Settings) }

      it "uses group's parent" do
        settings_class.settings_group(:foo, group_class)
        settings.foo.bar = "hi"
        child_settings = settings_class.new(settings)
        assert_equal("hi", child_settings.foo.bar)
        child_settings.foo.bar = "bye"
        assert_equal("bye", child_settings.foo.bar)
        child_settings.foo.bar_unset!
        assert_equal("hi", child_settings.foo.bar)
        settings.foo.bar_unset!
        assert_equal("default", child_settings.foo.bar)
      end

      it "checks whether the parent has the group" do
        settings_class.settings_attr(:foo, default: "default")
        child_class.settings_group(:foo, group_class)
        child_settings = child_class.new(settings)
        assert_equal("default", child_settings.foo.bar)
        child_settings.foo.bar = "bye"
        assert_equal("bye", child_settings.foo.bar)
        child_settings.foo.bar_unset!
        assert_equal("default", child_settings.foo.bar)
      end

      it "searches through undefined parents" do
        settings_class.settings_group(:foo, group_class)
        child_settings = child_class.new(settings)
        grandchild_settings = settings_class.new(child_settings)
        settings.foo.bar = "hi"
        assert_equal("hi", grandchild_settings.foo.bar)
      end

      it "searches through parent fields of the wrong type" do
        child_class.settings_attr(:foo)
        settings_class.settings_group(:foo, group_class)
        child_settings = child_class.new(settings)
        grandchild_settings = settings_class.new(child_settings)
        child_settings.foo = "yo"
        settings.foo.bar = "hi"
        assert_equal("hi", grandchild_settings.foo.bar)
      end

      it "stops searching parents at an explicit nil" do
        child_class.settings_attr(:foo)
        settings_class.settings_group(:foo, group_class)
        child_settings = child_class.new(settings)
        grandchild_settings = settings_class.new(child_settings)
        child_settings.foo = nil
        settings.foo.bar = "hi"
        assert_equal("default", grandchild_settings.foo.bar)
      end

      it "recognizes a parent field of type Settings" do
        child_class.settings_attr(:foo)
        settings_class.settings_group(:foo, group_class)
        child_settings = child_class.new(settings)
        grandchild_settings = settings_class.new(child_settings)
        child_subsettings = group_class.new
        child_subsettings.bar = "yo"
        child_settings.foo = child_subsettings
        settings.foo.bar = "hi"
        assert_equal("yo", grandchild_settings.foo.bar)
      end
    end
  end

  describe "auto-hierarchy" do
    class TestSettings < Toys::Settings
      class FooSettings < Toys::Settings
        class BarSettings < Toys::Settings
          settings_attr(:baz)
        end
      end
      class QuxSettings < Toys::Settings
        settings_attr(:ho)
      end
    end

    it "builds the hierarchy based on nesting" do
      settings = TestSettings.new
      assert_respond_to(settings, :foo_settings)
      assert_respond_to(settings.foo_settings, :bar_settings)
      assert_respond_to(settings.foo_settings.bar_settings, :baz)
      assert_respond_to(settings, :qux_settings)
      assert_respond_to(settings.qux_settings, :ho)
    end
  end
end
