# frozen_string_literal: true

require "helper"

describe Toys::ArgParsingError do
  let(:flag_error) { Toys::ArgParser::FlagUnrecognizedError.new(value: "--badFlag") }
  let(:arg_error) { Toys::ArgParser::ArgMissingError.new(name: "myarg") }
  let(:error) { Toys::ArgParsingError.new([flag_error, arg_error]) }

  it "stores the usage errors array" do
    assert_equal [flag_error, arg_error], error.usage_errors
  end

  it "sets message to the errors joined by newlines" do
    assert_equal [flag_error.to_s, arg_error.to_s].join("\n"), error.message
  end
end

describe Toys::ContextualError do
  describe ".capture basic behavior" do
    it "returns the block's value when no exception is raised" do
      result = Toys::ContextualError.capture { 42 }
      assert_equal 42, result
    end

    it "wraps a StandardError in a ContextualError" do
      assert_raises(Toys::ContextualError) do
        Toys::ContextualError.capture { raise "oops" }
      end
    end

    it "wraps a ScriptError in a ContextualError" do
      assert_raises(Toys::ContextualError) do
        Toys::ContextualError.capture { raise ::ScriptError, "script error" }
      end
    end

    it "wraps a SignalException in a ContextualError" do
      assert_raises(Toys::ContextualError) do
        Toys::ContextualError.capture { raise ::SignalException, "HUP" }
      end
    end

    it "passes through an existing ContextualError without re-wrapping" do
      inner_error = nil
      error = assert_raises(Toys::ContextualError) do
        Toys::ContextualError.capture(banner: "outer") do
          inner_error = assert_raises(Toys::ContextualError) do
            Toys::ContextualError.capture(banner: "inner") { raise "oops" }
          end
          raise inner_error
        end
      end
      assert_same inner_error, error
      assert_equal "inner", error.banner
    end
  end

  describe "attributes" do
    it "sets cause to the original exception" do
      original = RuntimeError.new("the original")
      error = assert_raises(Toys::ContextualError) do
        Toys::ContextualError.capture { raise original }
      end
      assert_same original, error.cause
    end

    it "adopts the cause's backtrace" do
      original = nil
      error = assert_raises(Toys::ContextualError) do
        Toys::ContextualError.capture do
          original = RuntimeError.new("oops")
          raise original
        end
      end
      assert_equal original.backtrace, error.backtrace
    end

    it "sets banner from keyword argument" do
      error = assert_raises(Toys::ContextualError) do
        Toys::ContextualError.capture(banner: "My Banner") { raise "oops" }
      end
      assert_equal "My Banner", error.banner
    end

    it "defaults banner to 'Unexpected error' when not provided" do
      error = assert_raises(Toys::ContextualError) do
        Toys::ContextualError.capture { raise "oops" }
      end
      assert_equal "Unexpected error", error.banner
    end

    it "includes banner, cause message, and cause class in message" do
      error = assert_raises(Toys::ContextualError) do
        Toys::ContextualError.capture(banner: "My Banner") { raise "the message" }
      end
      assert_equal "My Banner: the message (RuntimeError)", error.message
    end

    it "sets tool_name from keyword argument" do
      error = assert_raises(Toys::ContextualError) do
        Toys::ContextualError.capture(tool_name: ["my", "tool"]) { raise "oops" }
      end
      assert_equal ["my", "tool"], error.tool_name
    end

    it "leaves tool_name nil when not provided" do
      error = assert_raises(Toys::ContextualError) do
        Toys::ContextualError.capture { raise "oops" }
      end
      assert_nil error.tool_name
    end

    it "sets tool_args from keyword argument" do
      error = assert_raises(Toys::ContextualError) do
        Toys::ContextualError.capture(tool_args: ["--flag", "val"]) { raise "oops" }
      end
      assert_equal ["--flag", "val"], error.tool_args
    end

    it "leaves tool_args nil when not provided" do
      error = assert_raises(Toys::ContextualError) do
        Toys::ContextualError.capture { raise "oops" }
      end
      assert_nil error.tool_args
    end

    it "leaves config_path and config_line nil when no path provided" do
      error = assert_raises(Toys::ContextualError) do
        Toys::ContextualError.capture { raise "oops" }
      end
      assert_nil error.config_path
      assert_nil error.config_line
    end

    it "leaves config_path and config_line nil when path does not match backtrace" do
      error = assert_raises(Toys::ContextualError) do
        Toys::ContextualError.capture(path: "/no/such/path.rb") { raise "oops" }
      end
      assert_nil error.config_path
      assert_nil error.config_line
    end
  end

  describe "config_path and config_line from backtrace" do
    it "sets config_path and config_line when path matches a backtrace frame" do
      raise_line = nil
      error = assert_raises(Toys::ContextualError) do
        Toys::ContextualError.capture(path: __FILE__) do
          raise_line = __LINE__ + 1
          raise "oops"
        end
      end
      assert_equal __FILE__, error.config_path
      assert_equal raise_line, error.config_line
    end
  end

  describe "config_path and config_line from SyntaxError message" do
    it "extracts line from SyntaxError message when path matches" do
      path = "/fake/config/file.rb"
      error = assert_raises(Toys::ContextualError) do
        Toys::ContextualError.capture(path: path) do
          raise ::SyntaxError, "#{path}:42: unexpected keyword end"
        end
      end
      assert_equal path, error.config_path
      assert_equal 42, error.config_line
    end

    it "still wraps SyntaxError even when path does not match message" do
      # Verifies that a non-matching SyntaxError is still wrapped as a ContextualError,
      # not re-raised bare (which would bypass the error handler in CLI#run).
      path = "/fake/config/file.rb"
      error = assert_raises(Toys::ContextualError) do
        Toys::ContextualError.capture(path: path) do
          raise ::SyntaxError, "/different/path.rb:10: unexpected keyword end"
        end
      end
      assert_kind_of Toys::ContextualError, error
      assert_nil error.config_path
      assert_nil error.config_line
    end

    it "falls back to backtrace for SyntaxError when message does not contain path" do
      raise_line = nil
      error = assert_raises(Toys::ContextualError) do
        Toys::ContextualError.capture(path: __FILE__) do
          raise_line = __LINE__ + 1
          raise ::SyntaxError, "generic syntax error with no path"
        end
      end
      assert_equal __FILE__, error.config_path
      assert_equal raise_line, error.config_line
    end
  end

  describe "nested capture (update_fields! behavior)" do
    it "outer capture fills in nil tool_name from inner capture" do
      error = assert_raises(Toys::ContextualError) do
        Toys::ContextualError.capture(tool_name: ["outer-tool"]) do
          Toys::ContextualError.capture do
            raise "oops"
          end
        end
      end
      assert_equal ["outer-tool"], error.tool_name
    end

    it "inner tool_name is preserved when outer capture also has tool_name" do
      error = assert_raises(Toys::ContextualError) do
        Toys::ContextualError.capture(tool_name: ["outer-tool"]) do
          Toys::ContextualError.capture(tool_name: ["inner-tool"]) do
            raise "oops"
          end
        end
      end
      assert_equal ["inner-tool"], error.tool_name
    end

    it "outer capture fills in nil tool_args from inner capture" do
      error = assert_raises(Toys::ContextualError) do
        Toys::ContextualError.capture(tool_args: ["outer-arg"]) do
          Toys::ContextualError.capture do
            raise "oops"
          end
        end
      end
      assert_equal ["outer-arg"], error.tool_args
    end

    it "inner tool_args is preserved when outer capture also has tool_args" do
      error = assert_raises(Toys::ContextualError) do
        Toys::ContextualError.capture(tool_args: ["outer-arg"]) do
          Toys::ContextualError.capture(tool_args: ["inner-arg"]) do
            raise "oops"
          end
        end
      end
      assert_equal ["inner-arg"], error.tool_args
    end

    it "outer capture fills in nil config_path when path matches backtrace" do
      # Inner capture has no path; outer capture provides the path.
      # The exception was raised in __FILE__, so the outer path lookup succeeds.
      error = assert_raises(Toys::ContextualError) do
        Toys::ContextualError.capture(path: __FILE__) do
          Toys::ContextualError.capture do
            raise "oops"
          end
        end
      end
      assert_equal __FILE__, error.config_path
      assert_kind_of ::Integer, error.config_line
    end

    it "inner config_path is preserved when outer capture also has a path" do
      # Inner capture provides path: __FILE__, which matches the backtrace.
      # Outer capture has a different (non-matching) path and should not overwrite.
      error = assert_raises(Toys::ContextualError) do
        Toys::ContextualError.capture(path: "/outer/fake.rb") do
          Toys::ContextualError.capture(path: __FILE__) do
            raise "oops"
          end
        end
      end
      assert_equal __FILE__, error.config_path
    end
  end
end
