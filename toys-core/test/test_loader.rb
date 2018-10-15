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

describe Toys::Loader do
  let(:loader) {
    Toys::Loader.new(index_file_name: ".toys.rb")
  }
  let(:cases_dir) {
    File.join(__dir__, "lookup-cases")
  }
  def wrappable(str)
    Toys::Utils::WrappableString.new(str)
  end

  describe "empty" do
    it "still has a root tool" do
      tool, _remaining = loader.lookup([])
      refute_nil(tool)
    end
  end

  describe "configuration block" do
    it "loads tools" do
      loader.add_block(name: "test block") do
        tool "tool-1" do
          desc "block tool-1 description"
        end
      end
      tool, remaining = loader.lookup(["tool-1"])
      assert_equal("block tool-1 description", tool.desc.to_s)
      assert_equal(true, tool.definition_finished?)
      assert_equal("test block", tool.source_info.source_name)
      assert_equal([], remaining)
    end

    it "loads multiple blocks" do
      loader.add_block(name: "test block 1") do
        tool "tool-1" do
          desc "block 1 tool-1 description"
        end
      end
      loader.add_block(name: "test block 2") do
        tool "tool-1" do
          desc "block 2 tool-1 description"
        end
        tool "tool-2" do
          desc "block 2 tool-2 description"
        end
      end
      tool, remaining = loader.lookup(["tool-1"])
      assert_equal("block 1 tool-1 description", tool.desc.to_s)
      assert_equal(true, tool.definition_finished?)
      assert_equal("test block 1", tool.source_info.source_name)
      assert_equal([], remaining)
      tool, remaining = loader.lookup(["tool-2"])
      assert_equal("block 2 tool-2 description", tool.desc.to_s)
      assert_equal(true, tool.definition_finished?)
      assert_equal("test block 2", tool.source_info.source_name)
      assert_equal([], remaining)
    end
  end

  describe "path with config items" do
    before do
      loader.add_path(File.join(cases_dir, "config-items", ".toys"))
      loader.add_path(File.join(cases_dir, "config-items", ".toys.rb"))
    end

    it "finds a tool directly defined in a config file" do
      tool, remaining = loader.lookup(["tool-1"])
      assert_equal("file tool-1 short description", tool.desc.to_s)
      assert_equal(true, tool.definition_finished?)
      assert_equal([], remaining)
    end

    it "finds a subtool directly defined in a config file" do
      tool, remaining = loader.lookup(["namespace-1", "tool-1-1"])
      assert_equal("file tool-1-1 short description", tool.desc.to_s)
      assert_equal(["namespace-1", "tool-1-1"], tool.full_name)
      assert_equal([], remaining)
    end

    it "finds a namespace directly defined in a config file" do
      tool, remaining = loader.lookup(["namespace-1"])
      assert_equal("file namespace-1 short description", tool.desc.to_s)
      assert_equal(["namespace-1"], tool.full_name)
      assert_equal([], remaining)
    end

    it "finds a tool defined in a file in a config directory" do
      tool, remaining = loader.lookup(["tool-2"])
      assert_equal("directory tool-2 short description", tool.desc.to_s)
      assert_equal([], remaining)
    end

    it "finds the nearest namespace directly defined if a query doesn't match" do
      tool, remaining = loader.lookup(["namespace-1", "tool-blah"])
      assert_equal("file namespace-1 short description", tool.desc.to_s)
      assert_equal(["namespace-1"], tool.full_name)
      assert_equal(["tool-blah"], remaining)
    end

    it "finds the root if a query has no toplevel match" do
      tool, remaining = loader.lookup(["tool-blah"])
      assert_equal([], tool.full_name)
      assert_nil(tool.simple_name)
      assert_equal(["tool-blah"], remaining)
    end
  end

  describe "config path with some hierarchical files" do
    before do
      loader.add_path(File.join(cases_dir, "normal-file-hierarchy"))
    end

    it "finds a tool directly defined" do
      tool, remaining = loader.lookup(["tool-1"])
      assert_equal("normal tool-1 short description", tool.desc.to_s)
      assert_equal([], remaining)
      assert_equal(cases_dir, tool.source_info.context_directory)
    end

    it "finds a subtool directly defined" do
      tool, remaining = loader.lookup(["namespace-1", "tool-1-3"])
      assert_equal("normal tool-1-3 short description", tool.desc.to_s)
      assert_equal(["namespace-1", "tool-1-3"], tool.full_name)
      assert_equal([], remaining)
      assert_equal(cases_dir, tool.source_info.context_directory)
    end

    it "finds a namespace directly defined" do
      tool, remaining = loader.lookup(["namespace-1"])
      assert_equal(false, tool.runnable?)
      assert_equal(["namespace-1"], tool.full_name)
      assert_equal([], remaining)
    end

    it "finds the nearest namespace directly defined if a query doesn't match" do
      tool, remaining = loader.lookup(["namespace-1", "tool-blah"])
      assert_equal(false, tool.runnable?)
      assert_equal(["namespace-1"], tool.full_name)
      assert_equal(["tool-blah"], remaining)
    end

    it "finds the root if a query has no toplevel match" do
      tool, remaining = loader.lookup(["tool-blah"])
      assert_equal([], tool.full_name)
      assert_nil(tool.simple_name)
      assert_equal(["tool-blah"], remaining)
    end

    it "does not load unnecessary files" do
      loader.lookup(["namespace-1", "tool-1-3"])
      assert_equal(true, loader.tool_defined?(["namespace-1", "tool-1-3"]))
      assert_equal(true, loader.tool_defined?(["namespace-1"]))
      assert_equal(false, loader.tool_defined?(["namespace-1", "tool-1-1"]))
      assert_equal(false, loader.tool_defined?(["tool-1"]))
      loader.lookup(["tool-1"])
      assert_equal(true, loader.tool_defined?(["tool-1"]))
      assert_equal(false, loader.tool_defined?(["namespace-1", "tool-1-1"]))
    end

    it "loads all descendants of a namespace query" do
      loader.lookup([])
      assert_equal(true, loader.tool_defined?(["namespace-1", "tool-1-3"]))
      assert_equal(true, loader.tool_defined?(["tool-1"]))
    end
  end

  describe "extra delimiters" do
    let(:delimiters_loader) {
      Toys::Loader.new(index_file_name: ".toys.rb", extra_delimiters: ".:")
    }

    before do
      delimiters_loader.add_path(File.join(cases_dir, "normal-file-hierarchy"))
    end

    it "recognizes only specified delimiters" do
      tool, remaining = delimiters_loader.lookup(["namespace-1;tool-1-3"])
      assert_equal([], tool.full_name)
      assert_nil(tool.simple_name)
      assert_equal(["namespace-1;tool-1-3"], remaining)
    end

    it "finds a subtool" do
      tool, remaining = delimiters_loader.lookup(["namespace-1.tool-1-3"])
      assert_equal("normal tool-1-3 short description", tool.desc.to_s)
      assert_equal(["namespace-1", "tool-1-3"], tool.full_name)
      assert_equal([], remaining)
    end

    it "finds the nearest namespace if a query doesn't match" do
      tool, remaining = delimiters_loader.lookup(["namespace-1.tool-blah"])
      assert_equal(false, tool.runnable?)
      assert_equal(["namespace-1"], tool.full_name)
      assert_equal(["tool-blah"], remaining)
    end

    it "finds a subtool if a delimiter isn't used" do
      tool, remaining = delimiters_loader.lookup(["namespace-1", "tool-1-3"])
      assert_equal("normal tool-1-3 short description", tool.desc.to_s)
      assert_equal(["namespace-1", "tool-1-3"], tool.full_name)
      assert_equal([], remaining)
    end
  end

  describe "collisions between definitions" do
    before do
      loader.add_path(File.join(cases_dir, "collision"))
    end

    it "allows loading if the collision isn't actually traversed" do
      tool, _remaining = loader.lookup(["tool-2"])
      assert_equal("index tool-2 short description", tool.desc.to_s)
    end

    it "reports error if a tool is defined multiple times" do
      assert_raises(Toys::ContextualError) do
        loader.lookup(["tool-1"])
      end
    end
  end

  describe "priority between definitions" do
    it "chooses from the earlier path" do
      loader.add_path(File.join(cases_dir, "config-items", ".toys"))
      loader.add_path(File.join(cases_dir, "config-items", ".toys.rb"))
      loader.add_path(File.join(cases_dir, "normal-file-hierarchy"))

      tool, _remaining = loader.lookup(["tool-1"])
      assert_equal("file tool-1 short description", tool.desc.to_s)
    end

    it "honors the high-priority flag" do
      loader.add_path(File.join(cases_dir, "config-items", ".toys"))
      loader.add_path(File.join(cases_dir, "config-items", ".toys.rb"))
      loader.add_path(File.join(cases_dir, "normal-file-hierarchy"), high_priority: true)

      tool, _remaining = loader.lookup(["tool-1"])
      assert_equal("normal tool-1 short description", tool.desc.to_s)
    end
  end

  describe "includes" do
    before do
      loader.add_path(File.join(cases_dir, "items-with-includes"))
    end

    it "gets an item from a root-level directory include" do
      tool, _remaining = loader.lookup(["tool-2"])
      assert_equal("directory tool-2 short description", tool.desc.to_s)
    end

    it "gets an item from a root-level file include" do
      tool, _remaining = loader.lookup(["namespace-1", "tool-1-1"])
      assert_equal("file tool-1-1 short description", tool.desc.to_s)
      assert_equal(cases_dir, tool.source_info.context_directory)
    end

    it "gets an item from non-root-level include" do
      tool, _remaining = loader.lookup(["namespace-0", "namespace-1", "tool-1-1"])
      assert_equal("normal tool-1-1 short description", tool.desc.to_s)
      assert_equal(cases_dir, tool.source_info.context_directory)
    end

    it "does not load an include if not needed" do
      loader.lookup(["namespace-1", "tool-1-1"])
      assert_equal(true, loader.tool_defined?(["namespace-1", "tool-1-1"]))
      assert_equal(false, loader.tool_defined?(["namespace-0", "tool-1"]))
      loader.lookup(["namespace-0", "tool-1"])
      assert_equal(true, loader.tool_defined?(["namespace-0", "tool-1"]))
    end

    it "loads includes that are descendants of a namespace query" do
      assert_equal(false, loader.tool_defined?(["namespace-0", "namespace-1", "tool-1-1"]))
      loader.lookup(["namespace-0"])
      assert_equal(true, loader.tool_defined?(["namespace-0", "namespace-1", "tool-1-1"]))
    end
  end

  describe "aliases" do
    before do
      loader.add_path(File.join(cases_dir, "aliases"))
    end

    it "finds a directly referenced alias" do
      tool, remaining = loader.lookup(["alias-1"])
      assert_equal("file tool-1 short description", tool.desc.to_s)
      assert_equal(true, tool.definition_finished?)
      assert_equal([], remaining)
    end

    it "finds a recursively referenced alias" do
      tool, remaining = loader.lookup(["alias-2"])
      assert_equal("file tool-1 short description", tool.desc.to_s)
      assert_equal(true, tool.definition_finished?)
      assert_equal([], remaining)
    end

    it "recognizes remaining args after an alias" do
      tool, remaining = loader.lookup(["alias-2", "tool-blah"])
      assert_equal("file tool-1 short description", tool.desc.to_s)
      assert_equal(["tool-blah"], remaining)
    end
  end

  describe "preloads" do
    let(:preloading_loader) {
      Toys::Loader.new(index_file_name: ".toys.rb",
                       preload_file_name: ".preload.rb",
                       preload_directory_name: ".preload")
    }

    before do
      $toys_preload_ns1 = nil
      $toys_preload_ns2 = nil
      $toys_preload_ns3 = nil
      $toys_preload_ns1a_preloaded1 = nil
      $toys_preload_ns1a_preloaded2 = nil
      loader.add_path(File.join(cases_dir, "preloads"))
      preloading_loader.add_path(File.join(cases_dir, "preloads"))
    end

    it "finds a simple preload file" do
      assert_nil($toys_preload_ns2)
      preloading_loader.lookup(["ns-2", "foo"])
      assert_equal(:hi, $toys_preload_ns2)
    end

    it "finds nested preload files" do
      assert_nil($toys_preload_ns1)
      assert_nil($toys_preload_ns1a_preloaded1)
      assert_nil($toys_preload_ns1a_preloaded2)
      preloading_loader.lookup(["ns-1", "ns-1a", "foo"])
      assert_equal(:hi, $toys_preload_ns1)
      assert_equal(:hi, $toys_preload_ns1a_preloaded1)
      assert_equal(:hi, $toys_preload_ns1a_preloaded2)
    end

    it "ignores preloads if not configured" do
      loader.lookup(["ns-3", "foo"])
      assert_nil($toys_preload_ns3)
    end
  end

  describe "with data directory" do
    let(:finding_loader) {
      Toys::Loader.new(index_file_name: ".toys.rb",
                       data_directory_name: ".data")
    }

    before do
      loader.add_path(File.join(cases_dir, "data-finder"))
      finding_loader.add_path(File.join(cases_dir, "data-finder"))
    end

    it "finds data during loading" do
      finding_loader.lookup(["ns-1", "foo"])
    end

    it "overrides data during loading" do
      finding_loader.lookup(["ns-1", "ns-1a", "foo"])
    end

    it "reports lack of data during loading" do
      finding_loader.lookup(["ns-3", "foo"])
    end

    it "ignores data during loading if not configured" do
      loader.lookup(["ns-2", "foo"])
    end
  end
end
