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

describe Toys::Loader do
  let(:loader) {
    Toys::Loader.new(index_file_name: ".toys.rb")
  }
  let(:cases_dir) {
    File.join(__dir__, "lookup-cases")
  }
  def wrappable(str)
    Toys::WrappableString.new(str)
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
                       preload_dir_name: ".preload")
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
                       data_dir_name: ".data")
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

  describe "context directory" do
    let(:custom_dir) { "/path/to/dir" }

    it "can be set" do
      dir = custom_dir
      loader.add_block(name: "test block") do
        desc "a description"
        tool "ns1" do
          set_context_directory(dir)
          desc "a description"
          tool "tool1" do
            desc "a description"
          end
        end
      end
      tool, _remaining = loader.lookup([])
      assert_nil(tool.source_info.context_directory)
      assert_nil(tool.context_directory)
      tool, _remaining = loader.lookup(["ns1"])
      assert_nil(tool.source_info.context_directory)
      assert_equal(custom_dir, tool.context_directory)
      tool, _remaining = loader.lookup(["ns1", "tool1"])
      assert_nil(tool.source_info.context_directory)
      assert_equal(custom_dir, tool.context_directory)
    end
  end

  describe "subtool list" do
    let(:subtools_loader) {
      loader.add_block(name: "test block") do
        tool "ns3" do
          tool "tool1" do
            desc "hi"
          end
          def run; end
        end
        tool "ns2" do
          desc "hi"
          tool "tool3" do
            desc "hi"
          end
          tool "_tool2" do
            desc "hi"
          end
        end
        tool "_ns1" do
          desc "hi"
          tool "tool2" do
            desc "hi"
          end
          tool "tool1" do
            desc "hi"
          end
        end
      end
    }

    let(:aliases_loader) {
      loader.add_block(name: "test block") do
        tool "ns1" do
          tool "tool1" do
            desc "hi"
          end
          alias_tool "tool1_alias", "tool1"
          alias_tool "_tool1_alias", "tool1"
        end
        alias_tool "ns1_alias", "ns1"
        alias_tool "_ns1_alias", "ns1"
        tool "_tool2" do
        end
        alias_tool "tool2_alias", "_tool2"
      end
    }

    it "loads a list" do
      subtools = subtools_loader.list_subtools([])
      assert_equal(2, subtools.size)
      assert_equal(["ns2"], subtools[0].full_name)
      assert_equal(["ns3"], subtools[1].full_name)
    end

    it "loads a list with recursion" do
      subtools = subtools_loader.list_subtools([], recursive: true)
      assert_equal(3, subtools.size)
      assert_equal(["ns2", "tool3"], subtools[0].full_name)
      assert_equal(["ns3"], subtools[1].full_name)
      assert_equal(["ns3", "tool1"], subtools[2].full_name)
    end

    it "loads a list including hidden" do
      subtools = subtools_loader.list_subtools([], include_hidden: true)
      assert_equal(3, subtools.size)
      assert_equal(["_ns1"], subtools[0].full_name)
      assert_equal(["ns2"], subtools[1].full_name)
      assert_equal(["ns3"], subtools[2].full_name)
    end

    it "loads a list including hidden with recursion" do
      subtools = subtools_loader.list_subtools([], recursive: true, include_hidden: true)
      assert_equal(8, subtools.size)
      assert_equal(["_ns1"], subtools[0].full_name)
      assert_equal(["_ns1", "tool1"], subtools[1].full_name)
      assert_equal(["_ns1", "tool2"], subtools[2].full_name)
      assert_equal(["ns2"], subtools[3].full_name)
      assert_equal(["ns2", "_tool2"], subtools[4].full_name)
      assert_equal(["ns2", "tool3"], subtools[5].full_name)
      assert_equal(["ns3"], subtools[6].full_name)
      assert_equal(["ns3", "tool1"], subtools[7].full_name)
    end

    it "loads a list including aliases" do
      subtools = aliases_loader.list_subtools(["ns1"])
      assert_equal(2, subtools.size)
      assert_equal(["ns1", "tool1"], subtools[0].full_name)
      assert_equal(["ns1", "tool1_alias"], subtools[1].full_name)
    end

    it "loads a list omitting hidden aliases" do
      subtools = aliases_loader.list_subtools([], recursive: true)
      assert_equal(3, subtools.size)
      assert_equal(["ns1", "tool1"], subtools[0].full_name)
      assert_equal(["ns1", "tool1_alias"], subtools[1].full_name)
      assert_equal(["ns1_alias"], subtools[2].full_name)
    end
  end
end
