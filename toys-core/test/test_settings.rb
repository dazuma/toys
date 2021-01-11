# frozen_string_literal: true

require "helper"

module Toys
  module TestFixtures
    class Settings1 < Toys::Settings
      class FooSettings < Toys::Settings
        class BarSettings < Toys::Settings
          settings_attr(:baz)
        end
      end

      class QuxSettings < Toys::Settings
        settings_attr(:ho)
      end
    end
  end
end

describe Toys::Settings do
  settings_class_number = 0

  let(:settings_class_name) do
    settings_class_number += 1
    "A#{settings_class_number}"
  end
  let(:settings_class) do
    klass = Class.new(Toys::Settings)
    Object.const_set(settings_class_name, klass)
    klass
  end
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
        err = assert_raises(Toys::Settings::FieldError) do
          settings.foo = nil
        end
        assert_equal(
          "unable to set #{settings_class_name}#foo: value nil does not match type [true, false]",
          err.message
        )
        settings.foo_unset!
        assert_same(false, settings.foo)
      end

      it "matches string defaults" do
        settings_class.settings_attr(:foo, default: "abc")
        assert_equal("abc", settings.foo)
        settings.foo = "hi"
        assert_equal("hi", settings.foo)
        err = assert_raises(Toys::Settings::FieldError) do
          settings.foo = nil
        end
        assert_equal(
          "unable to set #{settings_class_name}#foo: value nil does not match type String",
          err.message
        )
        settings.foo_unset!
        assert_equal("abc", settings.foo)
      end

      it "matches class type spec" do
        settings_class.settings_attr(:foo, type: Numeric, default: 0)
        assert_equal(0, settings.foo)
        settings.foo = 3
        assert_equal(3, settings.foo)
        settings.foo = 3.14
        assert_equal(3.14, settings.foo)
        err = assert_raises(Toys::Settings::FieldError) do
          settings.foo = nil
        end
        assert_equal(
          "unable to set #{settings_class_name}#foo: value nil does not match type Numeric",
          err.message
        )
        err = assert_raises(Toys::Settings::FieldError) do
          settings.foo = "3"
        end
        assert_equal(
          "unable to set #{settings_class_name}#foo: value \"3\" does not match type Numeric",
          err.message
        )
        settings.foo_unset!
        assert_equal(0, settings.foo)
      end

      it "matches and converts to String type spec" do
        settings_class.settings_attr(:foo, type: String, default: "")
        assert_equal("", settings.foo)
        settings.foo = "bar"
        assert_equal("bar", settings.foo)
        err = assert_raises(Toys::Settings::FieldError) do
          settings.foo = nil
        end
        assert_equal(
          "unable to set #{settings_class_name}#foo: value nil does not match type String",
          err.message
        )
        settings.foo_unset!
        assert_equal("", settings.foo)
      end

      it "matches and converts to Symbol type spec" do
        settings_class.settings_attr(:foo, type: Symbol, default: :hello)
        assert_equal(:hello, settings.foo)
        settings.foo = :hi
        assert_equal(:hi, settings.foo)
        settings.foo = "ho"
        assert_equal(:ho, settings.foo)
        err = assert_raises(Toys::Settings::FieldError) do
          settings.foo = nil
        end
        assert_equal(
          "unable to set #{settings_class_name}#foo: value nil does not match type Symbol",
          err.message
        )
        settings.foo_unset!
        assert_equal(:hello, settings.foo)
      end

      it "matches and converts to Integer type spec" do
        settings_class.settings_attr(:foo, type: Integer, default: 0)
        assert_equal(0, settings.foo)
        settings.foo = -1
        assert_equal(-1, settings.foo)
        settings.foo = "321"
        assert_equal(321, settings.foo)
        settings.foo = 3.0
        assert_equal(3, settings.foo)
        err = assert_raises(Toys::Settings::FieldError) do
          settings.foo = 3.14
        end
        assert_equal(
          "unable to set #{settings_class_name}#foo: value 3.14 does not match type Integer",
          err.message
        )
        settings.foo_unset!
        assert_equal(0, settings.foo)
      end

      it "matches and converts to Float type spec" do
        settings_class.settings_attr(:foo, type: Float, default: 0.0)
        assert_equal(0.0, settings.foo)
        assert_kind_of(Float, settings.foo)
        settings.foo = -1.5
        assert_equal(-1.5, settings.foo)
        settings.foo = "321"
        assert_equal(321.0, settings.foo)
        assert_kind_of(Float, settings.foo)
        settings.foo = -1
        assert_equal(-1.0, settings.foo)
        assert_kind_of(Float, settings.foo)
        err = assert_raises(Toys::Settings::FieldError) do
          settings.foo = :hi
        end
        assert_equal(
          "unable to set #{settings_class_name}#foo: value :hi does not match type Float",
          err.message
        )
        settings.foo_unset!
        assert_equal(0.0, settings.foo)
        assert_kind_of(Float, settings.foo)
      end

      it "matches and converts to Regexp type spec" do
        settings_class.settings_attr(:foo, type: Regexp, default: "")
        assert_equal(//, settings.foo)
        settings.foo = /abc/
        assert_equal(/abc/, settings.foo)
        settings.foo = "def"
        assert_equal(/def/, settings.foo)
        err = assert_raises(Toys::Settings::FieldError) do
          settings.foo = :abc
        end
        assert_equal(
          "unable to set #{settings_class_name}#foo: value :abc does not match type Regexp",
          err.message
        )
        settings.foo_unset!
        assert_equal(//, settings.foo)
      end

      it "matches integer range type spec" do
        settings_class.settings_attr(:foo, type: 1..5, default: 3)
        assert_equal(3, settings.foo)
        settings.foo = 1
        assert_equal(1, settings.foo)
        settings.foo = "2"
        assert_equal(2, settings.foo)
        err = assert_raises(Toys::Settings::FieldError) do
          settings.foo = nil
        end
        assert_equal(
          "unable to set #{settings_class_name}#foo: value nil does not match type (1..5)",
          err.message
        )
        err = assert_raises(Toys::Settings::FieldError) do
          settings.foo = 6
        end
        assert_equal(
          "unable to set #{settings_class_name}#foo: value 6 does not match type (1..5)",
          err.message
        )
        settings.foo_unset!
        assert_equal(3, settings.foo)
      end

      it "matches regex type spec" do
        settings_class.settings_attr(:foo, type: /^\w+$/, default: "a")
        assert_equal("a", settings.foo)
        settings.foo = "b_2"
        assert_equal("b_2", settings.foo)
        err = assert_raises(Toys::Settings::FieldError) do
          settings.foo = nil
        end
        assert_equal(
          "unable to set #{settings_class_name}#foo: value nil does not match type /^\\w+$/",
          err.message
        )
        err = assert_raises(Toys::Settings::FieldError) do
          settings.foo = ":"
        end
        assert_equal(
          "unable to set #{settings_class_name}#foo: value \":\" does not match type /^\\w+$/",
          err.message
        )
        settings.foo_unset!
        assert_equal("a", settings.foo)
      end

      it "matches scalar type spec" do
        settings_class.settings_attr(:foo, type: nil)
        assert_nil(settings.foo)
        settings.foo = nil
        assert_nil(settings.foo)
        err = assert_raises(Toys::Settings::FieldError) do
          settings.foo = 0
        end
        assert_equal(
          "unable to set #{settings_class_name}#foo: value 0 does not match type nil",
          err.message
        )
        settings.foo_unset!
        assert_nil(settings.foo)
      end

      it "matches union type spec" do
        settings_class.settings_attr(:foo, type: [:a, :b, Integer, "4", nil])
        assert_nil(settings.foo)
        settings.foo = :b
        assert_equal(:b, settings.foo)
        settings.foo = nil
        assert_nil(settings.foo)
        settings.foo = 3
        assert_equal(3, settings.foo)
        settings.foo = "4"
        assert_equal("4", settings.foo)
        settings.foo = "5"
        assert_equal(5, settings.foo)
        err = assert_raises(Toys::Settings::FieldError) do
          settings.foo = :c
        end
        assert_equal(
          "unable to set #{settings_class_name}#foo:" \
            " value :c does not match type [:a, :b, Integer, \"4\", nil]",
          err.message
        )
        settings.foo_unset!
        assert_nil(settings.foo)
      end

      it "recognizes a block type spec" do
        settings_class.settings_attr(:foo, default: 0) do |val|
          val >= 0 ? val : Toys::Settings::ILLEGAL_VALUE
        end
        assert_equal(0, settings.foo)
        settings.foo = 0.1
        assert_equal(0.1, settings.foo)
        err = assert_raises(Toys::Settings::FieldError) do
          settings.foo = -1
        end
        assert_equal(
          "unable to set #{settings_class_name}#foo: value -1 does not match type (opaque proc)",
          err.message
        )
        settings.foo_unset!
        assert_equal(0, settings.foo)
      end

      it "checks the default against the type spec" do
        err = assert_raises(Toys::Settings::FieldError) do
          settings_class.settings_attr(:foo, type: Symbol)
        end
        assert_equal(
          "unable to set #{settings_class_name}#foo: value nil does not match type Symbol",
          err.message
        )
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
        child_settings = settings_class.new(parent: settings)
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
        child_settings = child_class.new(parent: settings)
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
        child_settings = child_class.new(parent: settings)
        assert_equal(0, child_settings.foo)
        child_settings.foo = 1
        assert_equal(1, child_settings.foo)
        child_settings.foo_unset!
        assert_equal(0, child_settings.foo)
      end

      it "searches through undefined parents" do
        settings_class.settings_attr(:foo, default: "default")
        child_settings = child_class.new(parent: settings)
        grandchild_settings = settings_class.new(parent: child_settings)
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
      assert_equal("#{settings_class_name}::Foo", settings.foo.class.name)
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
        child_settings = settings_class.new(parent: settings)
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
        child_settings = child_class.new(parent: settings)
        assert_equal("default", child_settings.foo.bar)
        child_settings.foo.bar = "bye"
        assert_equal("bye", child_settings.foo.bar)
        child_settings.foo.bar_unset!
        assert_equal("default", child_settings.foo.bar)
      end

      it "searches through undefined parents" do
        settings_class.settings_group(:foo, group_class)
        child_settings = child_class.new(parent: settings)
        grandchild_settings = settings_class.new(parent: child_settings)
        settings.foo.bar = "hi"
        assert_equal("hi", grandchild_settings.foo.bar)
      end

      it "searches through parent fields of the wrong type" do
        child_class.settings_attr(:foo)
        settings_class.settings_group(:foo, group_class)
        child_settings = child_class.new(parent: settings)
        grandchild_settings = settings_class.new(parent: child_settings)
        child_settings.foo = "yo"
        settings.foo.bar = "hi"
        assert_equal("hi", grandchild_settings.foo.bar)
      end

      it "stops searching parents at an explicit nil" do
        child_class.settings_attr(:foo)
        settings_class.settings_group(:foo, group_class)
        child_settings = child_class.new(parent: settings)
        grandchild_settings = settings_class.new(parent: child_settings)
        child_settings.foo = nil
        settings.foo.bar = "hi"
        assert_equal("default", grandchild_settings.foo.bar)
      end

      it "recognizes a parent field of type Settings" do
        child_class.settings_attr(:foo)
        settings_class.settings_group(:foo, group_class)
        child_settings = child_class.new(parent: settings)
        grandchild_settings = settings_class.new(parent: child_settings)
        child_subsettings = group_class.new
        child_subsettings.bar = "yo"
        child_settings.foo = child_subsettings
        settings.foo.bar = "hi"
        assert_equal("yo", grandchild_settings.foo.bar)
      end
    end
  end

  describe "auto-hierarchy" do
    it "builds the hierarchy based on nesting" do
      settings = Toys::TestFixtures::Settings1.new
      assert_respond_to(settings, :foo_settings)
      assert_respond_to(settings.foo_settings, :bar_settings)
      assert_respond_to(settings.foo_settings.bar_settings, :baz)
      assert_respond_to(settings, :qux_settings)
      assert_respond_to(settings.qux_settings, :ho)
    end
  end

  describe "data loading" do
    it "loads a simple hash" do
      settings_class.settings_attr(:foo)
      settings_class.settings_attr(:bar)
      errors = settings.load_data!({ "foo" => "hello" })
      assert_empty(errors)
      assert_equal("hello", settings.foo)
      assert_nil(settings.bar)
    end

    it "converts values" do
      settings_class.settings_attr(:foo, default: 0)
      settings_class.settings_attr(:bar, default: //)
      errors = settings.load_data!({ "foo" => "123", "bar" => "abc" })
      assert_empty(errors)
      assert_equal(123, settings.foo)
      assert_equal(/abc/, settings.bar)
    end

    it "detects type errors" do
      settings_class.settings_attr(:foo, default: 0)
      settings_class.settings_attr(:bar, type: /[a-z]+/, default: "a")
      errors = settings.load_data!({ "foo" => "123", "bar" => "123" })
      assert_equal(1, errors.size)
      assert_equal(
        "unable to set #{settings_class_name}#bar: value \"123\" does not match type /[a-z]+/",
        errors.first.message
      )
      assert_equal(123, settings.foo)
      assert_equal("a", settings.bar)
    end

    it "detects field mismatch" do
      settings_class.settings_attr(:foo, default: 0)
      settings_class.settings_attr(:bar, type: /[a-z]+/, default: "a")
      errors = settings.load_data!({ "foo" => "123", "baz" => "123" })
      assert_equal(1, errors.size)
      assert_equal(
        "unable to set #{settings_class_name}#baz: field does not exist",
        errors.first.message
      )
      assert_equal(123, settings.foo)
      assert_equal("a", settings.bar)
    end

    it "loads a nested hash" do
      settings_class.class_eval do
        settings_group(:foo) do
          settings_attr(:bar, default: 0)
        end
      end
      errors = settings.load_data!({ "foo" => { "bar" => "123" } })
      assert_empty(errors)
      assert_equal(123, settings.foo.bar)
    end

    it "detects nested hash mismatch" do
      settings_class.class_eval do
        settings_group(:foo) do
          settings_attr(:bar, default: 0)
        end
      end
      errors = settings.load_data!({ "foo" => "123" })
      assert_equal(1, errors.size)
      assert_equal(
        "unable to set #{settings_class_name}#foo: value \"123\" does not match type Hash",
        errors.first.message
      )
    end

    it "loads a YAML string" do
      settings_class.settings_attr(:foo)
      settings_class.settings_attr(:bar)
      errors = settings.load_yaml!("foo: hello")
      assert_empty(errors)
      assert_equal("hello", settings.foo)
      assert_nil(settings.bar)
    end

    it "loads a JSON string" do
      settings_class.settings_attr(:foo)
      settings_class.settings_attr(:bar)
      errors = settings.load_json!('{"foo": "hello"}')
      assert_empty(errors)
      assert_equal("hello", settings.foo)
      assert_nil(settings.bar)
    end

    it "loads a YAML file" do
      settings_class.settings_attr(:foo)
      settings_class.settings_attr(:bar)
      errors = settings.load_yaml_file!(File.join(__dir__, "settings", "input.yaml"))
      assert_empty(errors)
      assert_equal("hello", settings.foo)
      assert_nil(settings.bar)
    end

    it "loads a JSON file" do
      settings_class.settings_attr(:foo)
      settings_class.settings_attr(:bar)
      errors = settings.load_json_file!(File.join(__dir__, "settings", "input.json"))
      assert_empty(errors)
      assert_equal("hello", settings.foo)
      assert_nil(settings.bar)
    end
  end
end
