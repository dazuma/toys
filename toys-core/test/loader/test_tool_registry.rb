# frozen_string_literal: true

require "helper"

describe Toys::Loader::ToolRegistry do
  let(:registry) { Toys::Loader::ToolRegistry.new.record_root(0).record_root(1) }
  let(:tool_name) { ["foo", "bar"] }

  def source_at(priority)
    Toys::SourceInfo.resolve(Toys::SourceSpec::EMPTY, priority: priority)
  end

  describe "record_root" do
    it "records a root for a priority" do
      source = source_at(2)
      registry.record_root(2, source)
      assert_same(source, registry.get_tool(tool_name, 2).source_root)
    end

    it "defaults to an empty root" do
      registry.record_root(2)
      assert_equal(:proc, registry.get_tool(tool_name, 2).source_root.source_type)
    end

    it "raises if the priority already has a recorded root" do
      err = assert_raises(Toys::ToolDefinitionError) do
        registry.record_root(1, source_at(1))
      end
      assert_equal("Tool source root already recorded for priority 1", err.message)
    end
  end

  describe "get_tool" do
    it "returns the same definition for a repeated name and priority" do
      assert_same(registry.get_tool(tool_name, 0), registry.get_tool(tool_name, 0))
    end

    it "returns distinct definitions for different priorities" do
      refute_same(registry.get_tool(tool_name, 0), registry.get_tool(tool_name, 1))
    end

    it "raises if the priority has not been recorded" do
      err = assert_raises(Toys::ToolDefinitionError) do
        registry.get_tool(tool_name, 2)
      end
      assert_equal("Unrecorded priority: 2", err.message)
    end

    it "raises if a tool class is given for a name already defined at that priority" do
      registry.get_tool(tool_name, 0)
      err = assert_raises(Toys::ToolDefinitionError) do
        registry.get_tool(tool_name, 0, tool_class: ::Class.new(Toys::Context))
      end
      assert_equal("Tool already defined for #{tool_name.inspect}", err.message)
    end

    # No current caller repeats a tool class: DSL::Internal.configure_class
    # registers each Toys::Tool subclass exactly once. This pins the registry's
    # own contract, which keys the assertion on the class rather than on the
    # mere presence of a definition.
    it "returns the existing definition if the same tool class is given twice" do
      tool_class = ::Class.new(Toys::Context)
      tool = registry.get_tool(tool_name, 0, tool_class: tool_class)
      assert_same(tool_class, tool.tool_class)
      assert_same(tool, registry.get_tool(tool_name, 0, tool_class: tool_class))
    end

    it "raises if the name contains illegal characters" do
      err = assert_raises(Toys::ToolDefinitionError) do
        registry.get_tool(["foo", "bar*baz"], 0)
      end
      assert_equal('Illegal characters in name "bar*baz"', err.message)
    end

    describe "with activate" do
      it "returns nil when a higher priority is already active" do
        high = registry.get_tool(tool_name, 1, activate: true)
        assert_nil(registry.get_tool(tool_name, 0, activate: true))
        assert_same(high, registry.cur_definition(tool_name))
      end

      it "supersedes an active lower priority definition" do
        low = registry.get_tool(tool_name, 0, activate: true)
        high = registry.get_tool(tool_name, 1, activate: true)
        refute_same(low, high)
        assert_same(high, registry.cur_definition(tool_name))
      end

      it "raises if the priority has not been recorded" do
        err = assert_raises(Toys::ToolDefinitionError) do
          registry.get_tool(tool_name, 2, activate: true)
        end
        assert_equal("Unrecorded priority: 2", err.message)
      end
    end
  end

  describe "tool construction" do
    let(:middleware) { Toys::Middleware::Base.new }
    let(:middleware_registry) {
      Toys::Loader::ToolRegistry.new(middleware_stack: [middleware]).record_root(0)
    }

    it "implicitly creates ancestor definitions at the same priority" do
      registry.get_tool(tool_name, 1)
      assert(registry.tool_defined?(["foo"]))
      assert(registry.tool_defined?([]))
      assert_equal(1, registry.cur_definition(["foo"]).priority)
      assert_equal(1, registry.cur_definition([]).priority)
    end

    it "links a definition to its parent so lookups walk up the tree" do
      acceptor = Toys::Acceptor::Simple.new
      registry.get_tool(["foo"], 0).add_acceptor("acc", acceptor)
      assert_same(acceptor, registry.get_tool(tool_name, 0).lookup_acceptor("acc"))
    end

    it "builds a root tool from the registry middleware stack" do
      assert_equal([middleware], middleware_registry.get_tool([], 0).built_middleware)
    end

    it "builds a subtool from its parent's subtool middleware stack" do
      subtool_middleware = Toys::Middleware::Base.new
      parent = middleware_registry.get_tool(["foo"], 0)
      parent.subtool_middleware_stack.add(subtool_middleware)
      subtool = middleware_registry.get_tool(tool_name, 0)
      assert_equal([subtool_middleware, middleware], subtool.built_middleware)
      # The parent, already built, does not pick up its own addition.
      assert_equal([middleware], parent.built_middleware)
    end

    it "resolves middleware names using the given lookup" do
      lookup = Toys::ModuleLookup.new.add_path("toys/standard_middleware")
      named_registry =
        Toys::Loader::ToolRegistry.new(middleware_stack: [:set_default_descriptions],
                                       middleware_lookup: lookup).record_root(0)
      built = named_registry.get_tool([], 0).built_middleware
      assert_equal([Toys::StandardMiddleware::SetDefaultDescriptions], built.map(&:class))
    end
  end

  describe "cur_definition" do
    it "reports the highest priority definition when none is activated" do
      registry.get_tool(tool_name, 0)
      high = registry.get_tool(tool_name, 1)
      assert_same(high, registry.cur_definition(tool_name))
    end

    it "reports the highest priority definition when a lower priority is defined later" do
      high = registry.get_tool(tool_name, 1)
      registry.get_tool(tool_name, 0)
      assert_same(high, registry.cur_definition(tool_name))
    end

    it "reports the activated definition even when a higher priority one exists" do
      active = registry.get_tool(tool_name, 0, activate: true)
      registry.get_tool(tool_name, 1)
      assert_same(active, registry.cur_definition(tool_name))
    end

    it "does not raise for a name with illegal characters" do
      assert_nil(registry.cur_definition(["foo", "bar*baz"]))
    end
  end

  describe "tool_defined?" do
    it "returns false before the tool is defined" do
      refute(registry.tool_defined?(tool_name))
    end

    it "returns true after the tool is defined" do
      registry.get_tool(tool_name, 0)
      assert(registry.tool_defined?(tool_name))
    end

    it "returns false for a name that was merely looked up" do
      assert_nil(registry.cur_definition(tool_name))
      refute(registry.tool_defined?(tool_name))
    end
  end
end
