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

    it "handles Interrupted exceptions" do
      Toys::ContextualError.capture(banner: banner) do
        raise Interrupt
      end
      flunk
    rescue Toys::ContextualError => e
      result = default_ui.handle_error(e)
      assert_equal(130, result)
      assert_equal("\nINTERRUPTED\n", output_content)
    end

    it "handles SignalException" do
      Toys::ContextualError.capture(banner: banner) do
        raise SignalException, 15
      end
      flunk
    rescue Toys::ContextualError => e
      result = default_ui.handle_error(e)
      assert_equal(143, result)
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
