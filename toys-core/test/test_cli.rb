# frozen_string_literal: true

require "helper"

require "fileutils"
require "tmpdir"
require "toys/utils/exec"
require "toys/utils/standard_ui"

describe Toys::CLI do
  let(:logger_io) { ::StringIO.new }
  let(:logger) {
    Logger.new(logger_io).tap do |lgr|
      lgr.level = Logger::WARN
    end
  }
  let(:executable_name) { "toys" }
  let(:cli) {
    Toys::CLI.new(
      executable_name: executable_name,
      logger: logger,
      middleware_stack: [],
      extra_delimiters: ":"
    )
  }
  let(:lookup_cases_dir) { File.join(File.dirname(__dir__), "test-data", "lookup-cases") }

  describe "tool name splitter" do
    it "reflects the extra delimiters" do
      assert_equal(":", cli.tool_name_splitter.extra_delimiters)
      assert_equal(["foo", "bar"], cli.tool_name_splitter.split("foo:bar"))
    end

    it "is shared with the loader" do
      assert_same(cli.tool_name_splitter, cli.loader.tool_name_splitter)
    end

    it "defaults to recognizing only whitespace" do
      cli = Toys::CLI.new(logger: logger, middleware_stack: [])
      assert_equal(Toys::ToolNameSplitter::DEFAULT.extra_delimiters,
                   cli.tool_name_splitter.extra_delimiters)
      assert_equal(["foo:bar"], cli.tool_name_splitter.split("foo:bar"))
    end

    it "raises if the extra delimiters are illegal" do
      error = assert_raises(::ArgumentError) do
        Toys::CLI.new(logger: logger, middleware_stack: [], extra_delimiters: ",")
      end
      assert_includes(error.message, "Illegal delimiters")
    end

    it "is passed on to a child CLI" do
      child = cli.child
      assert_equal(":", child.tool_name_splitter.extra_delimiters)
    end
  end

  describe "execution" do
    it "returns the exit value" do
      cli.add_source do
        tool "foo" do
          def run
            exit(3)
          end
        end
      end
      assert_equal(3, cli.run("foo"))
    end

    it "handles no script defined" do
      cli.add_source do
        tool "foo" do
          # Empty tool
        end
      end
      error = assert_raises(Toys::ContextualError) do
        cli.run("foo")
      end
      assert_kind_of(Toys::NotRunnableError, error.cause)
    end

    it "can disable argument parsing" do
      test = self
      cli.add_source do
        tool "foo" do
          disable_argument_parsing
          to_run do
            test.assert_equal(["baz", "--bar"], args)
            test.assert(usage_errors.empty?)
          end
        end
      end
      cli.run("foo", "baz", "--bar")
    end

    it "runs initializer at the beginning" do
      test = self
      cli.add_source do
        tool "foo" do
          t = Toys::DSL::Internal.current_tool(self, true)
          t.add_initializer(proc { |a| set(:a, a) }, 123)
          to_run do
            test.assert_equal(123, get(:a))
          end
        end
      end
      cli.run("foo")
    end

    it "passes the verbosity setting through the default middleware stack" do
      test = self
      verbose_cli = Toys::CLI.new(executable_name: executable_name, logger: logger)
      verbose_cli.add_source do
        tool "foo" do
          to_run do
            test.assert_equal(2, verbosity)
            test.assert_equal(Logger::WARN - 2, logger.level)
          end
        end
      end
      assert_equal(0, verbose_cli.run("foo", verbosity: 2))
    end

    it "combines the verbosity setting with verbosity flags" do
      test = self
      verbose_cli = Toys::CLI.new(executable_name: executable_name, logger: logger)
      verbose_cli.add_source do
        tool "foo" do
          to_run do
            test.assert_equal(1, verbosity)
          end
        end
      end
      assert_equal(0, verbose_cli.run("foo", "-v", "-q", "-v", verbosity: 0))
    end

    it "makes context fields available via convenience methods" do
      test = self
      cli.add_source do
        tool "foo" do
          optional_arg(:arg1)
          optional_arg(:arg2)
          flag(:sw1, "-a")
          to_run do
            test.assert_equal(0, verbosity)
            test.assert_equal(["foo"], tool_name)
            test.assert_instance_of(Logger, logger)
            test.assert_equal("toys", cli.executable_name)
            test.assert_equal(["hello", "-a"], args)
            test.assert_equal({arg1: "hello", arg2: nil, sw1: true}, options)
          end
        end
      end
      cli.run(["foo", "hello", "-a"])
    end

    it "makes context fields available via get" do
      test = self
      cli.add_source do
        tool "foo" do
          optional_arg(:arg1)
          optional_arg(:arg2)
          flag(:sw1, "-a")
          to_run do
            test.assert_equal(0, get(Toys::Context::Key::VERBOSITY))
            test.assert_equal(["foo"], get(Toys::Context::Key::TOOL).full_name)
            test.assert_equal(["foo"], get(Toys::Context::Key::TOOL_NAME))
            test.assert_instance_of(Logger, get(Toys::Context::Key::LOGGER))
            test.assert_equal("toys", get(Toys::Context::Key::CLI).executable_name)
            test.assert_equal(["hello", "-a"], get(Toys::Context::Key::ARGS))
          end
        end
      end
      cli.run(["foo", "hello", "-a"])
    end

    it "makes options available via get" do
      test = self
      cli.add_source do
        tool "foo" do
          optional_arg(:arg1)
          optional_arg(:arg2)
          flag(:sw1, "-a")
          to_run do
            test.assert_equal(true, get(:sw1))
            test.assert_equal("hello", get(:arg1))
            test.assert_nil(get(:arg2))
          end
        end
      end
      cli.run(["foo", "hello", "-a"])
    end

    it "supports sub-runs" do
      test = self
      cli.add_source do
        tool "foo" do
          optional_arg :arg1
          to_run do
            test.assert_equal("hi", self[:arg1])
            exit(cli.run("bar", "ho"))
          end
        end
        tool "bar" do
          optional_arg :arg2
          to_run do
            test.assert_equal("ho", self[:arg2])
            exit(3)
          end
        end
      end
      assert_equal(3, cli.run(["foo", "hi"]))
    end

    it "accesses data from run" do
      cli.add_source(File.join(lookup_cases_dir, "data-finder"))
      assert_equal(0, cli.run("ns-1", "ns-1a", "foo"))
    end

    it "accesses lib directory" do
      skip "Skipped test because fork is not available" unless Toys::Compat.allow_fork?
      cli.add_source(File.join(lookup_cases_dir, "lib-dirs"))
      func = proc do
        puts cli.run("foo")
      end
      result = Toys::Utils::Exec.new.capture_proc(func)
      assert_equal("7\n", result)
    end

    it "accesses lib directory with overrides" do
      skip "Skipped test because fork is not available" unless Toys::Compat.allow_fork?
      cli.add_source(File.join(lookup_cases_dir, "lib-dirs"))
      func = proc do
        puts cli.run("ns", "bar")
      end
      result = Toys::Utils::Exec.new.capture_proc(func)
      assert_equal("9\n", result)
    end

    it "does not add a lib directory that is already on the load path" do
      cli.add_source(File.join(lookup_cases_dir, "lib-dirs"))
      lib_path = File.join(lookup_cases_dir, "lib-dirs", ".lib")
      orig_load_path = $LOAD_PATH.dup
      begin
        cli.load_tool("foo") { :ok }
        cli.load_tool("foo") { :ok }
        assert_equal(1, $LOAD_PATH.count(lib_path))
      ensure
        $LOAD_PATH.replace(orig_load_path)
      end
    end

    it "recognizes delimiters" do
      cli.add_source do
        tool "foo" do
          tool "bar" do
            def run
              exit(3)
            end
          end
        end
      end
      assert_equal(3, cli.run("foo:bar"))
    end
  end

  describe "delegation" do
    it "executes the delegate" do
      cli.add_source do
        tool "foo" do
          tool "bar" do
            def run
              exit(4)
            end
          end
          delegate_to ["foo", "bar"]
        end
      end
      assert_equal(4, cli.run("foo"))
    end

    it "passes arguments to the delegate" do
      test = self
      cli.add_source do
        tool "foo" do
          tool "bar" do
            flag :foo, "--foo=VAL"
            to_run do
              test.assert_equal("hello", get(:foo))
              exit(4)
            end
          end
          delegate_to ["foo", "bar"]
        end
      end
      assert_equal(4, cli.run("foo", "--foo", "hello"))
    end

    it "executes the delegate when the tool has a private exit method" do
      exit_mixin = ::Module.new do
        private

        def exit(code = 0)
          Toys::Context.exit(code)
        end
      end
      cli.add_source do
        tool "foo" do
          tool "bar" do
            def run
              exit(4)
            end
          end
          delegate_to ["foo", "bar"]
          include exit_mixin
        end
      end
      assert_equal(4, cli.run("foo"))
    end

    it "delegates to a namespace" do
      cli.add_source do
        tool "foo" do
          tool "bar" do
            def run
              exit(4)
            end
          end
        end
        tool "boo" do
          delegate_to ["foo"]
        end
      end
      assert_equal(4, cli.run("boo", "bar"))
    end

    it "detects dangling references" do
      cli.add_source do
        tool "foo" do
          delegate_to ["boo"]
        end
      end
      error = assert_raises(Toys::ContextualError) do
        cli.run("foo")
      end
      assert_equal("Delegate target not found: \"boo\"", error.cause.message)
    end

    it "detects circular references" do
      cli.add_source do
        tool "foo" do
          delegate_to ["boo"]
        end
        tool "boo" do
          delegate_to ["foo"]
        end
      end
      error = assert_raises(Toys::ContextualError) do
        cli.run("foo")
      end
      assert_kind_of(Toys::ToolDefinitionError, error.root_cause)
      assert_equal("Delegation loop: \"foo\" <- \"boo\" <- \"foo\"", error.root_cause.message)
    end

    it "attributes a delegate error to both the delegate and the delegating tool" do
      cli.add_source do
        tool "target" do
          to_run do
            raise "kaboom"
          end
        end
        tool "front" do
          delegate_to ["target"]
        end
      end
      error = assert_raises(Toys::ContextualError) do
        cli.run("front")
      end
      assert_equal(["front"], error.tool_name)
      assert_equal(["target"], error.cause.tool_name)
      assert_equal("kaboom", error.root_cause.message)
    end

    it "reraises a signal raised by a delegate" do
      cli.add_source do
        tool "target" do
          def run
            raise SignalException, 4
          end
        end
        tool "front" do
          delegate_to ["target"]
        end
      end
      error = assert_raises(SignalException) do
        cli.run("front")
      end
      assert_equal(4, error.signo)
    end

    it "lets the delegating tool handle an interrupt raised by the delegate" do
      cli.add_source do
        tool "target" do
          def run
            raise ::Interrupt
          end
        end
        tool "front" do
          on_interrupt do
            exit(7)
          end
          delegate_to ["target"]
        end
      end
      assert_equal(7, cli.run("front"))
    end

    it "lets the delegating tool handle a signal raised by the delegate" do
      test = self
      cli.add_source do
        tool "target" do
          def run
            raise SignalException, 15
          end
        end
        tool "front" do
          on_signal(15) do |ex|
            test.assert_equal(15, ex.signo)
            exit(8)
          end
          delegate_to ["target"]
        end
      end
      assert_equal(8, cli.run("front"))
    end

    it "offers the signal to each tool outward when the delegate reraises" do
      order = []
      cli.add_source do
        tool "target" do
          on_interrupt do |ex|
            order << :target
            raise ex
          end

          def run
            raise ::Interrupt
          end
        end
        tool "front" do
          on_interrupt do
            order << :front
            exit(11)
          end
          delegate_to ["target"]
        end
      end
      assert_equal(11, cli.run("front"))
      assert_equal([:target, :front], order)
    end

    it "gives the delegate the first chance to handle a signal" do
      order = []
      cli.add_source do
        tool "target" do
          on_interrupt do
            order << :target
            exit(9)
          end

          def run
            raise ::Interrupt
          end
        end
        tool "front" do
          on_interrupt do
            order << :front
            exit(10)
          end
          delegate_to ["target"]
        end
      end
      assert_equal(9, cli.run("front"))
      assert_equal([:target], order)
    end

    it "passes a delegate error to a custom error handler" do
      my_handler = proc do |error|
        assert_equal(["front"], error.tool_name)
        assert_equal(["target"], error.cause.tool_name)
        assert_kind_of(::RuntimeError, error.root_cause)
        11
      end
      my_cli = cli.child(error_handler: my_handler)
      my_cli.add_source do
        tool "target" do
          to_run do
            raise "kaboom"
          end
        end
        tool "front" do
          delegate_to ["target"]
        end
      end
      assert_equal(11, my_cli.run("front"))
    end
  end

  describe "error handling" do
    it "raises the error by default" do
      cli.add_source do
        tool "foo" do
          def run
            raise "whoops"
          end
        end
      end
      error = assert_raises(Toys::ContextualError) do
        cli.run("foo")
      end
      assert_equal("whoops", error.cause.message)
    end

    it "preserves the full cause chain when reraising a non-signal error" do
      cli.add_source do
        tool "foo" do
          def run
            raise ::ArgumentError, "root"
          rescue ::ArgumentError
            raise "whoops"
          end
        end
      end
      error = assert_raises(Toys::ContextualError) do
        cli.run("foo")
      end
      cause = error.cause
      assert_equal("whoops", cause.message)
      assert_kind_of(::ArgumentError, cause.cause)
      assert_equal("root", cause.cause.message)
    end

    it "supports a custom handler that receives definition errors" do
      my_handler = proc do |error|
        assert_nil(error.tool_name)
        assert_includes(error.tool_file_path, "/errors/definition.rb")
        assert_kind_of(NameError, error.cause)
        9
      end
      my_cli = cli.child(error_handler: my_handler)
      my_cli.add_source(File.join(lookup_cases_dir, "errors"))
      assert_equal(9, my_cli.run("definition"))
    end

    it "supports a custom handler that receives runtime errors" do
      my_handler = proc do |error|
        assert_equal(["runtime", "hello"], error.tool_name)
        assert_includes(error.tool_file_path, "/errors/runtime.rb")
        assert_kind_of(NameError, error.cause)
        10
      end
      my_cli = cli.child(error_handler: my_handler)
      my_cli.add_source(File.join(lookup_cases_dir, "errors"))
      assert_equal(10, my_cli.run("runtime", "hello"))
    end

    it "passes an error raised during argument parsing to the error handler" do
      my_handler = proc do |error|
        assert_equal(["foo"], error.tool_name)
        assert_equal("handler kaboom", error.root_cause.message)
        13
      end
      my_cli = cli.child(error_handler: my_handler)
      my_cli.add_source do
        tool "foo" do
          flag :bar, "--bar=VAL", handler: proc { |_val, _prev| raise "handler kaboom" }
          def run
            # Never reached
          end
        end
      end
      assert_equal(13, my_cli.run("foo", "--bar=x"))
    end

    it "supports a custom handler that receives signals" do
      # A signal is never wrapped in a ContextualError, so the handler receives
      # the SignalException itself rather than a wrapper.
      my_handler = proc do |error|
        assert_kind_of(SignalException, error)
        assert_equal(4, error.signo)
        12
      end
      my_cli = cli.child(error_handler: my_handler)
      my_cli.add_source do
        tool "foo" do
          def run
            raise SignalException, 4
          end
        end
      end
      assert_equal(12, my_cli.run("foo"))
    end

    it "passes an unwrapped signal raised by a delegate to a custom handler" do
      my_handler = proc do |error|
        assert_kind_of(::Interrupt, error)
        14
      end
      my_cli = cli.child(error_handler: my_handler)
      my_cli.add_source do
        tool "target" do
          def run
            raise ::Interrupt
          end
        end
        tool "front" do
          delegate_to ["target"]
        end
      end
      assert_equal(14, my_cli.run("front"))
    end
  end

  describe "signal_handling" do
    it "raises the signal by default" do
      cli.add_source do
        tool "foo" do
          def run
            raise SignalException, 4
          end
        end
      end
      error = assert_raises(SignalException) do
        cli.run("foo")
      end
      assert_equal(4, error.signo)
    end

    it "executes a signal handler block that matches the signal" do
      cli.add_source do
        tool "foo" do
          def run
            raise SignalException, 15
          end

          on_signal(15) do
            exit(16)
          end
        end
      end
      assert_equal(16, cli.run("foo"))
    end

    it "bypasses a signal handler block that doesn't match the signal" do
      cli.add_source do
        tool "foo" do
          def run
            raise SignalException, 15
          end

          on_signal(4) do
            exit(2)
          end
        end
      end
      error = assert_raises(SignalException) do
        cli.run("foo")
      end
      assert_equal(15, error.signo)
    end

    it "supports an interrupt block with no argument" do
      cli.add_source do
        tool "foo" do
          def run
            raise ::Interrupt
          end

          on_interrupt do
            exit(2)
          end
        end
      end
      assert_equal(2, cli.run("foo"))
    end

    it "supports propagating an interrupt" do
      cli.add_source do
        tool "foo" do
          def run
            raise ::Interrupt
          end

          on_interrupt do |ex|
            raise ex
          end
        end
      end
      assert_raises(Interrupt) do
        cli.run("foo")
      end
    end

    it "supports an interrupt block with an argument" do
      test = self
      cli.add_source do
        tool "foo" do
          def run
            raise ::Interrupt
          end

          on_interrupt do |ex|
            test.assert_instance_of(::Interrupt, ex)
            exit(2)
          end
        end
      end
      assert_equal(2, cli.run("foo"))
    end

    it "supports nested interrupts" do
      counter = 0
      cli.add_source do
        tool "foo" do
          def run
            raise ::Interrupt
          end

          on_interrupt do |ex|
            counter += 1
            raise ::Interrupt if ex.cause.nil?
            exit(counter)
          end
        end
      end
      assert_equal(2, cli.run("foo"))
    end

    it "supports an interrupt method with no argument" do
      cli.add_source do
        tool "foo" do
          def run
            raise ::Interrupt
          end

          on_interrupt :int_handler

          def int_handler
            exit(2)
          end
        end
      end
      assert_equal(2, cli.run("foo"))
    end

    it "supports an interrupt method with an argument" do
      cli.add_source do
        tool "foo" do
          def run
            raise ::Interrupt
          end

          def int_handler(exception)
            exit(exception.is_a?(::Interrupt) ? 2 : 3)
          end

          on_interrupt :int_handler
        end
      end
      assert_equal(2, cli.run("foo"))
    end
  end

  describe "usage error handling" do
    it "passes the exception out by default" do
      cli.add_source do
        tool "foo" do
          def run; end
        end
      end
      error = assert_raises(Toys::ContextualError) do
        cli.run("foo", "--bar")
      end
      usage_errors = error.cause.usage_errors
      assert(usage_errors.any? { |ue| ue.message == "Flag \"--bar\" is not recognized." })
    end

    it "supports setting the handler back to the default" do
      cli.add_source do
        tool "foo" do
          on_usage_error :run
          on_usage_error nil

          def run; end
        end
      end
      error = assert_raises(Toys::ContextualError) do
        cli.run("foo", "--bar")
      end
      usage_errors = error.cause.usage_errors
      assert(usage_errors.any? { |ue| ue.message == "Flag \"--bar\" is not recognized." })
    end

    it "supports redirecting back to run" do
      cli.add_source do
        tool "foo" do
          on_usage_error :run

          def run
            exit usage_errors.size
          end
        end
      end
      assert_equal(3, cli.run("foo", "--bar", "--baz", "--qux"))
    end

    it "supports invoking a method with no argument" do
      cli.add_source do
        tool "foo" do
          on_usage_error :usage_handler

          def run
            exit(-1)
          end

          def usage_handler
            exit usage_errors.size
          end
        end
      end
      assert_equal(3, cli.run("foo", "--bar", "--baz", "--qux"))
    end

    it "supports invoking a method with an argument" do
      cli.add_source do
        tool "foo" do
          on_usage_error :usage_handler

          def run
            exit(-1)
          end

          def usage_handler(errs)
            exit errs.size
          end
        end
      end
      assert_equal(3, cli.run("foo", "--bar", "--baz", "--qux"))
    end

    it "supports invoking a block with no argument" do
      cli.add_source do
        tool "foo" do
          on_usage_error do
            exit usage_errors.size
          end

          def run
            exit(-1)
          end
        end
      end
      assert_equal(3, cli.run("foo", "--bar", "--baz", "--qux"))
    end

    it "supports invoking a block with no argument" do
      cli.add_source do
        tool "foo" do
          on_usage_error do |errs|
            exit errs.size
          end

          def run
            exit(-1)
          end
        end
      end
      assert_equal(3, cli.run("foo", "--bar", "--baz", "--qux"))
    end
  end

  describe "directive alterations" do
    it "allows partial flag match" do
      cli.add_source do
        tool "foo" do
          flag :abcde
          def run
            exit(0)
          end
        end
      end
      assert_equal(0, cli.run("foo", "--abc"))
    end

    it "requires exact flag match" do
      cli.add_source do
        tool "foo" do
          flag :abcde
          require_exact_flag_match
          def run
            exit(0)
          end
        end
      end
      error = assert_raises(Toys::ContextualError) do
        cli.run("foo", "--abc")
      end
      assert_equal('Flag "--abc" is not recognized.', error.cause.usage_errors.first.message)
    end
  end

  describe "load_tool" do
    it "runs a block" do
      cli.add_source do
        tool "foo" do
          def run
            puts(message)
          end

          def message
            "hello"
          end
        end
      end
      result = cli.load_tool("foo") do |tool|
        "#{tool.message}#{tool.message}"
      end
      assert_equal("hellohello", result)
    end

    it "handles usage errors" do
      cli.add_source do
        tool "foo" do
          def run
            puts(message)
          end

          def message
            "hello 1"
          end
        end
      end
      assert_raises(Toys::ArgParsingError) do
        cli.load_tool("bar") do
          flunk("Did not expect the block to run")
        end
      end
    end

    it "does not wrap an error raised by the block" do
      cli.add_source do
        tool "foo" do
          def run
            # Never reached
          end
        end
      end
      error = assert_raises(::RuntimeError) do
        cli.load_tool("foo") do
          raise "from the block"
        end
      end
      assert_equal("from the block", error.message)
    end

    it "does not wrap an error raised during argument parsing" do
      cli.add_source do
        tool "foo" do
          flag :bar, "--bar=VAL", handler: proc { |_val, _prev| raise "handler kaboom" }
          def run
            # Never reached
          end
        end
      end
      error = assert_raises(::RuntimeError) do
        cli.load_tool("foo", "--bar=x") do
          flunk("Did not expect the block to run")
        end
      end
      assert_equal("handler kaboom", error.message)
    end

    it "honors the verbosity setting" do
      test = self
      cli.add_source do
        tool "foo" do
          def run
            # Never reached
          end
        end
      end
      cli.load_tool("foo", verbosity: 2) do |tool|
        test.assert_equal(2, tool[Toys::Context::Key::VERBOSITY])
      end
    end
  end

  describe "add_source argument checking" do
    it "rejects a call with neither a spec nor a block" do
      error = assert_raises(ArgumentError) { cli.add_source }
      assert_equal("No source spec, path, or block given", error.message)
    end

    it "rejects both a spec and a block" do
      spec = Toys::SourceSpec.block { nil }
      error = assert_raises(ArgumentError) { cli.add_source(spec) { nil } }
      assert_equal("Ambiguous source: both spec and block passed", error.message)
    end

    it "rejects an argument that is neither a spec nor a legal path" do
      error = assert_raises(ArgumentError) { cli.add_source(12_345) }
      assert_equal("Illegal path value: 12345", error.message)
    end

    it "leaves the source list untouched when an argument is rejected" do
      assert_raises(ArgumentError) { cli.add_source(12_345) }
      refute_tool_defined(cli, "foo")
    end

    it "accepts a path-convertible object as a path" do
      require "pathname"
      cli.add_source(Pathname.new(File.join(lookup_cases_dir, "config-items", ".toys.rb")))
      tool, _remaining = cli.loader.lookup(["tool-1"])
      assert_equal("file tool-1 short description", tool.desc.to_s)
    end

    # Returns true if the CLI has no tool by the given name. A lookup miss
    # falls back to the nearest namespace, which here is always the root.
    def refute_tool_defined(a_cli, name)
      tool, _remaining = a_cli.loader.lookup([name])
      assert_empty(tool.full_name, "expected no tool named #{name.inspect}")
    end
  end

  describe "add_source with a gem spec" do
    let(:gem_toys_dir) { "test-data/lookup-cases/config-items" }

    it "adds tools from a gem" do
      cli.add_source(Toys::SourceSpec.gem("toys-core", path: ".toys.rb", toys_dir: gem_toys_dir))
      tool, remaining = cli.loader.lookup(["tool-1"])
      assert_equal("file tool-1 short description", tool.desc.to_s)
      assert_equal([], remaining)
      assert_match(%r{^gem\(name=toys-core version=\S+ path=#{gem_toys_dir}/\.toys\.rb\)},
                   tool.source_info.source_name)
    end

    it "defaults to the entire toys directory" do
      cli.add_source(Toys::SourceSpec.gem("toys-core", toys_dir: "#{gem_toys_dir}/.toys"))
      tool, _remaining = cli.loader.lookup(["tool-2"])
      assert_equal("directory tool-2 short description", tool.desc.to_s)
    end

    it "honors high_priority" do
      cli.add_source(File.join(lookup_cases_dir, "normal-file-hierarchy"))
      cli.add_source(Toys::SourceSpec.gem("toys-core", path: ".toys.rb", toys_dir: gem_toys_dir),
                     high_priority: true)
      tool, _remaining = cli.loader.lookup(["tool-1"])
      assert_equal("file tool-1 short description", tool.desc.to_s)
    end

    it "returns self" do
      result = cli.add_source(Toys::SourceSpec.gem("toys-core", path: ".toys.rb",
                                                   toys_dir: gem_toys_dir))
      assert_same(cli, result)
    end
  end

  describe "add_source with a git spec" do
    let(:git_remote) { "https://github.com/dazuma/toys.git" }
    let(:git_path) { "toys-core/test-data/lookup-cases/config-items/.toys.rb" }

    before do
      skip "Skipped integration test" unless ENV["TOYS_TEST_INTEGRATION"]
    end

    it "adds tools from a git source" do
      cli.add_source(Toys::SourceSpec.git(git_remote, path: git_path, commit: "main"))
      tool, remaining = cli.loader.lookup(["tool-1"])
      assert_equal("file tool-1 short description", tool.desc.to_s)
      assert_equal([], remaining)
    end

    it "returns self" do
      result = cli.add_source(Toys::SourceSpec.git(git_remote, path: git_path, commit: "main"))
      assert_same(cli, result)
    end
  end

  describe "convenience source-adding methods" do
    # A CLI that recognizes toplevel tool files and directories, as the
    # standard Toys CLI does. The search path methods find nothing without
    # them.
    let(:search_cli) {
      Toys::CLI.new(
        executable_name: executable_name,
        logger: logger,
        middleware_stack: [],
        toplevel_tool_file_name: ".toys.rb",
        toplevel_tool_dir_name: ".toys"
      )
    }
    let(:config_items_dir) { File.join(lookup_cases_dir, "config-items") }
    # Realpath, so that paths built from it match the paths that a directory
    # walk starting inside it produces.
    let(:tmp_dir) { File.realpath(Dir.mktmpdir("toys_cli_search_path_test")) }

    after do
      FileUtils.rm_rf(tmp_dir)
    end

    # Creates a directory, named by path elements relative to the temp
    # directory, containing a toplevel tool file that defines a tool with the
    # given name and description. Returns the directory path.
    def make_search_dir(*path_elems, tool_name:, desc:)
      dir = File.join(tmp_dir, *path_elems)
      FileUtils.mkdir_p(dir)
      contents = "tool(#{tool_name.inspect}) { desc(#{desc.inspect}) }\n"
      File.write(File.join(dir, ".toys.rb"), contents)
      dir
    end

    # Asserts that the given CLI has no tool by the given name. A lookup miss
    # falls back to the nearest namespace, which here is always the root.
    def refute_tool_defined(a_cli, name)
      tool, _remaining = a_cli.loader.lookup([name])
      assert_empty(tool.full_name, "expected no tool named #{name.inspect}")
    end

    # The add_config_* methods are deprecated in favor of add_source, so they
    # get only enough coverage to show that they still reach the source list.

    it "adds a source through add_config_block" do
      cli.add_config_block do
        tool "foo" do
          def run
            exit(3)
          end
        end
      end
      assert_equal(3, cli.run("foo"))
    end

    it "adds a source through add_config_path" do
      cli.add_config_path(File.join(config_items_dir, ".toys.rb"))
      tool, remaining = cli.loader.lookup(["tool-1"])
      assert_equal("file tool-1 short description", tool.desc.to_s)
      assert_equal([], remaining)
      # add_config_path, unlike add_search_path, defaults the context
      # directory to the parent of the given path.
      assert_equal(config_items_dir, tool.context_directory)
    end

    describe "add_search_path" do
      it "loads tools from the toplevel tool file" do
        search_cli.add_search_path(config_items_dir)
        tool, remaining = search_cli.loader.lookup(["tool-1"])
        assert_equal("file tool-1 short description", tool.desc.to_s)
        assert_equal([], remaining)
      end

      it "loads tools from the toplevel tool directory" do
        search_cli.add_search_path(config_items_dir)
        tool, _remaining = search_cli.loader.lookup(["tool-2"])
        assert_equal("directory tool-2 short description", tool.desc.to_s)
      end

      it "loads nothing from a directory with no toplevel tool file or directory" do
        search_cli.add_search_path(File.join(lookup_cases_dir, "normal-file-hierarchy"))
        refute_tool_defined(search_cli, "tool-1")
      end

      it "ignores a toplevel tool file that is a directory" do
        FileUtils.mkdir_p(File.join(tmp_dir, ".toys.rb"))
        File.write(File.join(tmp_dir, ".toys.rb", "tool-1.rb"), "desc 'from a bogus tool file'\n")
        search_cli.add_search_path(tmp_dir)
        refute_tool_defined(search_cli, "tool-1")
      end

      it "ignores a toplevel tool directory that is a file" do
        File.write(File.join(tmp_dir, ".toys"), "tool('tool-1') { desc 'from a bogus tool dir' }\n")
        search_cli.add_search_path(tmp_dir)
        refute_tool_defined(search_cli, "tool-1")
      end

      it "ignores the toplevel tool file if the CLI does not define one" do
        dir_only_cli = Toys::CLI.new(logger: logger, middleware_stack: [],
                                     toplevel_tool_dir_name: ".toys")
        dir_only_cli.add_search_path(config_items_dir)
        tool, _remaining = dir_only_cli.loader.lookup(["tool-2"])
        assert_equal("directory tool-2 short description", tool.desc.to_s)
        refute_tool_defined(dir_only_cli, "tool-1")
      end

      it "ignores the toplevel tool directory if the CLI does not define one" do
        file_only_cli = Toys::CLI.new(logger: logger, middleware_stack: [],
                                      toplevel_tool_file_name: ".toys.rb")
        file_only_cli.add_search_path(config_items_dir)
        tool, _remaining = file_only_cli.loader.lookup(["tool-1"])
        assert_equal("file tool-1 short description", tool.desc.to_s)
        refute_tool_defined(file_only_cli, "tool-2")
      end

      it "defaults the context directory to the search path itself" do
        search_cli.add_search_path(config_items_dir)
        tool, _remaining = search_cli.loader.lookup(["tool-1"])
        assert_equal(config_items_dir, tool.context_directory)
      end

      it "honors a context directory of :parent" do
        search_cli.add_search_path(config_items_dir, context_directory: :parent)
        tool, _remaining = search_cli.loader.lookup(["tool-1"])
        assert_equal(lookup_cases_dir, tool.context_directory)
      end

      it "honors an explicit context directory" do
        search_cli.add_search_path(config_items_dir, context_directory: tmp_dir)
        tool, _remaining = search_cli.loader.lookup(["tool-1"])
        assert_equal(tmp_dir, tool.context_directory)
      end

      it "honors a nil context directory" do
        search_cli.add_search_path(config_items_dir, context_directory: nil)
        tool, _remaining = search_cli.loader.lookup(["tool-1"])
        assert_nil(tool.context_directory)
      end

      it "adds at the tail of the priority list by default" do
        search_cli.add_search_path(config_items_dir)
        search_cli.add_search_path(make_search_dir(tool_name: "tool-1", desc: "temp tool-1"))
        tool, _remaining = search_cli.loader.lookup(["tool-1"])
        assert_equal("file tool-1 short description", tool.desc.to_s)
      end

      it "honors high_priority" do
        search_cli.add_search_path(config_items_dir)
        search_cli.add_search_path(make_search_dir(tool_name: "tool-1", desc: "temp tool-1"),
                                   high_priority: true)
        tool, _remaining = search_cli.loader.lookup(["tool-1"])
        assert_equal("temp tool-1", tool.desc.to_s)
      end

      it "returns self" do
        assert_same(search_cli, search_cli.add_search_path(config_items_dir))
      end

      # The return value is used for chaining, e.g. by the "system tools" builtin,
      # so it must be the CLI even on the paths that add no source.
      it "returns self for a search path that does not exist" do
        assert_same(search_cli, search_cli.add_search_path(File.join(tmp_dir, "nonexistent")))
      end

      it "returns self for a search path that holds no toplevel tool file or directory" do
        empty_dir = File.join(tmp_dir, "empty")
        FileUtils.mkdir_p(empty_dir)
        assert_same(search_cli, search_cli.add_search_path(empty_dir))
      end

      it "skips a search path that does not exist" do
        search_cli.add_search_path(File.join(tmp_dir, "nonexistent"))
        search_cli.add_search_path(config_items_dir)
        refute_tool_defined(search_cli, "nonexistent")
        tool, _remaining = search_cli.loader.lookup(["tool-1"])
        assert_equal("file tool-1 short description", tool.desc.to_s)
      end

      it "skips a search path that is a file rather than a directory" do
        file_path = File.join(tmp_dir, "not-a-directory")
        File.write(file_path, "tool('tool-1') { desc 'from a file search path' }\n")
        search_cli.add_search_path(file_path)
        refute_tool_defined(search_cli, "tool-1")
      end

      it "skips a search path that is not readable" do
        unreadable_dir = make_search_dir("unreadable", tool_name: "tool-1", desc: "unreadable tool")
        File.chmod(0o000, unreadable_dir)
        begin
          skip "Skipped because this process can read a mode 000 directory" if File.readable?(unreadable_dir)
          search_cli.add_search_path(unreadable_dir)
          refute_tool_defined(search_cli, "tool-1")
        ensure
          File.chmod(0o755, unreadable_dir)
        end
      end

      it "accepts a path-convertible object as a search path" do
        require "pathname"
        search_cli.add_search_path(Pathname.new(config_items_dir))
        tool, _remaining = search_cli.loader.lookup(["tool-1"])
        assert_equal("file tool-1 short description", tool.desc.to_s)
      end

      it "raises if the source list is finalized, even for a path it would skip" do
        search_cli.loader
        assert_raises(Toys::SourceListFinalizedError) do
          search_cli.add_search_path(File.join(tmp_dir, "nonexistent"))
        end
      end

      it "rejects an argument that is not a legal path" do
        error = assert_raises(ArgumentError) { search_cli.add_search_path(12_345) }
        assert_equal("Illegal search_path value: 12345", error.message)
      end

      # Whether an argument is well formed must not depend on what happens to be
      # on disk, so the check happens before the search path is examined.
      it "rejects an illegal context directory, even for a path it would skip" do
        error = assert_raises(ArgumentError) do
          search_cli.add_search_path(File.join(tmp_dir, "nonexistent"), context_directory: 12_345)
        end
        assert_equal("Illegal context_directory value: 12345", error.message)
      end

      it "expands a relative search path, and the context directory derived from it" do
        expected = nil
        Dir.chdir(lookup_cases_dir) do
          expected = File.expand_path("config-items")
          search_cli.add_search_path("config-items")
        end
        tool, _remaining = search_cli.loader.lookup(["tool-1"])
        assert_equal("file tool-1 short description", tool.desc.to_s)
        assert_equal(expected, tool.context_directory)
      end

      it "collapses dot segments in the search path before deriving the context directory" do
        search_cli.add_search_path(File.join(config_items_dir, ".toys", ".."))
        tool, _remaining = search_cli.loader.lookup(["tool-1"])
        assert_equal(config_items_dir, tool.context_directory)
      end

      it "expands a relative context directory" do
        search_cli.add_search_path(config_items_dir, context_directory: "relative/context")
        tool, _remaining = search_cli.loader.lookup(["tool-1"])
        assert_equal(File.expand_path("relative/context"), tool.context_directory)
      end

      it "accepts a path-convertible object as a context directory" do
        require "pathname"
        search_cli.add_search_path(config_items_dir, context_directory: Pathname.new(tmp_dir))
        tool, _remaining = search_cli.loader.lookup(["tool-1"])
        assert_equal(tmp_dir, tool.context_directory)
      end
    end

    describe "add_search_path_hierarchy" do
      # Terminating at the temp directory's parent keeps the walk from
      # reaching real directories above it.
      let(:terminate_dirs) { [File.dirname(tmp_dir)] }

      it "adds the start directory and its ancestors" do
        make_search_dir(tool_name: "tool-top", desc: "top tool")
        start_dir = make_search_dir("ns-1", "ns-2", tool_name: "tool-start", desc: "start tool")
        # ns-1, in the middle of the hierarchy, has no tool file at all.
        search_cli.add_search_path_hierarchy(start: start_dir, terminate: terminate_dirs)
        tool, _remaining = search_cli.loader.lookup(["tool-start"])
        assert_equal("start tool", tool.desc.to_s)
        tool, _remaining = search_cli.loader.lookup(["tool-top"])
        assert_equal("top tool", tool.desc.to_s)
      end

      it "gives the start directory a higher priority than its ancestors" do
        make_search_dir(tool_name: "tool-1", desc: "top tool")
        make_search_dir("ns-1", tool_name: "tool-1", desc: "middle tool")
        start_dir = make_search_dir("ns-1", "ns-2", tool_name: "tool-1", desc: "start tool")
        search_cli.add_search_path_hierarchy(start: start_dir, terminate: terminate_dirs)
        tool, _remaining = search_cli.loader.lookup(["tool-1"])
        assert_equal("start tool", tool.desc.to_s)
      end

      it "halts the walk without checking a terminating directory" do
        make_search_dir(tool_name: "tool-top", desc: "top tool")
        middle_dir = make_search_dir("ns-1", tool_name: "tool-middle", desc: "middle tool")
        start_dir = make_search_dir("ns-1", "ns-2", tool_name: "tool-start", desc: "start tool")
        search_cli.add_search_path_hierarchy(start: start_dir, terminate: [middle_dir])
        tool, _remaining = search_cli.loader.lookup(["tool-start"])
        assert_equal("start tool", tool.desc.to_s)
        refute_tool_defined(search_cli, "tool-middle")
        refute_tool_defined(search_cli, "tool-top")
      end

      it "defaults the start directory to the current directory" do
        start_dir = make_search_dir("ns-1", "ns-2", tool_name: "tool-1", desc: "start tool")
        Dir.chdir(start_dir) do
          search_cli.add_search_path_hierarchy(terminate: terminate_dirs)
        end
        tool, _remaining = search_cli.loader.lookup(["tool-1"])
        assert_equal("start tool", tool.desc.to_s)
      end

      it "adds the hierarchy at the tail of the priority list by default" do
        search_cli.add_source do
          tool "tool-1" do
            desc "block tool"
          end
        end
        start_dir = make_search_dir("ns-1", tool_name: "tool-1", desc: "start tool")
        search_cli.add_search_path_hierarchy(start: start_dir, terminate: terminate_dirs)
        tool, _remaining = search_cli.loader.lookup(["tool-1"])
        assert_equal("block tool", tool.desc.to_s)
      end

      it "honors high_priority, preserving the order within the hierarchy" do
        search_cli.add_source do
          tool "tool-1" do
            desc "block tool"
          end
        end
        make_search_dir(tool_name: "tool-1", desc: "top tool")
        start_dir = make_search_dir("ns-1", tool_name: "tool-1", desc: "start tool")
        search_cli.add_search_path_hierarchy(start: start_dir, terminate: terminate_dirs,
                                             high_priority: true)
        tool, _remaining = search_cli.loader.lookup(["tool-1"])
        assert_equal("start tool", tool.desc.to_s)
      end

      it "skips directories in the hierarchy that do not exist" do
        make_search_dir(tool_name: "tool-top", desc: "top tool")
        start_dir = File.join(tmp_dir, "nonexistent", "also-nonexistent")
        search_cli.add_search_path_hierarchy(start: start_dir, terminate: terminate_dirs)
        tool, _remaining = search_cli.loader.lookup(["tool-top"])
        assert_equal("top tool", tool.desc.to_s)
      end

      it "stops the walk at the file system root" do
        # Nothing is loaded here; the assertion is that the walk returns at
        # all, rather than looping on a root whose parent is itself.
        assert_same(search_cli, search_cli.add_search_path_hierarchy(start: "/"))
      end

      it "returns self" do
        result = search_cli.add_search_path_hierarchy(start: tmp_dir, terminate: terminate_dirs)
        assert_same(search_cli, result)
      end

      it "defaults each directory's context directory to that directory" do
        make_search_dir(tool_name: "tool-top", desc: "top tool")
        start_dir = make_search_dir("ns-1", tool_name: "tool-start", desc: "start tool")
        search_cli.add_search_path_hierarchy(start: start_dir, terminate: terminate_dirs)
        tool, _remaining = search_cli.loader.lookup(["tool-start"])
        assert_equal(start_dir, tool.context_directory)
        tool, _remaining = search_cli.loader.lookup(["tool-top"])
        assert_equal(tmp_dir, tool.context_directory)
      end

      it "honors an explicit context directory for every directory in the hierarchy" do
        make_search_dir(tool_name: "tool-top", desc: "top tool")
        start_dir = make_search_dir("ns-1", tool_name: "tool-start", desc: "start tool")
        context_dir = File.join(tmp_dir, "context")
        search_cli.add_search_path_hierarchy(start: start_dir, terminate: terminate_dirs,
                                             context_directory: context_dir)
        tool, _remaining = search_cli.loader.lookup(["tool-start"])
        assert_equal(context_dir, tool.context_directory)
        tool, _remaining = search_cli.loader.lookup(["tool-top"])
        assert_equal(context_dir, tool.context_directory)
      end

      it "honors a nil context directory for every directory in the hierarchy" do
        make_search_dir(tool_name: "tool-top", desc: "top tool")
        start_dir = make_search_dir("ns-1", tool_name: "tool-start", desc: "start tool")
        search_cli.add_search_path_hierarchy(start: start_dir, terminate: terminate_dirs,
                                             context_directory: nil)
        tool, _remaining = search_cli.loader.lookup(["tool-start"])
        assert_nil(tool.context_directory)
        tool, _remaining = search_cli.loader.lookup(["tool-top"])
        assert_nil(tool.context_directory)
      end

      # An uncollapsed start path would name a directory that the walk then
      # reaches again by its plain name, adding it twice at two priorities.
      it "collapses dot segments in the start directory" do
        start_dir = make_search_dir("ns-1", tool_name: "tool-1", desc: "start tool")
        FileUtils.mkdir_p(File.join(start_dir, "ns-2"))
        search_cli.add_search_path_hierarchy(start: File.join(start_dir, "ns-2", ".."),
                                             terminate: terminate_dirs)
        tool, _remaining = search_cli.loader.lookup(["tool-1"])
        assert_equal("start tool", tool.desc.to_s)
        assert_equal(start_dir, tool.context_directory)
      end

      it "collapses dot segments in a terminating directory" do
        make_search_dir(tool_name: "tool-top", desc: "top tool")
        middle_dir = make_search_dir("ns-1", tool_name: "tool-middle", desc: "middle tool")
        start_dir = make_search_dir("ns-1", "ns-2", tool_name: "tool-start", desc: "start tool")
        search_cli.add_search_path_hierarchy(start: start_dir,
                                             terminate: [File.join(middle_dir, "ns-2", "..")])
        tool, _remaining = search_cli.loader.lookup(["tool-start"])
        assert_equal("start tool", tool.desc.to_s)
        refute_tool_defined(search_cli, "tool-middle")
        refute_tool_defined(search_cli, "tool-top")
      end
    end
  end

  # A context directory has two forms. The one a source or a tool definition
  # sets may be unset; the effective one seen by a running tool falls back to
  # the working directory and is never nil.
  describe "runtime context directory" do
    it "falls back to the working directory when nothing sets one" do
      captured = nil
      cli.add_source do
        tool "foo" do
          to_run { captured = context_directory }
        end
      end
      tool, _remaining = cli.loader.lookup(["foo"])
      assert_nil(tool.context_directory)
      cli.run("foo")
      assert_equal(Dir.getwd, captured)
    end

    it "uses the working directory in effect when the tool runs" do
      captured = nil
      cli.add_source do
        tool "foo" do
          to_run { captured = context_directory }
        end
      end
      other_dir = File.realpath(Dir.mktmpdir("toys_cli_context_dir_test"))
      begin
        Dir.chdir(other_dir) { cli.run("foo") }
        assert_equal(other_dir, captured)
      ensure
        FileUtils.rm_rf(other_dir)
      end
    end

    it "prefers the source context directory over the working directory" do
      captured = nil
      cli.add_source(Toys::SourceSpec.block(context_directory: "/source/dir") do
        tool "foo" do
          to_run { captured = context_directory }
        end
      end)
      cli.run("foo")
      assert_equal("/source/dir", captured)
    end

    it "prefers a context directory set by the tool definition" do
      captured = nil
      cli.add_source(Toys::SourceSpec.block(context_directory: "/source/dir") do
        tool "foo" do
          set_context_directory "/custom/dir"
          to_run { captured = context_directory }
        end
      end)
      cli.run("foo")
      assert_equal("/custom/dir", captured)
    end
  end

  describe "source list finalization" do
    it "raises when adding a source after the loader is built" do
      cli.loader
      assert_raises(Toys::SourceListFinalizedError) do
        cli.add_source { tool("foo") { def run; end } }
      end
    end

    it "raises when adding a source after the runner is built" do
      cli.runner
      assert_raises(Toys::SourceListFinalizedError) do
        cli.add_source(File.join(lookup_cases_dir, "config-items", ".toys.rb"))
      end
    end

    it "raises when adding a source after a tool has been run" do
      cli.add_source do
        tool "foo" do
          def run; end
        end
      end
      assert_equal(0, cli.run("foo"))
      assert_raises(Toys::SourceListFinalizedError) do
        cli.add_search_path(lookup_cases_dir)
      end
    end

    it "raises from every source-adding method" do
      cli.loader
      [
        -> { cli.add_config_path(lookup_cases_dir) },
        -> { cli.add_config_block { nil } },
        -> { cli.add_source(lookup_cases_dir) },
        -> { cli.add_source(Toys::SourceSpec.gem("toys-core")) },
        -> { cli.add_source(Toys::SourceSpec.git("https://example.com/repo.git")) },
        -> { cli.add_search_path(lookup_cases_dir) },
        -> { cli.add_search_path_hierarchy(start: lookup_cases_dir) },
      ].each do |adder|
        assert_raises(Toys::SourceListFinalizedError) { adder.call }
      end
    end

    # Returns true if the CLI has no tool by the given name. A lookup miss
    # falls back to the nearest namespace, which here is always the root.
    def refute_tool_defined(a_cli, name)
      tool, _remaining = a_cli.loader.lookup([name])
      assert_empty(tool.full_name, "expected no tool named #{name.inspect}")
    end

    it "copies a source list passed to the constructor" do
      source_list = Toys::SourceList.new
      spec = Toys::SourceSpec.block do
        tool "foo" do
          def run
            exit(3)
          end
        end
      end
      source_list.add(spec)
      list_cli = Toys::CLI.new(logger: logger, middleware_stack: [], source_list: source_list)

      # The caller keeps its own list, so later additions there must not reach
      # the CLI, which would otherwise route around the finalization guard.
      spec = Toys::SourceSpec.block do
        tool "bar" do
          def run
            exit(4)
          end
        end
      end
      source_list.add(spec)
      assert_equal(3, list_cli.run("foo"))
      refute_tool_defined(list_cli, "bar")
    end

    it "is not affected by a caller mutating its source list after finalization" do
      source_list = Toys::SourceList.new
      spec = Toys::SourceSpec.block do
        tool "foo" do
          def run
            exit(3)
          end
        end
      end
      source_list.add(spec)
      list_cli = Toys::CLI.new(logger: logger, middleware_stack: [], source_list: source_list)
      list_cli.finalize_sources!
      spec = Toys::SourceSpec.block do
        tool "bar" do
          def run
            exit(4)
          end
        end
      end
      source_list.add(spec)
      assert_equal(3, list_cli.run("foo"))
      refute_tool_defined(list_cli, "bar")
    end

    it "allows adding sources to a CLI that has a global logger" do
      logger_cli = Toys::CLI.new(logger: logger, middleware_stack: [])
      logger_cli.add_source do
        tool "foo" do
          def run
            exit(3)
          end
        end
      end
      assert_equal(3, logger_cli.run("foo"))
    end
  end

  describe "finalize_sources!" do
    it "returns self" do
      assert_same(cli, cli.finalize_sources!)
    end

    it "raises when adding a source afterward" do
      cli.finalize_sources!
      assert_raises(Toys::SourceListFinalizedError) do
        cli.add_source { tool("foo") { def run; end } }
      end
    end

    it "builds a working loader and runner" do
      cli.add_source do
        tool "foo" do
          def run
            exit(3)
          end
        end
      end
      cli.finalize_sources!
      tool, _remaining = cli.loader.lookup(["foo"])
      assert_equal(true, tool.definition_finished?)
      assert_equal(3, cli.run("foo"))
    end

    it "is idempotent, building the loader and runner only once" do
      cli.finalize_sources!
      loader = cli.loader
      runner = cli.runner
      cli.finalize_sources!
      assert_same(loader, cli.loader)
      assert_same(runner, cli.runner)
    end

    it "is a no-op if the source list is already finalized" do
      cli.loader
      cli.finalize_sources!
      assert_raises(Toys::SourceListFinalizedError) do
        cli.add_source { tool("foo") { def run; end } }
      end
    end
  end

  describe "runner" do
    it "is the runner that runs the CLI's tools" do
      test = self
      cli_runner = nil
      cli.add_source do
        tool "foo" do
          to_run do
            test.assert_same(cli_runner, self[Toys::Context::Key::RUNNER])
          end
        end
      end
      cli_runner = cli.runner
      assert_equal(0, cli.run("foo"))
    end

    it "returns the same runner on every call" do
      assert_same(cli.runner, cli.runner)
    end

    it "runs a tool with the CLI's configuration" do
      test = self
      cli.add_source do
        tool "foo" do
          to_run do
            test.assert_same(test.cli, self[Toys::Context::Key::CLI])
            test.assert_equal("toys", self[Toys::Context::Key::EXECUTABLE_NAME])
            exit(3)
          end
        end
      end
      assert_equal(3, cli.runner.run(["foo"]))
    end

    it "gives a child CLI its own runner" do
      refute_same(cli.runner, cli.child.runner)
    end
  end

  describe "child" do
    # Stand-ins, only ever compared by identity.
    let(:git_cache) { Object.new }
    let(:gems_util) { Object.new }
    let(:logger2) {
      Logger.new(logger_io).tap do |lgr|
        lgr.level = Logger::DEBUG
      end
    }

    it "resets tool blocks" do
      cli.add_source do
        tool "foo" do
          def run
            exit(3)
          end
        end
      end
      child = cli.child
      child.add_source do
        tool "foo" do
          def run
            exit(4)
          end
        end
      end
      assert_equal(4, child.run("foo"))
    end

    it "copies parameters" do
      assert_same(logger, cli.logger_factory.call)
      child = cli.child
      assert_same(logger, child.logger_factory.call)
    end

    it "recognizes every constructor keyword" do
      keywords = Toys::CLI.instance_method(:initialize).parameters
                          .filter_map { |type, name| name if [:key, :keyreq].include?(type) }
      assert_equal(keywords.sort, cli.send(:current_settings, true).keys.sort,
                   "Every CLI#initialize keyword must appear in CLI#current_settings," \
                   " otherwise CLI#child silently drops it")
    end

    # A SourceList has no value equality, so compare it by what a copy has to
    # preserve: the same specs, in the same order, with the same priorities.
    def equivalent_setting?(parent_value, child_value)
      return parent_value == child_value unless parent_value.is_a?(Toys::SourceList)
      child_value.is_a?(Toys::SourceList) &&
        parent_value.each_with_priority.to_a == child_value.each_with_priority.to_a
    end

    it "empties the source list unless sources are copied" do
      cli.add_source do
        tool "foo" do
          def run; end
        end
      end
      source_list = cli.send(:current_settings, false)[:source_list]
      assert_instance_of(Toys::SourceList, source_list)
      assert_empty(source_list)
    end

    # Resolution is per-Loader, and a child gets its own, so a copied source
    # spec is resolved again rather than carried over already resolved.
    it "re-resolves copied sources in the child's own loader" do
      activations = []
      util = Object.new
      util.define_singleton_method(:activate) { |name, *_versions| activations << name }
      gem_cli = Toys::CLI.new(logger: logger, middleware_stack: [], gems_util: util)
      gem_cli.add_source(Toys::SourceSpec.gem("toys-core", path: ".toys.rb",
                                              toys_dir: "test-data/lookup-cases/config-items"))
      gem_cli.loader.lookup(["tool-1"])
      assert_equal(["toys-core"], activations)

      gem_cli.child(copy_sources: true).loader.lookup(["tool-1"])
      assert_equal(["toys-core", "toys-core"], activations)
    end

    it "carries the resolvers into a child that copies no sources" do
      cli = Toys::CLI.new(logger: logger, middleware_stack: [],
                          git_cache: git_cache, gems_util: gems_util)
      settings = cli.child.send(:current_settings, true)
      assert_same(git_cache, settings[:git_cache])
      assert_same(gems_util, settings[:gems_util])
    end

    it "copies every setting so that it survives the copy" do
      cli.add_source do
        tool "foo" do
          def run; end
        end
      end
      parent_settings = cli.send(:current_settings, true)
      child_settings = cli.child(copy_sources: true).send(:current_settings, true)
      mismatched = parent_settings.keys.reject do |key|
        equivalent_setting?(parent_settings[key], child_settings[key])
      end
      assert_empty(mismatched,
                   "Settings that did not survive CLI#child, likely because" \
                   " CLI#current_settings reports a derived value rather than the one passed in")
    end

    it "overrides parameters" do
      assert_same(logger, cli.logger_factory.call)
      child = cli.child(logger: logger2)
      assert_same(logger2, child.logger_factory.call)
    end

    it "can drop the logger, falling back to the default factory" do
      assert_same(logger, cli.logger_factory.call)
      child = cli.child(logger: nil)
      assert_nil(child.logger)
      refute_same(logger, child.logger_factory.call)
      assert_instance_of(Logger, child.logger_factory.call)
    end

    it "does not copy loader sources by default" do
      cli.add_source do
        tool "foo" do
          def run
            exit(3)
          end
        end
      end
      child = cli.child
      tool, remaining = child.loader.lookup(["foo"])
      assert_empty(tool.full_name)
      assert_equal(["foo"], remaining)
    end

    it "copies loader sources when requested" do
      cli.add_source do
        tool "foo" do
          def run
            exit(3)
          end
        end
      end
      child = cli.child(copy_sources: true)
      assert_equal(3, child.run("foo"))
    end

    it "copies loader sources added from paths" do
      cli.add_source(File.join(lookup_cases_dir, "config-items", ".toys.rb"))
      child = cli.child(copy_sources: true)
      tool, _remaining = child.loader.lookup(["tool-1"])
      assert_equal("file tool-1 short description", tool.desc.to_s)
    end

    it "lets sources added in the child block take priority over copied sources" do
      cli.add_source do
        tool "foo" do
          def run
            exit(3)
          end
        end
      end
      child = cli.child(copy_sources: true) do |c|
        c.add_source(high_priority: true) do
          tool "foo" do
            def run
              exit(4)
            end
          end
        end
      end
      assert_equal(4, child.run("foo"))
    end

    it "does not affect the original cli when the child adds sources" do
      cli.add_source do
        tool "foo" do
          def run
            exit(3)
          end
        end
      end
      child = cli.child(copy_sources: true)
      child.add_source(high_priority: true) do
        tool "foo" do
          def run
            exit(4)
          end
        end
      end
      assert_equal(3, cli.run("foo"))
    end
  end
end
