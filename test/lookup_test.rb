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
      tool.effective_short_desc.must_equal "file tool-1 short description"
      tool.effective_long_desc.must_equal "file tool-1 long description"
    end

    it "finds a subtool directly defined in a config file" do
      tool = lookup.lookup(["collection-1", "tool-1-1"])
      tool.effective_short_desc.must_equal "file tool-1-1 short description"
      tool.effective_long_desc.must_equal "file tool-1-1 long description"
      tool.full_name.must_equal ["collection-1", "tool-1-1"]
    end

    it "finds a collection directly defined in a config file" do
      tool = lookup.lookup(["collection-1"])
      tool.effective_short_desc.must_equal "file collection-1 short description"
      tool.full_name.must_equal ["collection-1"]
    end

    it "finds a tool defined in a file in a config directory" do
      tool = lookup.lookup(["tool-2"])
      tool.effective_short_desc.must_equal "directory tool-2 short description"
      tool.effective_long_desc.must_equal "directory tool-2 long description"
    end

    it "finds the nearest collection directly defined if a query doesn't match" do
      tool = lookup.lookup(["collection-1", "tool-blah"])
      tool.effective_short_desc.must_equal "file collection-1 short description"
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
      tool.effective_short_desc.must_equal "normal tool-1 short description"
      tool.effective_long_desc.must_equal "normal tool-1 long description"
    end

    it "finds a subtool directly defined" do
      tool = lookup.lookup(["collection-1", "tool-1-3"])
      tool.effective_short_desc.must_equal "normal tool-1-3 short description"
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
      lookup.add_config_paths(File.join(cases_dir, "config-items"))
      lookup.add_paths(File.join(cases_dir, "normal-file-hierarchy"))
    end

    it "allows loading if the collision isn't actually traversed" do
      tool = lookup.lookup(["tool-2"])
      tool.effective_short_desc.must_equal "directory tool-2 short description"
      tool.effective_long_desc.must_equal "directory tool-2 long description"
    end

    it "reports error if a tool is defined multiple times" do
      proc do
        lookup.lookup(["tool-1"])
      end.must_raise(Toys::ToolDefinitionError)
    end
  end

  describe "includes" do
    before do
      lookup.add_paths(File.join(cases_dir, "items-with-includes"))
    end

    it "gets an item from a root-level directory include" do
      tool = lookup.lookup(["tool-2"])
      tool.effective_short_desc.must_equal "directory tool-2 short description"
      tool.effective_long_desc.must_equal "directory tool-2 long description"
    end

    it "gets an item from a root-level file include" do
      tool = lookup.lookup(["collection-1", "tool-1-1"])
      tool.effective_short_desc.must_equal "file tool-1-1 short description"
      tool.effective_long_desc.must_equal "file tool-1-1 long description"
    end

    it "gets an item from non-root-level include" do
      tool = lookup.lookup(["collection-0", "collection-1", "tool-1-1"])
      tool.effective_short_desc.must_equal "normal tool-1-1 short description"
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
