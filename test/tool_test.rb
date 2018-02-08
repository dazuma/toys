require "helper"

describe Toys::Tool do
  let(:tool_name) { "foo" }
  let(:subtool_name) { "bar" }
  let(:root_tool) { Toys::Tool.new(nil, nil) }
  let(:tool) { Toys::Tool.new(root_tool, tool_name) }
  let(:subtool) { Toys::Tool.new(tool, subtool_name) }
  let(:logger) {
    logger = Logger.new(StringIO.new)
    logger.level = Logger::WARN
    logger
  }
  let(:context) { Toys::Context.new(Toys::Lookup.new, logger: logger) }

  describe "names" do
    it "works for a root tool" do
      root_tool.simple_name.must_be_nil
      root_tool.full_name.must_equal []
    end

    it "works for a toplevel tool" do
      tool.simple_name.must_equal tool_name
      tool.full_name.must_equal [tool_name]
    end

    it "works for a subtool" do
      subtool.simple_name.must_equal subtool_name
      subtool.full_name.must_equal [tool_name, subtool_name]
    end
  end

  describe "field setting" do
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

  describe "option parsing" do
    it "allows empty arguments when none are specified" do
      tool.executor = proc do
        options.must_equal({})
        args.must_equal []
      end
      tool.execute(context, []).must_equal 0
    end

    it "defaults simple boolean switch to nil" do
      tool.add_switch(:a, "-a", "--aa", doc: "hi there")
      tool.executor = proc do
        options.must_equal({a: nil})
      end
      tool.execute(context, []).must_equal 0
    end

    it "sets simple boolean switch" do
      tool.add_switch(:a, "-a", "--aa", doc: "hi there")
      tool.executor = proc do
        options.must_equal({a: true})
      end
      tool.execute(context, ["--aa"]).must_equal 0
    end

    it "defaults value switch to nil" do
      tool.add_switch(:a, "-a", "--aa=VALUE", doc: "hi there")
      tool.executor = proc do
        options.must_equal({a: nil})
      end
      tool.execute(context, []).must_equal 0
    end

    it "honors given default of a value switch" do
      tool.add_switch(:a, "-a", "--aa=VALUE", default: "hehe", doc: "hi there")
      tool.executor = proc do
        options.must_equal({a: "hehe"})
      end
      tool.execute(context, []).must_equal 0
    end

    it "sets value switch" do
      tool.add_switch(:a, "-a", "--aa=VALUE", doc: "hi there")
      tool.executor = proc do
        options.must_equal({a: "hoho"})
      end
      tool.execute(context, ["--aa", "hoho"]).must_equal 0
    end

    it "converts a value switch" do
      tool.add_switch(:a, "-a", "--aa=VALUE", accept: Integer, doc: "hi there")
      tool.executor = proc do
        options.must_equal({a: 1234})
      end
      tool.execute(context, ["--aa", "1234"]).must_equal 0
    end

    it "checks match of a value switch" do
      tool.add_switch(:a, "-a", "--aa=VALUE", accept: Integer, doc: "hi there")
      tool.executor = proc do
        raise "shouldn't have gotten here"
      end
      proc do
        tool.execute(context, ["--aa", "a1234"]).wont_equal 0
      end.must_output(/invalid argument: --aa a1234/)
    end

    it "defaults the name of a value switch" do
      tool.add_switch(:a_bc, doc: "hi there")
      tool.executor = proc do
        options.must_equal({a_bc: "hoho"})
      end
      tool.execute(context, ["--a-bc", "hoho"]).must_equal 0
    end

    it "errors on an unknown switch" do
      tool.executor = proc do
        raise "shouldn't have gotten here"
      end
      proc do
        tool.execute(context, ["-a"]).wont_equal 0
      end.must_output(/invalid option: -a/)
    end

    it "recognizes args in order" do
      tool.add_optional_arg(:b)
      tool.add_optional_arg(:c)
      tool.add_required_arg(:a, doc: "Hello")
      tool.set_remaining_args(:d)
      tool.executor = proc do
        options.must_equal({a: "foo", b: "bar", c: "baz", d: ["hello", "world"]})
      end
      tool.execute(context, ["foo", "bar", "baz", "hello", "world"]).must_equal 0
    end

    it "omits optional args if not provided" do
      tool.add_optional_arg(:b)
      tool.add_optional_arg(:c)
      tool.add_required_arg(:a, doc: "Hello")
      tool.set_remaining_args(:d)
      tool.executor = proc do
        options.must_equal({a: "foo", b: "bar", c: nil, d: []})
      end
      tool.execute(context, ["foo", "bar"]).must_equal 0
    end

    it "errors if required args are missing" do
      tool.add_required_arg(:a)
      tool.add_required_arg(:b)
      tool.executor = proc do
        raise "shouldn't have gotten here"
      end
      proc do
        tool.execute(context, ["foo"]).wont_equal 0
      end.must_output(/No value given for required argument named <b>/)
    end

    it "errors if there are too many arguments" do
      tool.add_optional_arg(:b)
      tool.add_required_arg(:a)
      tool.executor = proc do
        raise "shouldn't have gotten here"
      end
      proc do
        tool.execute(context, ["foo", "bar", "baz"]).wont_equal 0
      end.must_output(/Extra arguments provided: baz/)
    end

    it "honors defaults for optional arg" do
      tool.add_optional_arg(:b, default: "hello")
      tool.add_required_arg(:a)
      tool.executor = proc do
        options.must_equal({a: "foo", b: "hello"})
      end
      tool.execute(context, ["foo"]).must_equal 0
    end
  end

  describe "default options" do
    it "honors --verbose flag" do
      tool.executor = proc do
        logger.level.must_equal(Logger::DEBUG)
      end
      tool.execute(context, ["-v", "--verbose"]).must_equal 0
    end

    it "honors --quiet flag" do
      tool.executor = proc do
        logger.level.must_equal(Logger::FATAL)
      end
      tool.execute(context, ["-q", "--quiet"]).must_equal 0
    end

    it "prints help for a command with an executor" do
      tool.executor = proc do
        raise "shouldn't have gotten here"
      end
      proc do
        tool.execute(context, ["--help"]).must_equal 0
      end.must_output(/Usage:/)
    end

    it "prints help for a command with no executor" do
      proc do
        tool.execute(context, []).must_equal 0
      end.must_output(/Usage:/)
    end
  end
end
