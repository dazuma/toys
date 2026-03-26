# frozen_string_literal: true

require "helper"

describe Toys::Context do
  let(:fake_cli) { Object.new }
  let(:fake_tool) { Object.new }
  let(:usage_errors) { [] }
  let(:logger) { Logger.new(nil) }
  let(:data) {
    {
      Toys::Context::Key::ARGS => ["hello", "world"],
      Toys::Context::Key::CLI => fake_cli,
      Toys::Context::Key::CONTEXT_DIRECTORY => "/some/dir",
      Toys::Context::Key::DELEGATED_FROM => nil,
      Toys::Context::Key::LOGGER => logger,
      Toys::Context::Key::TOOL => fake_tool,
      Toys::Context::Key::TOOL_NAME => ["my-tool"],
      Toys::Context::Key::TOOL_SOURCE => nil,
      Toys::Context::Key::USAGE_ERRORS => usage_errors,
      Toys::Context::Key::VERBOSITY => 2,
      :my_flag => "flagval",
      "my_string_key" => "strval",
    }
  }
  let(:context) { Toys::Context.new(data) }

  describe "well-known key getters" do
    it "returns args" do
      assert_equal(["hello", "world"], context.args)
    end

    it "returns cli" do
      assert_same(fake_cli, context.cli)
    end

    it "returns context_directory" do
      assert_equal("/some/dir", context.context_directory)
    end

    it "returns logger" do
      assert_same(logger, context.logger)
    end

    it "returns tool_name" do
      assert_equal(["my-tool"], context.tool_name)
    end

    it "returns tool_source" do
      assert_nil(context.tool_source)
    end

    it "returns usage_errors" do
      assert_same(usage_errors, context.usage_errors)
    end

    it "returns verbosity" do
      assert_equal(2, context.verbosity)
    end

    it "returns delegated_from via []" do
      assert_nil(context[Toys::Context::Key::DELEGATED_FROM])
    end
  end

  describe "__ aliases for well-known getters" do
    it "__args returns args" do
      assert_equal(["hello", "world"], context.__args)
    end

    it "__cli returns cli" do
      assert_same(fake_cli, context.__cli)
    end

    it "__context_directory returns context_directory" do
      assert_equal("/some/dir", context.__context_directory)
    end

    it "__logger returns logger" do
      assert_same(logger, context.__logger)
    end

    it "__tool_name returns tool_name" do
      assert_equal(["my-tool"], context.__tool_name)
    end

    it "__tool_source returns tool_source" do
      assert_nil(context.__tool_source)
    end

    it "__usage_errors returns usage_errors" do
      assert_same(usage_errors, context.__usage_errors)
    end

    it "__verbosity returns verbosity" do
      assert_equal(2, context.__verbosity)
    end
  end

  describe "#[] and #get" do
    it "reads a well-known key" do
      assert_equal(2, context[Toys::Context::Key::VERBOSITY])
    end

    it "reads a symbol key" do
      assert_equal("flagval", context[:my_flag])
    end

    it "reads a string key" do
      assert_equal("strval", context["my_string_key"])
    end

    it "returns nil for an absent key" do
      assert_nil(context[:absent])
    end

    it "get is an alias for []" do
      assert_equal("flagval", context.get(:my_flag))
    end

    it "__get is an alias for []" do
      assert_equal("flagval", context.__get(:my_flag))
    end
  end

  describe "#[]=" do
    it "sets a new key" do
      context[:new_key] = "new_value"
      assert_equal("new_value", context[:new_key])
    end

    it "overwrites an existing key" do
      context[:my_flag] = "updated"
      assert_equal("updated", context[:my_flag])
    end

    it "can set a well-known key" do
      context[Toys::Context::Key::VERBOSITY] = 5
      assert_equal(5, context.verbosity)
    end
  end

  describe "#set" do
    it "sets a single key-value pair" do
      context.set(:foo, "bar")
      assert_equal("bar", context[:foo])
    end

    it "returns self for single key-value pair" do
      assert_same(context, context.set(:foo, "bar"))
    end

    it "sets multiple keys from a hash" do
      context.set(foo: "bar", baz: 42)
      assert_equal("bar", context[:foo])
      assert_equal(42, context[:baz])
    end

    it "returns self when given a hash" do
      assert_same(context, context.set(foo: "bar"))
    end

    it "overwrites an existing key" do
      context.set(:my_flag, "updated")
      assert_equal("updated", context[:my_flag])
    end

    it "__set is an alias" do
      context.__set(:foo, "bar")
      assert_equal("bar", context[:foo])
    end
  end

  describe "#options" do
    it "includes symbol keys" do
      assert_equal("flagval", context.options[:my_flag])
    end

    it "includes string keys" do
      assert_equal("strval", context.options["my_string_key"])
    end

    it "excludes non-string/symbol keys" do
      context.options.each_key do |key|
        assert(key.is_a?(String) || key.is_a?(Symbol))
      end
    end

    it "__options is an alias" do
      assert_equal("flagval", context.__options[:my_flag])
    end
  end

  describe "#find_data" do
    let(:fake_source) {
      Object.new.tap do |s|
        def s.find_data(path, type: nil)
          type == :directory ? "/data/dir/#{path}" : "/data/file/#{path}"
        end
      end
    }
    let(:context_with_source) {
      Toys::Context.new(data.merge(Toys::Context::Key::TOOL_SOURCE => fake_source))
    }

    it "delegates to tool_source" do
      assert_equal("/data/file/foo.txt", context_with_source.find_data("foo.txt"))
    end

    it "passes type argument to tool_source" do
      assert_equal("/data/dir/mydir", context_with_source.find_data("mydir", type: :directory))
    end

    it "returns nil when tool_source is nil" do
      assert_nil(context.find_data("foo.txt"))
    end

    it "__find_data is an alias" do
      assert_equal("/data/file/foo.txt", context_with_source.__find_data("foo.txt"))
    end
  end

  describe "#exit (instance method)" do
    it "throws :result with the given code" do
      code = catch(:result) { context.exit(5) }
      assert_equal(5, code)
    end

    it "throws :result with 0 by default" do
      code = catch(:result) { context.exit }
      assert_equal(0, code)
    end

    it "__exit is an alias" do
      code = catch(:result) { context.__exit(7) }
      assert_equal(7, code)
    end
  end

  describe "Context.exit (class method)" do
    it "throws :result with the given code" do
      code = catch(:result) { Toys::Context.exit(3) }
      assert_equal(3, code)
    end

    it "throws :result with 0 by default" do
      code = catch(:result) { Toys::Context.exit }
      assert_equal(0, code)
    end

    it "converts a non-integer string to -1" do
      code = catch(:result) { Toys::Context.exit("oops") }
      assert_equal(-1, code)
    end

    it "converts nil to -1" do
      code = catch(:result) { Toys::Context.exit(nil) }
      assert_equal(-1, code)
    end

    it "accepts negative exit codes" do
      code = catch(:result) { Toys::Context.exit(-1) }
      assert_equal(-1, code)
    end
  end

  describe "#inspect" do
    it "includes the tool name in quotes" do
      assert_match(/tool="my-tool"/, context.inspect)
    end

    it "shows (root) for an empty tool name" do
      ctx = Toys::Context.new(data.merge(Toys::Context::Key::TOOL_NAME => []))
      assert_match(/tool=\(root\)/, ctx.inspect)
    end

    it "shows (root) for a nil tool name" do
      ctx = Toys::Context.new(data.merge(Toys::Context::Key::TOOL_NAME => nil))
      assert_match(/tool=\(root\)/, ctx.inspect)
    end

    it "joins multi-word tool names with spaces" do
      ctx = Toys::Context.new(data.merge(Toys::Context::Key::TOOL_NAME => ["foo", "bar"]))
      assert_match(/tool="foo bar"/, ctx.inspect)
    end

    it "includes the object id in hex" do
      assert_match(/id=0x[0-9a-f]+/, context.inspect)
    end
  end

  describe "override safety via __ aliases" do
    let(:subclass) {
      Class.new(Toys::Context) do
        def args
          "overridden_args"
        end

        def cli
          "overridden_cli"
        end

        def verbosity
          "overridden_verbosity"
        end

        def get(_key)
          "overridden_get"
        end

        def set(_key, _value = nil)
          "overridden_set"
        end

        def options
          "overridden_options"
        end

        def find_data(_path, **_kwargs)
          "overridden_find_data"
        end

        def exit(_code = 0)
          "overridden_exit"
        end
      end
    }
    let(:subctx) { subclass.new(data) }

    it "overriding args does not break __args" do
      assert_equal("overridden_args", subctx.args)
      assert_equal(["hello", "world"], subctx.__args)
    end

    it "overriding verbosity does not break __verbosity" do
      assert_equal("overridden_verbosity", subctx.verbosity)
      assert_equal(2, subctx.__verbosity)
    end

    it "overriding get does not break __get" do
      assert_equal("overridden_get", subctx.get(:my_flag))
      assert_equal("flagval", subctx.__get(:my_flag))
    end

    it "overriding set does not break __set" do
      assert_equal("overridden_set", subctx.set(:foo, "bar"))
      subctx.__set(:foo, "bar")
      assert_equal("bar", subctx.__get(:foo))
    end

    it "overriding options does not break __options" do
      assert_equal("overridden_options", subctx.options)
      assert_equal("flagval", subctx.__options[:my_flag])
    end

    it "overriding exit does not break __exit" do
      assert_equal("overridden_exit", subctx.exit(0))
      code = catch(:result) { subctx.__exit(42) }
      assert_equal(42, code)
    end
  end
end
