# frozen_string_literal: true

require "helper"
require "toys/utils/standard_ui"
require "toys/utils/terminal"

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

  describe "logging" do
    let(:unstyled_ui) {
      Toys::Utils::StandardUI.new(output: Toys::Utils::Terminal.new(output: output_buffer, styled: false))
    }
    let(:styled_ui) {
      Toys::Utils::StandardUI.new(output: Toys::Utils::Terminal.new(output: output_buffer, styled: true))
    }
    let(:detailed_header) { /\[\d{4}-\d\d-\d\d \d\d:\d\d:\d\d  WARN\]/ }

    # A subclass that refers to plain `Logger` searches the ancestors of the
    # class before the top level, so StandardUI must not define a `Logger`
    # constant that would shadow `::Logger`.
    it "does not shadow ::Logger in subclasses" do
      refute(Toys::Utils::StandardUI.const_defined?(:Logger, false))
    end

    def raise_error
      raise "boom"
    rescue ::RuntimeError => e
      e
    end

    it "makes a logger supporting the verbosity protocol" do
      logger = unstyled_ui.create_logger(nil)
      assert_instance_of(Toys::Utils::StandardUI::VerbosityLogger, logger)
      assert_kind_of(::Logger, logger)
      assert_equal(0, logger.verbosity)
      logger.verbosity = 2
      assert_equal(2, logger.verbosity)
    end

    it "makes a logger with a level of WARN" do
      assert_equal(::Logger::WARN, unstyled_ui.create_logger(nil).level)
    end

    it "uses the simple format at zero verbosity" do
      logger = unstyled_ui.create_logger(nil)
      logger.warn("foobar")
      assert_equal("WARN: foobar\n", output_content)
    end

    it "uses the simple format at negative verbosity" do
      logger = unstyled_ui.create_logger(nil)
      logger.verbosity = -1
      logger.error("foobar")
      assert_equal("ERROR: foobar\n", output_content)
    end

    it "uses the detailed format at positive verbosity" do
      logger = unstyled_ui.create_logger(nil)
      logger.verbosity = 1
      logger.warn("foobar")
      assert_match(/\A#{detailed_header}  foobar\n\z/, output_content)
    end

    it "follows verbosity changes on an existing logger" do
      logger = unstyled_ui.create_logger(nil)
      logger.warn("one")
      logger.verbosity = 1
      logger.warn("two")
      logger.verbosity = 0
      logger.warn("three")
      lines = output_content.lines
      assert_equal("WARN: one\n", lines[0])
      assert_match(/\A#{detailed_header}  two\n\z/, lines[1])
      assert_equal("WARN: three\n", lines[2])
    end

    it "prefixes only the first line of a multi-line message in the simple format" do
      logger = unstyled_ui.create_logger(nil)
      logger.error("line one\nline two")
      assert_equal("ERROR: line one\nline two\n", output_content)
    end

    it "omits the backtrace of an exception in the simple format" do
      logger = unstyled_ui.create_logger(nil)
      logger.error(raise_error)
      assert_equal("ERROR: boom (RuntimeError)\n", output_content)
    end

    it "includes the backtrace of an exception in the detailed format" do
      error = raise_error
      logger = unstyled_ui.create_logger(nil)
      logger.verbosity = 1
      logger.error(error)
      lines = output_content.lines
      assert_match(/ERROR\]  boom \(RuntimeError\)\n\z/, lines[0])
      assert_equal(error.backtrace.map { |line| "#{line}\n" }, lines[1..])
    end

    it "inspects a message that is not a string" do
      logger = unstyled_ui.create_logger(nil)
      logger.warn([:foo, 1])
      assert_equal("WARN: [:foo, 1]\n", output_content)
    end

    it "styles the prefix in the simple format" do
      logger = styled_ui.create_logger(nil)
      logger.error("foobar")
      expected_prefix = styled_ui.terminal.apply_styles("ERROR:", :bright_red, :bold)
      assert_equal("#{expected_prefix} foobar\n", output_content)
    end

    it "styles the header in the detailed format" do
      logger = styled_ui.create_logger(nil)
      logger.verbosity = 1
      logger.error("foobar")
      assert_match(/\A\e\[91;1m\[[^\]]+ERROR\]\e\[0m  foobar\n\z/, output_content)
    end

    it "does not style the debug prefix in the simple format" do
      logger = styled_ui.create_logger(nil)
      logger.level = ::Logger::DEBUG
      logger.debug("foobar")
      assert_equal("DEBUG: foobar\n", output_content)
    end

    it "does not style the debug header in the detailed format" do
      logger = styled_ui.create_logger(nil)
      logger.level = ::Logger::DEBUG
      logger.verbosity = 1
      logger.debug("foobar")
      assert_match(/\A\[[^\]]+DEBUG\]  foobar\n\z/, output_content)
    end

    it "uses the verbose log format only at positive verbosity" do
      refute(unstyled_ui.verbose_log_format?(-1))
      refute(unstyled_ui.verbose_log_format?(0))
      assert(unstyled_ui.verbose_log_format?(1))
    end

    it "formats a simple log entry" do
      entry = unstyled_ui.format_simple_log_entry("WARN", ::Time.now, nil, "foobar")
      assert_equal("WARN: foobar\n", entry)
    end

    it "formats a verbose log entry" do
      entry = unstyled_ui.format_verbose_log_entry("WARN", ::Time.new(2026, 1, 2, 3, 4, 5), nil, "foobar")
      assert_equal("[2026-01-02 03:04:05  WARN]  foobar\n", entry)
    end

    describe "in a subclass" do
      let(:subclass_ui) {
        klass = ::Class.new(Toys::Utils::StandardUI) do
          def verbose_log_format?(verbosity)
            verbosity > 1
          end

          def format_simple_log_entry(severity, _time, _progname, msg)
            "simple #{severity} #{msg}\n"
          end

          def format_verbose_log_entry(severity, _time, _progname, msg)
            "verbose #{severity} #{msg}\n"
          end
        end
        klass.new(output: Toys::Utils::Terminal.new(output: output_buffer, styled: false))
      }

      it "dispatches through the overridable methods" do
        logger = subclass_ui.create_logger(nil)
        logger.verbosity = 1
        logger.warn("one")
        logger.verbosity = 2
        logger.warn("two")
        assert_equal("simple WARN one\nverbose WARN two\n", output_content)
      end
    end

    it "formats a verbose log entry from format_log_entry" do
      entry = unstyled_ui.format_log_entry("WARN", ::Time.new(2026, 1, 2, 3, 4, 5), nil, "foobar")
      assert_equal("[2026-01-02 03:04:05  WARN]  foobar\n", entry)
    end

    describe "in a subclass that defines format_log_entry" do
      def make_ui(&block)
        klass = ::Class.new(Toys::Utils::StandardUI) do
          def verbose_log_format?(_verbosity)
            raise "should not be called"
          end

          def format_simple_log_entry(_severity, _time, _progname, _msg)
            raise "should not be called"
          end

          def format_verbose_log_entry(_severity, _time, _progname, _msg)
            raise "should not be called"
          end

          class_eval(&block)
        end
        klass.new(output: Toys::Utils::Terminal.new(output: output_buffer, styled: false))
      end

      it "uses a public format_log_entry at every verbosity" do
        ui = make_ui do
          def format_log_entry(severity, _time, _progname, msg)
            "custom #{severity} #{msg}\n"
          end
        end
        logger = ui.create_logger(nil)
        logger.warn("one")
        logger.verbosity = 1
        logger.warn("two")
        assert_equal("custom WARN one\ncustom WARN two\n", output_content)
      end

      it "supports calling super from format_log_entry at every verbosity" do
        ui = make_ui do
          def format_verbose_log_entry(severity, _time, _progname, msg)
            "verbose #{severity} #{msg}\n"
          end

          def format_log_entry(severity, time, progname, msg)
            "custom #{super}"
          end
        end
        logger = ui.create_logger(nil)
        logger.warn("one")
        logger.verbosity = 1
        logger.warn("two")
        assert_equal("custom verbose WARN one\ncustom verbose WARN two\n", output_content)
      end

      it "uses a format_log_entry defined on a single instance" do
        ui = make_ui { nil }
        ui.define_singleton_method(:format_log_entry) do |severity, _time, _progname, msg|
          "custom #{severity} #{msg}\n"
        end
        logger = ui.create_logger(nil)
        logger.warn("one")
        assert_equal("custom WARN one\n", output_content)
      end

      it "uses a private format_log_entry" do
        ui = make_ui do
          private

          def format_log_entry(severity, _time, _progname, msg)
            "custom #{severity} #{msg}\n"
          end
        end
        logger = ui.create_logger(nil)
        logger.warn("one")
        assert_equal("custom WARN one\n", output_content)
      end
    end

    it "switches format with verbosity flags when used by a CLI" do
      cli = Toys::CLI.new(executable_name: "toys", **unstyled_ui.cli_args)
      cli.add_source do
        tool "foo" do
          to_run { logger.warn("foobar") }
        end
      end
      assert_equal(0, cli.run("foo"))
      assert_equal(0, cli.run("foo", "-v"))
      lines = output_content.lines
      assert_equal("WARN: foobar\n", lines[0])
      assert_match(/\A#{detailed_header}  foobar\n\z/, lines[1])
    end
  end
end
