# frozen_string_literal: true

require "helper"
require "toys/utils/standard_ui"

describe Toys::Utils::StandardUI do
  let(:output_buffer) { StringIO.new }
  let(:output_content) { output_buffer.string }
  let(:output_lines) { output_content.lines.map(&:chomp).reject(&:empty?) }
  let(:default_ui) { Toys::Utils::StandardUI.new(output: output_buffer) }
  let(:ui_with_abbrev_backtrace) do
    Toys::Utils::StandardUI.new(output: output_buffer,
                                backtrace_omit_prefixes: Toys.framework_lib_paths,
                                incomplete_backtrace_message: "(Backtrace abbreviated)")
  end
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
    def capture_nested_error(inner_banner: "inner banner", outer_banner: "outer banner", &block)
      Toys::ContextualError.capture(banner: outer_banner, tool_name: ["front"], tool_verb: "running", final: true) do
        Toys::ContextualError.capture(banner: inner_banner, tool_name: ["target"],
                                      tool_args: ["arg1"], tool_verb: "running", final: true, &block)
      end
      flunk
    rescue Toys::ContextualError => e
      e
    end

    # Raises from a synthetic file, so that a capture given that path resolves
    # a tool file location pointing into it rather than into this test file. The
    # fabricated backtrace location is the whole point here, which is why the
    # eval does not use __FILE__ as the cop would otherwise want.
    def raise_from(path, line)
      eval("raise 'foobar'", binding, path, line) # rubocop:disable Style/EvalWithLocation
    end

    it "generates basic exception output" do
      Toys::ContextualError.capture(banner: banner,
                                    tool_name: tool_name,
                                    tool_args: tool_args,
                                    tool_verb: "running") do
        raise "foobar"
      end
      flunk
    rescue Toys::ContextualError => e
      default_ui.handle_error(e)
      assert_includes(output_lines, "Backtrace (outermost to innermost)")
      assert_includes(output_lines, "my banner: foobar (RuntimeError)")
      assert_includes(output_lines, 'while running tool: "tool1 tool2", with arguments: ["arg1", "arg2"]')
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

    it "displays the correct banner for nested errors" do
      error = capture_nested_error { raise "foobar" }
      default_ui.handle_error(error)
      assert_includes(output_lines, "inner banner: foobar (RuntimeError)")
      refute(output_lines.any? { |line| line.include?("outer banner") })
    end

    it "displays the nested frames in order" do
      error = capture_nested_error { raise "foobar" }
      default_ui.handle_error(error)
      assert_equal(["while running tool: \"target\", with arguments: [\"arg1\"]",
                    "while running tool: \"front\""],
                   output_lines[-2, 2])
    end

    it "displays the backtrace omitting internal frames" do
      error =
        begin
          Toys::ContextualError.capture(banner: "b", path: "/fake/inner.rb",
                                        tool_name: ["front"], final: true) do
            Toys::ContextualError.capture(banner: "b", path: "/fake/inner.rb",
                                          tool_name: ["target"], final: true) do
              raise_from("/fake/inner.rb", 7)
            end
          end
          flunk
        rescue Toys::ContextualError => e
          e
        end
      ui_with_abbrev_backtrace.handle_error(error)
      assert(output_lines.any? { |line| %r{\d+: /fake/inner\.rb:7}.match?(line) })
      assert(output_lines.any? { |line| /\(\.\.\.\d+ internal framework frames?\.\.\.\)/.match?(line) })
      assert_includes(output_lines, "    (Backtrace abbreviated)")
    end

    it "displays the backtrace including internal frames" do
      error =
        begin
          Toys::ContextualError.capture(banner: "b", path: "/fake/inner.rb",
                                        tool_name: ["front"], final: true) do
            Toys::ContextualError.capture(banner: "b", path: "/fake/inner.rb",
                                          tool_name: ["target"], final: true) do
              raise_from("/fake/inner.rb", 7)
            end
          end
          flunk
        rescue Toys::ContextualError => e
          e
        end
      default_ui.handle_error(error)
      assert(output_lines.any? { |line| %r{\d+: /fake/inner\.rb:7}.match?(line) })
      assert(output_lines.none? { |line| /\(\.\.\.\d+ internal framework frames?\.\.\.\)/.match?(line) })
    end

    it "displays a text-only backtrace" do
      error = ::RuntimeError.new("foobar")
      error.set_backtrace(["/fake/one.rb:5", "/fake/two.rb:10"])
      default_ui.handle_error(error)
      assert(output_lines.any? { |line| %r{\d+: /fake/one\.rb:5}.match?(line) })
      assert(output_lines.any? { |line| %r{\d+: /fake/two\.rb:10}.match?(line) })
    end

    it "displays a text-only backtrace with eliding" do
      error = ::RuntimeError.new("foobar")
      error.set_backtrace(["/fake/one.rb:5", "#{Toys::CORE_LIB_PATH}/two.rb:10"])
      ui_with_abbrev_backtrace.handle_error(error)
      assert(output_lines.any? { |line| %r{\d+: /fake/one\.rb:5}.match?(line) })
      refute(output_lines.any? { |line| %r{\d+: #{Toys::CORE_LIB_PATH}/two\.rb:10}.match?(line) })
    end

    it "displays only the inmost tool path" do
      error =
        begin
          Toys::ContextualError.capture(banner: "b", path: "/fake/outer.rb",
                                        tool_name: ["front"], final: true) do
            Toys::ContextualError.capture(banner: "b", path: "/fake/inner.rb",
                                          tool_name: ["target"], final: true) do
              raise_from("/fake/inner.rb", 7)
            end
          end
          flunk
        rescue Toys::ContextualError => e
          e
        end
      default_ui.handle_error(error)
      assert_includes(output_lines, "    (/fake/inner.rb:7)")
      refute(output_lines.any? { |line| line.include?("outer.rb") })
    end

    it "supports a single frame with a path but no tool name" do
      error =
        begin
          Toys::ContextualError.capture(banner: "b", path: "/fake/inner.rb", final: true) do
            raise_from("/fake/inner.rb", 7)
          end
          flunk
        rescue Toys::ContextualError => e
          e
        end
      default_ui.handle_error(error)
      assert_equal(["b: foobar (RuntimeError)", "    (/fake/inner.rb:7)"],
                   output_lines[-2, 2])
    end

    it "supports the root tool" do
      error =
        begin
          Toys::ContextualError.capture(banner: "b", path: "/fake/inner.rb",
                                        tool_verb: "running", tool_name: [], final: true) do
            raise_from("/fake/inner.rb", 7)
          end
          flunk
        rescue Toys::ContextualError => e
          e
        end
      default_ui.handle_error(error)
      assert_equal(["b: foobar (RuntimeError)",
                    "    (/fake/inner.rb:7)",
                    "while running the root tool"],
                   output_lines[-3, 3])
    end

    it "handles frames that carry different fields" do
      error =
        begin
          Toys::ContextualError.capture(banner: "Outer banner", tool_name: ["front"],
                                        tool_verb: "running", final: true) do
            Toys::ContextualError.capture(banner: "Inner banner", tool_name: ["target"],
                                          tool_args: ["arg1"], tool_verb: "loading", final: true) do
              raise "foobar"
            end
          end
          flunk
        rescue Toys::ContextualError => e
          e
        end
      default_ui.handle_error(error)
      assert_equal(["Inner banner: foobar (RuntimeError)",
                    "while loading tool: \"target\", with arguments: [\"arg1\"]",
                    "while running tool: \"front\""],
                   output_lines[-3, 3])
    end

    it "handles a non-contextual error" do
      error = assert_raises(::RuntimeError) { raise_from("/fake/inner.rb", 7) }
      assert_equal(1, default_ui.handle_error(error))
      assert(output_lines.any? { |line| %r{\d+: /fake/inner\.rb:7}.match?(line) })
      assert_equal("foobar (RuntimeError)", output_lines.last)
      refute_includes(output_lines, "(/fake/inner.rb:7)")
    end

    it "does not crash on a contextual error with no cause" do
      error = Toys::ContextualError.new(::RuntimeError.new("foobar"), "b", nil, "running", ["t"], nil, true)
      assert_nil(error.root_cause)
      assert_equal(1, default_ui.handle_error(error))
      assert_includes(output_content, "while running tool: \"t\"")
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

    it "returns the exit code for a bare error" do
      error = assert_raises(Toys::NotRunnableError) { raise Toys::NotRunnableError }
      assert_equal(126, default_ui.handle_error(error))
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
