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
