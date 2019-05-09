# frozen_string_literal: true

# Copyright 2018 Daniel Azuma
#
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice,
#   this list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# * Neither the name of the copyright holder, nor the names of any other
#   contributors to this software, may be used to endorse or promote products
#   derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
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
