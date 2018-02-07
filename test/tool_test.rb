require "helper"

describe Toys::Tool do
  let(:tool_name) { "foo" }
  let(:subtool_name) { "bar" }
  let(:root_tool) { Toys::Tool.new(nil, nil) }
  let(:tool) { Toys::Tool.new(root_tool, tool_name) }
  let(:subtool) { Toys::Tool.new(tool, subtool_name) }

  describe "root" do
    it "has the right names" do
      root_tool.simple_name.must_be_nil
      root_tool.full_name.must_equal []
    end
  end

  describe "subtool" do
    it "has the right names" do
      subtool.simple_name.must_equal subtool_name
      subtool.full_name.must_equal [tool_name, subtool_name]
    end
  end

  describe "simple tool" do
    it "has the right names" do
      tool.simple_name.must_equal tool_name
      tool.full_name.must_equal [tool_name]
    end

    it "defaults fields to nil" do
      tool.short_desc.must_be_nil
      tool.long_desc.must_be_nil
      tool.executor.must_be_nil
    end

    it "detects priority decreases" do
      tool.short_desc = "hi"
      tool.long_desc = "hiho"
      tool.check_priority(-1).must_equal false
      tool.short_desc.must_equal "hi"
      tool.long_desc.must_equal "hiho"
    end

    it "detects priority equality" do
      tool.short_desc = "hi"
      tool.long_desc = "hiho"
      tool.check_priority(0).must_equal true
      tool.short_desc.must_equal "hi"
      tool.long_desc.must_equal "hiho"
    end

    it "detects priority increases" do
      tool.short_desc = "hi"
      tool.long_desc = "hiho"
      tool.check_priority(1).must_equal true
      tool.short_desc.must_be_nil
      tool.long_desc.must_be_nil
    end
  end
end
