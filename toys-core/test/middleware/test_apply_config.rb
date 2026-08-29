# frozen_string_literal: true

require "helper"
require "logger"
require "stringio"
require "toys/standard_middleware/apply_config"

describe Toys::StandardMiddleware::ApplyConfig do
  let(:logger) {
    Logger.new(StringIO.new).tap do |lgr|
      lgr.level = Logger::WARN
    end
  }
  # Maps each tool class the block was applied to, to the source in effect for
  # that application. The block runs as a class_eval on the tool class, so
  # `self` identifies the tool.
  let(:applied_sources) { {} }
  let(:middleware) {
    sources = applied_sources
    Toys::StandardMiddleware::ApplyConfig.new do
      sources[self] = source_info
      long_desc "applied by middleware"
    end
  }
  let(:cli) {
    Toys::CLI.new(executable_name: "toys", logger: logger, middleware_stack: [middleware])
  }

  it "applies the block to a tool" do
    cli.add_source do
      tool "foo" do
        def run; end
      end
    end
    tool, _remaining = cli.loader.lookup(["foo"])
    assert_equal("applied by middleware", tool.long_desc.first.to_s)
  end

  it "applies the block to a namespace that was never activated" do
    cli.add_source do
      tool "ns" do
        tool "leaf" do
          def run; end
        end
      end
    end
    tool, _remaining = cli.loader.lookup(["ns"])
    assert_equal(["ns"], tool.full_name)
    assert_equal("applied by middleware", tool.long_desc.first.to_s)
  end

  it "applies the block to tools from sources of differing priority" do
    cli.add_source do
      tool "foo" do
        def run; end
      end
    end
    cli.add_source do
      tool "ns" do
        tool "leaf" do
          def run; end
        end
      end
    end
    foo, _remaining = cli.loader.lookup(["foo"])
    ns, _remaining = cli.loader.lookup(["ns"])
    leaf, _remaining = cli.loader.lookup(["ns", "leaf"])
    refute_equal(foo.priority, ns.priority)
    assert_equal("applied by middleware", foo.long_desc.first.to_s)
    assert_equal("applied by middleware", ns.long_desc.first.to_s)
    assert_equal("applied by middleware", leaf.long_desc.first.to_s)
  end

  it "gives the block a proc source matching the tool's priority" do
    cli.add_source(Toys::SourceSpec.block(source_name: "my source") do
      tool "foo" do
        def run; end
      end
    end)
    tool, _remaining = cli.loader.lookup(["foo"])
    source = applied_sources[tool.tool_class]
    refute_nil(source)
    assert_equal(:proc, source.source_type)
    assert_equal("my source", source.source_name)
    assert_same(tool.source_root, source.parent)
  end

  it "reuses a single source for all tools in the same source tree" do
    cli.add_source do
      tool "foo" do
        def run; end
      end
      tool "bar" do
        def run; end
      end
    end
    foo, _remaining = cli.loader.lookup(["foo"])
    bar, _remaining = cli.loader.lookup(["bar"])
    assert_same(foo.source_root, bar.source_root)
    assert_same(applied_sources[foo.tool_class], applied_sources[bar.tool_class])
  end

  it "creates a separate source for each source tree" do
    cli.add_source do
      tool "foo" do
        def run; end
      end
    end
    cli.add_source do
      tool "bar" do
        def run; end
      end
    end
    foo, _remaining = cli.loader.lookup(["foo"])
    bar, _remaining = cli.loader.lookup(["bar"])
    refute_same(applied_sources[foo.tool_class], applied_sources[bar.tool_class])
    assert_same(foo.source_root, applied_sources[foo.tool_class].parent)
    assert_same(bar.source_root, applied_sources[bar.tool_class].parent)
  end

  describe "with an explicit source name" do
    let(:middleware) {
      sources = applied_sources
      Toys::StandardMiddleware::ApplyConfig.new(source_name: "the config block") do
        sources[self] = source_info
      end
    }

    it "names the block source" do
      cli.add_source do
        tool "foo" do
          def run; end
        end
      end
      cli.loader.lookup(["foo"])
      refute_empty(applied_sources)
      applied_sources.each_value do |source|
        assert_equal("the config block", source.source_name)
      end
    end
  end

  describe "with a parent source" do
    # A SourceInfo can be obtained only from a loader, so this captures one
    # from a separate CLI. Its source tree is therefore foreign to the CLI
    # under test.
    let(:foreign_source) {
      captured = nil
      other_cli = Toys::CLI.new(executable_name: "toys", logger: logger, middleware_stack: [])
      other_cli.add_source(Toys::SourceSpec.block(source_name: "other tree") do
        captured = source_info
        tool "foo" do
          def run; end
        end
      end)
      other_cli.loader.lookup(["foo"])
      captured
    }
    let(:middleware) {
      sources = applied_sources
      Toys::StandardMiddleware::ApplyConfig.new(parent_source: foreign_source) do
        sources[self] = source_info
        long_desc "applied by middleware"
      end
    }

    it "does not apply the block to tools from another source tree" do
      cli.add_source do
        tool "foo" do
          def run; end
        end
      end
      tool, _remaining = cli.loader.lookup(["foo"])
      assert_empty(tool.long_desc)
      assert_empty(applied_sources)
    end

    # The matching case, in which the parent source does belong to the tool's
    # own source tree, arises through the subtool_apply directive. See the
    # "subtool_apply directive" tests in test_dsl.rb.
    it "applies the block to tools from its own source tree" do
      cli = Toys::CLI.new(executable_name: "toys", logger: logger, middleware_stack: [])
      cli.add_source do
        tool "foo" do
          subtool_apply do
            long_desc "applied by middleware"
          end
          tool "bar" do
            def run; end
          end
        end
      end
      tool, _remaining = cli.loader.lookup(["foo", "bar"])
      assert_equal("applied by middleware", tool.long_desc.first.to_s)
    end
  end
end
