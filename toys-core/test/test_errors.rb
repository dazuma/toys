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

    it "does not wrap a SignalException" do
      # A signal must stay recognizable as a signal all the way up the stack,
      # so that each tool can dispatch it to its own handler and the Ruby VM
      # can ultimately handle it.
      error = assert_raises(::SignalException) do
        Toys::ContextualError.capture { raise ::SignalException, "HUP" }
      end
      assert_equal(::Signal.list["HUP"], error.signo)
    end

    it "does not wrap an Interrupt" do
      assert_raises(::Interrupt) do
        Toys::ContextualError.capture { raise ::Interrupt }
      end
    end

    it "does not wrap a SignalException raised through nested captures" do
      error = assert_raises(::SignalException) do
        Toys::ContextualError.capture(banner: "outer", final: true) do
          Toys::ContextualError.capture(banner: "inner", final: true) do
            raise ::SignalException, 15
          end
        end
      end
      assert_equal(15, error.signo)
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

    it "adopts the original backtrace through nested wrappers" do
      # Each wrapper takes its backtrace from its cause, so every level must
      # continue to point at the code that actually failed. If a wrapper were
      # left with no backtrace, Ruby would fill one in at raise time, which
      # points into ContextualError.capture rather than the failing tool.
      original = nil
      error = assert_raises(Toys::ContextualError) do
        Toys::ContextualError.capture(banner: "outermost", final: true) do
          Toys::ContextualError.capture(banner: "middle", final: true) do
            Toys::ContextualError.capture(banner: "innermost", final: true) do
              original = RuntimeError.new("oops")
              raise original
            end
          end
        end
      end
      assert_equal original.backtrace, error.backtrace
      assert_equal original.backtrace, error.cause.backtrace
      assert_equal original.backtrace, error.cause.cause.backtrace
    end

    it "adopts the cause's backtrace when the cause has no backtrace locations" do
      # An exception that was built but never raised carries a string backtrace
      # only. The wrapper must still adopt it.
      original = RuntimeError.new("oops")
      original.set_backtrace(["/fake/path.rb:12:in 'run'"])
      assert_nil original.backtrace_locations
      error = assert_raises(Toys::ContextualError) do
        Toys::ContextualError.capture { raise original }
      end
      assert_equal ["/fake/path.rb:12:in 'run'"], error.backtrace
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

    it "names the original error once in the message of a nested error" do
      error = assert_raises(Toys::ContextualError) do
        Toys::ContextualError.capture(banner: "Outer", final: true) do
          Toys::ContextualError.capture(banner: "Inner", final: true) { raise "the message" }
        end
      end
      assert_equal "Outer: the message (RuntimeError)", error.message
    end

    it "names the original error once in the message of a doubly nested error" do
      error = assert_raises(Toys::ContextualError) do
        Toys::ContextualError.capture(banner: "Outermost", final: true) do
          Toys::ContextualError.capture(banner: "Middle", final: true) do
            Toys::ContextualError.capture(banner: "Innermost", final: true) do
              raise ::ArgumentError, "the message"
            end
          end
        end
      end
      assert_equal "Outermost: the message (ArgumentError)", error.message
    end

    it "uses the immediate cause in the message when there is no root cause" do
      # A ContextualError constructed outside a rescue has no cause at all, so
      # there is no root cause to fall back on. The message must still be
      # built rather than raising on nil.
      inner = Toys::ContextualError.new(::RuntimeError.new("orig"), "Inner", nil, nil, nil, true)
      assert_nil inner.root_cause
      outer = Toys::ContextualError.new(inner, "Outer", nil, nil, nil, true)
      assert_equal "Outer: Inner: orig (RuntimeError) (Toys::ContextualError)", outer.message
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

    # A wrapper locates the config line by searching its cause's backtrace
    # locations. Those survive from one wrapper to the next only on Rubies
    # where Exception#set_backtrace accepts location objects, so on older
    # Rubies only the innermost frame of a chain can resolve a config path.
    it "sets config_path on an outer frame wrapping a finalized error" do
      skip "Skipped test because Ruby is older than 3.4" if Toys::Compat::RUBY_VERSION_CODE < 30_400
      raise_line = nil
      error = assert_raises(Toys::ContextualError) do
        Toys::ContextualError.capture(banner: "outer", path: __FILE__, final: true) do
          Toys::ContextualError.capture(banner: "inner", final: true) do
            raise_line = __LINE__ + 1
            raise "oops"
          end
        end
      end
      # The outer capture built a new wrapper around the finalized inner one.
      assert_kind_of Toys::ContextualError, error.cause
      assert_equal "outer", error.banner
      assert_equal __FILE__, error.config_path
      assert_equal raise_line, error.config_line
    end

    it "retains backtrace locations across a wrapper" do
      skip "Skipped test because Ruby is older than 3.4" if Toys::Compat::RUBY_VERSION_CODE < 30_400
      original = nil
      error = assert_raises(Toys::ContextualError) do
        Toys::ContextualError.capture(banner: "outer", final: true) do
          Toys::ContextualError.capture(banner: "inner", final: true) do
            original = RuntimeError.new("oops")
            raise original
          end
        end
      end
      refute_nil error.backtrace_locations
      assert_equal original.backtrace_locations.map(&:to_s), error.backtrace_locations.map(&:to_s)
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

  describe "final" do
    it "is not final by default" do
      error = assert_raises(Toys::ContextualError) do
        Toys::ContextualError.capture { raise "oops" }
      end
      refute(error.final?)
    end

    it "is final when captured with final: true" do
      error = assert_raises(Toys::ContextualError) do
        Toys::ContextualError.capture(final: true) { raise "oops" }
      end
      assert(error.final?)
    end

    it "merges a non-final error into the outer capture" do
      inner_error = nil
      error = assert_raises(Toys::ContextualError) do
        Toys::ContextualError.capture(banner: "outer", tool_name: ["outer-tool"]) do
          inner_error = assert_raises(Toys::ContextualError) do
            Toys::ContextualError.capture(banner: "inner") { raise "oops" }
          end
          raise inner_error
        end
      end
      assert_same(inner_error, error)
      assert_equal("inner", error.banner)
      assert_equal(["outer-tool"], error.tool_name)
    end

    it "finalizes a non-final error merged by a final capture" do
      error = assert_raises(Toys::ContextualError) do
        Toys::ContextualError.capture(banner: "outer", final: true) do
          Toys::ContextualError.capture(banner: "inner") { raise "oops" }
        end
      end
      assert(error.final?)
      assert_equal("inner", error.banner)
    end

    it "does not clear the final flag of an error passing through a non-final capture" do
      # Once finalized, an error must stay finalized, so a later non-final
      # capture nests rather than merging into it.
      error = assert_raises(Toys::ContextualError) do
        Toys::ContextualError.capture(banner: "outermost") do
          Toys::ContextualError.capture(banner: "outer", final: true) do
            Toys::ContextualError.capture(banner: "inner") { raise "oops" }
          end
        end
      end
      assert_equal("outermost", error.banner)
      refute(error.final?)
      assert(error.cause.final?)
      assert_equal("inner", error.cause.banner)
    end

    it "wraps a final error in a new error rather than merging" do
      inner_error = nil
      error = assert_raises(Toys::ContextualError) do
        Toys::ContextualError.capture(banner: "outer", tool_name: ["outer-tool"]) do
          inner_error = assert_raises(Toys::ContextualError) do
            Toys::ContextualError.capture(banner: "inner", tool_name: ["inner-tool"], final: true) do
              raise "oops"
            end
          end
          raise inner_error
        end
      end
      refute_same(inner_error, error)
      assert_equal("outer", error.banner)
      assert_equal(["outer-tool"], error.tool_name)
      assert_same(inner_error, error.cause)
      assert_equal("inner", error.cause.banner)
      assert_equal(["inner-tool"], error.cause.tool_name)
      assert_equal("oops", error.cause.cause.message)
    end

    it "propagates the final setting to a wrapping error" do
      error = assert_raises(Toys::ContextualError) do
        Toys::ContextualError.capture(banner: "outer", final: true) do
          Toys::ContextualError.capture(banner: "inner", final: true) { raise "oops" }
        end
      end
      assert(error.final?)
      assert(error.cause.final?)
    end
  end

  describe "root_cause" do
    it "returns the original error for a single level" do
      original = ::RuntimeError.new("the original")
      error = assert_raises(Toys::ContextualError) do
        Toys::ContextualError.capture { raise original }
      end
      assert_same(original, error.root_cause)
    end

    it "returns the original error through multiple nested levels" do
      error = assert_raises(Toys::ContextualError) do
        Toys::ContextualError.capture(banner: "outermost", final: true) do
          Toys::ContextualError.capture(banner: "middle", final: true) do
            Toys::ContextualError.capture(banner: "innermost", final: true) do
              raise ::ArgumentError, "the original"
            end
          end
        end
      end
      assert_kind_of(::ArgumentError, error.root_cause)
      assert_equal("the original", error.root_cause.message)
    end

    it "stops at the first non-contextual error in the cause chain" do
      error = assert_raises(Toys::ContextualError) do
        Toys::ContextualError.capture(final: true) do
          raise ::ArgumentError, "underlying"
        rescue ::ArgumentError
          raise "outer error"
        end
      end
      root = error.root_cause
      assert_kind_of(::RuntimeError, root)
      assert_equal("outer error", root.message)
      assert_kind_of(::ArgumentError, root.cause)
    end
  end
end
