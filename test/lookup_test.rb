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

describe Toys::Lookup do
  let(:lookup) {
    Toys::Lookup.new(config_dir_name: ".toys",
                     config_file_name: ".toys.rb",
                     index_file_name: ".toys.rb")
  }
  let(:cases_dir) {
    File.join(__dir__, "lookup-cases")
  }

  describe "config path with config items" do
    before do
      lookup.add_config_paths(File.join(cases_dir, "config-items"))
    end

    it "finds a tool directly defined in a config file" do
      tool = lookup.lookup(["tool-1"])
      tool.effective_desc.must_equal "file tool-1 short description"
      tool.effective_long_desc.must_equal "file tool-1 long description"
    end

    it "finds a subtool directly defined in a config file" do
      tool = lookup.lookup(["collection-1", "tool-1-1"])
      tool.effective_desc.must_equal "file tool-1-1 short description"
      tool.effective_long_desc.must_equal "file tool-1-1 long description"
      tool.full_name.must_equal ["collection-1", "tool-1-1"]
    end

    it "finds a collection directly defined in a config file" do
      tool = lookup.lookup(["collection-1"])
      tool.effective_desc.must_equal "file collection-1 short description"
      tool.full_name.must_equal ["collection-1"]
    end

    it "finds a tool defined in a file in a config directory" do
      tool = lookup.lookup(["tool-2"])
      tool.effective_desc.must_equal "directory tool-2 short description"
      tool.effective_long_desc.must_equal "directory tool-2 long description"
    end

    it "finds the nearest collection directly defined if a query doesn't match" do
      tool = lookup.lookup(["collection-1", "tool-blah"])
      tool.effective_desc.must_equal "file collection-1 short description"
      tool.full_name.must_equal ["collection-1"]
    end

    it "finds the root if a query has no toplevel match" do
      tool = lookup.lookup(["tool-blah"])
      tool.full_name.must_equal []
      tool.simple_name.must_be_nil
    end
  end

  describe "ordinary path with some hierarchical files" do
    before do
      lookup.add_paths(File.join(cases_dir, "normal-file-hierarchy"))
    end

    it "finds a tool directly defined" do
      tool = lookup.lookup(["tool-1"])
      tool.effective_desc.must_equal "normal tool-1 short description"
      tool.effective_long_desc.must_equal "normal tool-1 long description"
    end

    it "finds a subtool directly defined" do
      tool = lookup.lookup(["collection-1", "tool-1-3"])
      tool.effective_desc.must_equal "normal tool-1-3 short description"
      tool.effective_long_desc.must_equal "normal tool-1-3 long description"
      tool.full_name.must_equal ["collection-1", "tool-1-3"]
    end

    it "finds a collection directly defined" do
      tool = lookup.lookup(["collection-1"])
      tool.only_collection?.must_equal true
      tool.full_name.must_equal ["collection-1"]
    end

    it "finds the nearest collection directly defined if a query doesn't match" do
      tool = lookup.lookup(["collection-1", "tool-blah"])
      tool.only_collection?.must_equal true
      tool.full_name.must_equal ["collection-1"]
    end

    it "finds the root if a query has no toplevel match" do
      tool = lookup.lookup(["tool-blah"])
      tool.full_name.must_equal []
      tool.simple_name.must_be_nil
    end

    it "does not load unnecessary files" do
      lookup.lookup(["collection-1", "tool-1-3"])
      lookup.tool_defined?(["collection-1", "tool-1-3"]).must_equal true
      lookup.tool_defined?(["collection-1"]).must_equal true
      lookup.tool_defined?(["collection-1", "tool-1-1"]).must_equal false
      lookup.tool_defined?(["tool-1"]).must_equal false
      lookup.lookup(["tool-1"])
      lookup.tool_defined?(["tool-1"]).must_equal true
    end

    it "loads all descendants of a collection query" do
      lookup.lookup([])
      lookup.tool_defined?(["collection-1", "tool-1-3"]).must_equal true
      lookup.tool_defined?(["tool-1"]).must_equal true
    end
  end

  describe "collisions between definitions" do
    before do
      lookup.add_paths(File.join(cases_dir, "collision"))
    end

    it "allows loading if the collision isn't actually traversed" do
      tool = lookup.lookup(["tool-2"])
      tool.effective_desc.must_equal "index tool-2 short description"
      tool.effective_long_desc.must_equal "index tool-2 long description"
    end

    it "reports error if a tool is defined multiple times" do
      proc do
        lookup.lookup(["tool-1"])
      end.must_raise(Toys::ToolDefinitionError)
    end
  end

  describe "priority between definitions" do
    it "chooses from the config path if that has higher priority" do
      lookup.add_config_paths(File.join(cases_dir, "config-items"))
      lookup.add_paths(File.join(cases_dir, "normal-file-hierarchy"))

      tool = lookup.lookup(["tool-1"])
      tool.effective_desc.must_equal "file tool-1 short description"
      tool.effective_long_desc.must_equal "file tool-1 long description"
    end

    it "chooses from the directory path if that has higher priority" do
      lookup.add_config_paths(File.join(cases_dir, "config-items"))
      lookup.add_paths(File.join(cases_dir, "normal-file-hierarchy"), high_priority: true)

      tool = lookup.lookup(["tool-1"])
      tool.effective_desc.must_equal "normal tool-1 short description"
      tool.effective_long_desc.must_equal "normal tool-1 long description"
    end
  end

  describe "includes" do
    before do
      lookup.add_paths(File.join(cases_dir, "items-with-includes"))
    end

    it "gets an item from a root-level directory include" do
      tool = lookup.lookup(["tool-2"])
      tool.effective_desc.must_equal "directory tool-2 short description"
      tool.effective_long_desc.must_equal "directory tool-2 long description"
    end

    it "gets an item from a root-level file include" do
      tool = lookup.lookup(["collection-1", "tool-1-1"])
      tool.effective_desc.must_equal "file tool-1-1 short description"
      tool.effective_long_desc.must_equal "file tool-1-1 long description"
    end

    it "gets an item from non-root-level include" do
      tool = lookup.lookup(["collection-0", "collection-1", "tool-1-1"])
      tool.effective_desc.must_equal "normal tool-1-1 short description"
      tool.effective_long_desc.must_equal "normal tool-1-1 long description"
    end

    it "does not load an include if not needed" do
      lookup.lookup(["collection-1", "tool-1-1"])
      lookup.tool_defined?(["collection-1", "tool-1-1"]).must_equal true
      lookup.tool_defined?(["collection-0", "tool-1"]).must_equal false
      lookup.lookup(["collection-0", "tool-1"])
      lookup.tool_defined?(["collection-0", "tool-1"]).must_equal true
    end

    it "loads includes that are descendants of a collection query" do
      lookup.tool_defined?(["collection-0", "collection-1", "tool-1-1"]).must_equal false
      lookup.lookup(["collection-0"])
      lookup.tool_defined?(["collection-0", "collection-1", "tool-1-1"]).must_equal true
    end
  end
end
