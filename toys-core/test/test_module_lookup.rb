# frozen_string_literal: true

require "helper"

describe Toys::ModuleLookup do
  describe "to_path_name" do
    it "handles camel case" do
      result = Toys::ModuleLookup.to_path_name("Hello1World")
      assert_equal("hello1_world", result)
    end

    it "handles caps" do
      result = Toys::ModuleLookup.to_path_name("CLI")
      assert_equal("c_l_i", result)
    end

    it "handles existing underscores" do
      result = Toys::ModuleLookup.to_path_name("_Hello_Ruby__World_today_")
      assert_equal("hello_ruby_world_today", result)
    end

    it "handles symbols" do
      result = Toys::ModuleLookup.to_path_name(:HelloWorld)
      assert_equal("hello_world", result)
    end
  end

  describe "to_module_name" do
    it "handles snake case" do
      result = Toys::ModuleLookup.to_module_name("hello_world")
      assert_equal(:HelloWorld, result)
    end

    it "handles caps" do
      result = Toys::ModuleLookup.to_module_name("c_l_i")
      assert_equal(:CLI, result)
    end

    it "handles extra underscores" do
      result = Toys::ModuleLookup.to_module_name("_hello__world_")
      assert_equal(:HelloWorld, result)
    end

    it "handles non-character word starts" do
      result = Toys::ModuleLookup.to_module_name("hello_1world")
      assert_equal(:Hello_1world, result)
    end
  end

  describe "path_to_module" do
    it "looks up an existing module" do
      mod = Toys::ModuleLookup.path_to_module("toys/standard_mixins")
      assert_equal("Toys::StandardMixins", mod.name)
    end

    it "raises on a nonexisting module" do
      assert_raises(::NameError) do
        Toys::ModuleLookup.path_to_module("toys/blah_blah_blah")
      end
    end
  end

  describe "standard_mixins lookup" do
    let(:module_lookup) { Toys::ModuleLookup.new.add_path("toys/standard_mixins") }

    it "looks up a module" do
      assert_equal("Toys::StandardMixins::Exec", module_lookup.lookup(:exec).name)
    end

    it "does not find toplevel modules" do
      assert_nil(module_lookup.lookup(:object))
    end
  end
end
