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

describe Toys::Tool do
  let(:lookup) { Toys::Lookup.new }
  let(:binary_name) { "toys" }
  let(:tool_name) { "foo" }
  let(:subtool_name) { "bar" }
  let(:subtool2_name) { "baz" }
  let(:root_tool) { Toys::Tool.new(lookup, []) }
  let(:tool) { Toys::Tool.new(lookup, [tool_name]) }
  let(:subtool) { Toys::Tool.new(lookup, [tool_name, subtool_name]) }
  let(:subtool2) { Toys::Tool.new(lookup, [tool_name, subtool2_name]) }
  let(:logger) {
    logger = Logger.new(StringIO.new)
    logger.level = Logger::WARN
    logger
  }
  let(:context_base) { Toys::Context::Base.new(lookup, binary_name, logger) }

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

  describe "definition state" do
    it "defaults to empty" do
      tool.includes_description?.must_equal false
      tool.includes_definition?.must_equal false
      tool.only_collection?.must_equal false
    end

    it "prevents defining from multiple paths" do
      tool.defining_from("path1") do
        tool.desc = "hi"
        tool.long_desc = "hiho"
      end
      proc do
        tool.desc = "ho"
      end.must_raise(Toys::ToolDefinitionError)
    end
  end

  describe "option parsing" do
    it "allows empty arguments when none are specified" do
      tool.executor = proc do
        options.must_equal({})
        args.must_equal []
      end
      tool.execute(context_base, 0, []).must_equal 0
    end

    it "defaults simple boolean switch to nil" do
      tool.add_switch(:a, "-a", "--aa", doc: "hi there")
      tool.executor = proc do
        options.must_equal({a: nil})
      end
      tool.execute(context_base, 0, []).must_equal 0
    end

    it "sets simple boolean switch" do
      tool.add_switch(:a, "-a", "--aa", doc: "hi there")
      tool.executor = proc do
        options.must_equal({a: true})
      end
      tool.execute(context_base, 0, ["--aa"]).must_equal 0
    end

    it "defaults value switch to nil" do
      tool.add_switch(:a, "-a", "--aa=VALUE", doc: "hi there")
      tool.executor = proc do
        options.must_equal({a: nil})
      end
      tool.execute(context_base, 0, []).must_equal 0
    end

    it "honors given default of a value switch" do
      tool.add_switch(:a, "-a", "--aa=VALUE", default: "hehe", doc: "hi there")
      tool.executor = proc do
        options.must_equal({a: "hehe"})
      end
      tool.execute(context_base, 0, []).must_equal 0
    end

    it "sets value switch" do
      tool.add_switch(:a, "-a", "--aa=VALUE", doc: "hi there")
      tool.executor = proc do
        options.must_equal({a: "hoho"})
      end
      tool.execute(context_base, 0, ["--aa", "hoho"]).must_equal 0
    end

    it "converts a value switch" do
      tool.add_switch(:a, "-a", "--aa=VALUE", accept: Integer, doc: "hi there")
      tool.executor = proc do
        options.must_equal({a: 1234})
      end
      tool.execute(context_base, 0, ["--aa", "1234"]).must_equal 0
    end

    it "checks match of a value switch" do
      tool.add_switch(:a, "-a", "--aa=VALUE", accept: Integer, doc: "hi there")
      tool.executor = proc do
        raise "shouldn't have gotten here"
      end
      proc do
        tool.execute(context_base, 0, ["--aa", "a1234"]).wont_equal 0
      end.must_output(/invalid argument: --aa a1234/)
    end

    it "defaults the name of a value switch" do
      tool.add_switch(:a_bc, doc: "hi there")
      tool.executor = proc do
        options.must_equal({a_bc: "hoho"})
      end
      tool.execute(context_base, 0, ["--a-bc", "hoho"]).must_equal 0
    end

    it "errors on an unknown switch" do
      tool.executor = proc do
        raise "shouldn't have gotten here"
      end
      proc do
        tool.execute(context_base, 0, ["-a"]).wont_equal 0
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
      tool.execute(context_base, 0, ["foo", "bar", "baz", "hello", "world"]).must_equal 0
    end

    it "omits optional args if not provided" do
      tool.add_optional_arg(:b)
      tool.add_optional_arg(:c)
      tool.add_required_arg(:a, doc: "Hello")
      tool.set_remaining_args(:d)
      tool.executor = proc do
        options.must_equal({a: "foo", b: "bar", c: nil, d: []})
      end
      tool.execute(context_base, 0, ["foo", "bar"]).must_equal 0
    end

    it "errors if required args are missing" do
      tool.add_required_arg(:a)
      tool.add_required_arg(:b)
      tool.executor = proc do
        raise "shouldn't have gotten here"
      end
      proc do
        tool.execute(context_base, 0, ["foo"]).wont_equal 0
      end.must_output(/No value given for required argument named <b>/)
    end

    it "errors if there are too many arguments" do
      tool.add_optional_arg(:b)
      tool.add_required_arg(:a)
      tool.executor = proc do
        raise "shouldn't have gotten here"
      end
      proc do
        tool.execute(context_base, 0, ["foo", "bar", "baz"]).wont_equal 0
      end.must_output(/Extra arguments provided: baz/)
    end

    it "honors defaults for optional arg" do
      tool.add_optional_arg(:b, default: "hello")
      tool.add_required_arg(:a)
      tool.executor = proc do
        options.must_equal({a: "foo", b: "hello"})
      end
      tool.execute(context_base, 0, ["foo"]).must_equal 0
    end
  end

  describe "default options" do
    it "honors --verbose flag" do
      tool.executor = proc do
        logger.level.must_equal(Logger::DEBUG)
      end
      tool.execute(context_base, 0, ["-v", "--verbose"]).must_equal 0
    end

    it "honors --quiet flag" do
      tool.executor = proc do
        logger.level.must_equal(Logger::FATAL)
      end
      tool.execute(context_base, 0, ["-q", "--quiet"]).must_equal 0
    end

    it "prints help for a command with an executor" do
      tool.executor = proc do
        raise "shouldn't have gotten here"
      end
      proc do
        tool.execute(context_base, 0, ["--help"]).must_equal 0
      end.must_output(/Usage:/)
    end

    it "prints help for a command with no executor" do
      proc do
        tool.execute(context_base, 0, []).must_equal 0
      end.must_output(/Usage:/)
    end
  end

  describe "helper" do
    it "can be defined on a tool" do
      tool.add_helper("hello_helper") { |val| val * 2 }
      tool.executor = proc do
        hello_helper(2).must_equal(4)
      end
      tool.execute(context_base, 0, []).must_equal(0)
    end

    it "cannot begin with an underscore" do
      proc do
        tool.add_helper("_hello_helper") { |val| val * 2 }
      end.must_raise(Toys::ToolDefinitionError)
    end
  end

  describe "helper module" do
    it "can be looked up from standard helpers" do
      tool.use_module(:file_utils)
      tool.executor = proc do
        private_methods.include?(:rm_rf).must_equal(true)
      end
      tool.execute(context_base, 0, []).must_equal(0)
    end
  end

  describe "aliases" do
  end
end
