# frozen_string_literal: true

require "helper"
require "toys/utils/standard_ui"

describe Toys::Utils::StandardUI do
  let(:output_buffer) { StringIO.new }
  let(:output_content) { output_buffer.string }
  let(:default_ui) { Toys::Utils::StandardUI.new(output: output_buffer) }
  let(:banner) { "my banner" }
  let(:tool_name) { ["tool1", "tool2"] }
  let(:tool_args) { ["arg1", "arg2"] }

  it "creates CLI args" do
    args = default_ui.cli_args
    assert_equal([:error_handler, :logger_factory], args.keys)
    assert_kind_of(::Proc, args[:error_handler])
    assert_kind_of(::Proc, args[:logger_factory])
  end

  describe "handle_error" do
    it "generates expected exception output" do
      Toys::ContextualError.capture(banner: banner, tool_name: tool_name, tool_args: tool_args) do
        raise "foobar"
      end
      flunk
    rescue Toys::ContextualError => e
      default_ui.handle_error(e)
      assert_includes(output_content, "foobar")
      assert_includes(output_content, banner)
      assert_includes(output_content, "tool1 tool2")
      assert_includes(output_content, '["arg1", "arg2"]')
    end

    it "returns the exit code for RuntimeError" do
      Toys::ContextualError.capture(banner: banner) do
        raise "foobar"
      end
      flunk
    rescue Toys::ContextualError => e
      result = default_ui.handle_error(e)
      assert_equal(1, result)
    end

    it "returns the exit code for ArgParsingError" do
      Toys::ContextualError.capture(banner: banner) do
        raise Toys::ArgParsingError, []
      end
      flunk
    rescue Toys::ContextualError => e
      result = default_ui.handle_error(e)
      assert_equal(2, result)
    end

    it "returns the exit code for NotRunnableError" do
      Toys::ContextualError.capture(banner: banner) do
        raise Toys::NotRunnableError
      end
      flunk
    rescue Toys::ContextualError => e
      result = default_ui.handle_error(e)
      assert_equal(126, result)
    end

    # Signals are never wrapped in a ContextualError, so the error handler
    # receives them bare. `capture` is used here only to give them a backtrace.
    it "handles Interrupted exceptions" do
      Toys::ContextualError.capture(banner: banner) do
        raise Interrupt
      end
      flunk
    rescue Interrupt => e
      result = default_ui.handle_error(e)
      assert_equal(130, result)
      assert_equal("\nINTERRUPTED\n", output_content)
    end

    it "handles SignalException" do
      Toys::ContextualError.capture(banner: banner) do
        raise SignalException, 15
      end
      flunk
    rescue SignalException => e
      result = default_ui.handle_error(e)
      assert_equal(143, result)
      assert_equal("\nSIGNAL RECEIVED: SIGTERM\n", output_content)
    end
  end

  describe "handle_error with nested errors" do
    def capture_nested_error(inner_banner: "inner banner", outer_banner: "outer banner", &block)
      Toys::ContextualError.capture(banner: outer_banner, tool_name: ["front"], final: true) do
        Toys::ContextualError.capture(banner: inner_banner, tool_name: ["target"],
                                      tool_args: ["arg1"], final: true, &block)
      end
      flunk
    rescue Toys::ContextualError => e
      e
    end

    it "reports the original error rather than the intermediate error" do
      error = capture_nested_error { raise "foobar" }
      default_ui.handle_error(error)
      lines = output_content.lines.map(&:chomp).reject(&:empty?)
      assert_equal("RuntimeError: foobar", lines.first)
      reported = lines.grep(/^ +\S+Error: /)
      assert_equal(["    RuntimeError: foobar", "    RuntimeError: foobar"], reported)
    end

    it "displays a context block for each level, innermost first" do
      error = capture_nested_error { raise "foobar" }
      default_ui.handle_error(error)
      inner_index = output_content.index("inner banner")
      outer_index = output_content.index("outer banner")
      refute_nil(inner_index)
      refute_nil(outer_index)
      assert(inner_index < outer_index, "expected the inner context block to be displayed first")
      assert_includes(output_content, "target")
      assert_includes(output_content, "front")
      assert_includes(output_content, '["arg1"]')
    end

    it "returns the exit code for the original error" do
      error = capture_nested_error { raise Toys::NotRunnableError }
      assert_equal(126, default_ui.handle_error(error))
    end

    # A signal raised inside nested captures is not wrapped by any of them, so
    # it reaches the handler bare no matter how deep the nesting.
    it "passes an Interrupt through the nesting unwrapped" do
      error = assert_raises(Interrupt) do
        capture_nested_error { raise Interrupt }
      end
      assert_equal(130, default_ui.handle_error(error))
      assert_equal("\nINTERRUPTED\n", output_content)
    end

    it "passes a SignalException through the nesting unwrapped" do
      error = assert_raises(SignalException) do
        capture_nested_error { raise SignalException, 15 }
      end
      assert_equal(143, default_ui.handle_error(error))
      assert_equal("\nSIGNAL RECEIVED: SIGTERM\n", output_content)
    end
  end

  describe "create_logger" do
    it "makes a logger that outputs the expected format" do
      logger = default_ui.create_logger(nil)
      logger.warn "foobar"
      assert_includes(output_content, "  WARN]")
      assert_includes(output_content, "foobar")
    end
  end
end
