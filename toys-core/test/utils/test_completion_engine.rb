# frozen_string_literal: true

require "helper"
require "toys/utils/completion_engine"

describe Toys::Utils::CompletionEngine do
  let(:logger) {
    Logger.new(StringIO.new).tap do |lgr|
      lgr.level = Logger::WARN
    end
  }
  let(:executable_name) { "toys" }
  let(:context_capture) {
    proc { |context|
      @context = context
      []
    }
  }
  let(:partials_fixture) {
    proc { [Toys::Completion::Candidate.new("partial-hello", partial: true)] }
  }
  let(:cli) {
    tester = self
    cli = Toys::CLI.new(executable_name: executable_name, logger: logger, middleware_stack: [],
                        extra_delimiters: ".:")
    cli.add_config_block do
      tool "one" do
        flag :hello
        flag :world, "--world VALUE", "-wVALUE", complete_values: ["building", "news"]
        flag :ruby, "--ruby [VALUE]", complete_values: ["gems", "tuesday"]
        required_arg :foo, complete: ["lish", "sball"]
        optional_arg :bar do
          complete ["n", "k"], prefix_constraint: /\A([a-z]+=)?\z/
        end
        remaining_args :baz, complete: ["aar", "ooka"]
        def run; end
      end
      tool "two" do
        optional_arg :path, complete: tester.partials_fixture
        def run; end
      end
      tool "three" do
        tool "four" do
          flag :hello
          flag :world, "--world VALUE", "-wVALUE", complete_values: tester.context_capture
          required_arg :foo, complete: tester.context_capture
          optional_arg :bar, complete: tester.context_capture
          remaining_args :baz, complete: tester.context_capture
          def run; end
        end
      end
      tool "five", delegate_to: ["one"] do
        tool "six" do
          def run; end
        end
      end
    end
    cli
  }

  describe "for bash" do
    let(:completion) {
      @context = nil
      Toys::Utils::CompletionEngine::Bash.new(cli)
    }

    it "detects failure to find executable name" do
      result = completion.run_internal("toys")
      assert_nil(result)
    end

    it "completes empty input" do
      _qt, candidates = completion.run_internal("toys ")
      assert_equal(["five", "one", "three", "two"], candidates.map(&:string))
    end

    it "completes t" do
      _qt, candidates = completion.run_internal("toys t")
      assert_equal(["three", "two"], candidates.map(&:string))
    end

    it "completes tw" do
      _qt, candidates = completion.run_internal("toys tw")
      assert_equal(["two"], candidates.map(&:string))
    end

    it "completes key=t" do
      _qt, candidates = completion.run_internal("toys key=t")
      assert_equal([], candidates)
    end

    it "completes subtool" do
      _qt, candidates = completion.run_internal("toys three ")
      assert_equal(["four"], candidates.map(&:string))
    end

    it "completes subtool with colon" do
      _qt, candidates = completion.run_internal("toys three:")
      assert_equal(["four"], candidates.map(&:string))
    end

    it "completes subtool with period" do
      _qt, candidates = completion.run_internal("toys three.")
      assert_equal(["three.four"], candidates.map(&:string))
    end

    it "does not complete subtool with slash" do
      _qt, candidates = completion.run_internal("toys three/")
      assert_equal([], candidates)
    end

    it "completes flag names and first arg" do
      _qt, candidates = completion.run_internal("toys one ")
      assert_equal(["--hello", "--ruby", "--world", "-w", "lish", "sball"], candidates.map(&:string))
    end

    it "completes first arg with prefix" do
      _qt, candidates = completion.run_internal("toys one key=")
      assert_equal([], candidates)
    end

    it "completes flag names only" do
      _qt, candidates = completion.run_internal("toys one --")
      assert_equal(["--hello", "--ruby", "--world"], candidates.map(&:string))
    end

    it "completes flag names and second arg" do
      _qt, candidates = completion.run_internal("toys one x ")
      assert_equal(["--hello", "--ruby", "--world", "-w", "k", "n"], candidates.map(&:string))
    end

    it "completes flag names and second arg with a valid prefix" do
      _qt, candidates = completion.run_internal("toys one x pre=")
      assert_equal(["k", "n"], candidates.map(&:string))
    end

    it "completes flag names and second arg with an invalid prefix" do
      _qt, candidates = completion.run_internal("toys one x PRE=")
      assert_equal([], candidates)
    end

    it "completes flag names and remaining arg" do
      _qt, candidates = completion.run_internal("toys one x y z ")
      assert_equal(["--hello", "--ruby", "--world", "-w", "aar", "ooka"], candidates.map(&:string))
    end

    it "completes after flag with no argument" do
      _qt, candidates = completion.run_internal("toys one --hello ")
      assert_equal(["--hello", "--ruby", "--world", "-w", "lish", "sball"], candidates.map(&:string))
    end

    it "completes empty string after flag with required argument" do
      _qt, candidates = completion.run_internal("toys one --world ")
      assert_equal(["building", "news"], candidates.map(&:string))
    end

    it "completes empty string after flag with required argument and =" do
      _qt, candidates = completion.run_internal("toys one --world=")
      assert_equal(["building", "news"], candidates.map(&:string))
    end

    it "completes empty string after flag with required argument and = with prefixed value" do
      _qt, candidates = completion.run_internal("toys one --world=key=b")
      assert_equal([], candidates)
    end

    it "completes empty string after flag with optional argument" do
      _qt, candidates = completion.run_internal("toys one --ruby ")
      assert_equal(["--hello", "--ruby", "--world", "-w", "gems", "tuesday"], candidates.map(&:string))
    end

    it "completes empty string after flag with optional argument and =" do
      _qt, candidates = completion.run_internal("toys one --ruby=")
      assert_equal(["gems", "tuesday"], candidates.map(&:string))
    end

    it "completes apparent flag after flag with optional argument" do
      _qt, candidates = completion.run_internal("toys one --ruby -")
      assert_equal(["--hello", "--ruby", "--world", "-w"], candidates.map(&:string))
    end

    it "completes after flag with its argument" do
      _qt, candidates = completion.run_internal("toys one --ruby together ")
      assert_equal(["--hello", "--ruby", "--world", "-w", "lish", "sball"], candidates.map(&:string))
    end

    it "completes after flag ender" do
      _qt, candidates = completion.run_internal("toys one -- ")
      assert_equal(["lish", "sball"], candidates.map(&:string))
    end

    it "completes for delegating tools" do
      _qt, candidates = completion.run_internal("toys five ")
      assert_equal(["--hello", "--ruby", "--world", "-w", "lish", "sball", "six"], candidates.map(&:string))
    end

    it "recognizes closed single quotes" do
      quote_type, candidates = completion.run_internal("toys 't'")
      assert_equal(:single, quote_type)
      assert_equal(["three", "two"], candidates.map(&:string))
    end

    it "recognizes open single quotes" do
      quote_type, candidates = completion.run_internal("toys 't")
      assert_equal(:single, quote_type)
      assert_equal(["three", "two"], candidates.map(&:string))
    end

    it "recognizes closed double quotes" do
      quote_type, candidates = completion.run_internal('toys "t"')
      assert_equal(:double, quote_type)
      assert_equal(["three", "two"], candidates.map(&:string))
    end

    it "recognizes open double quotes" do
      quote_type, candidates = completion.run_internal('toys "t')
      assert_equal(:double, quote_type)
      assert_equal(["three", "two"], candidates.map(&:string))
    end

    it "constructs context for no active flag" do
      completion.run_internal("toys three four --hello 123")
      assert_equal("123", @context.fragment)
      assert_nil(@context.arg_parser.active_flag_def)
    end

    it "constructs context for long flag with value" do
      completion.run_internal("toys three four --world 123")
      assert_equal("123", @context.fragment)
      assert_equal(:world, @context.arg_parser.active_flag_def.key)
    end

    it "constructs context for single character flag with value" do
      completion.run_internal("toys three four -w 123")
      assert_equal("123", @context.fragment)
      assert_equal(:world, @context.arg_parser.active_flag_def.key)
    end

    it "does not complete single character flag with attached value" do
      completion.run_internal("toys three four -w123")
      assert_nil(@context)
    end

    it "constructs context for empty remaining args" do
      completion.run_internal("toys three four foo bar ")
      assert_equal("", @context.fragment)
      assert_equal([], @context.arg_parser.data[:baz])
    end

    it "constructs context for several remaining args" do
      completion.run_internal("toys three four foo bar baz1 baz2 ")
      assert_equal("", @context.fragment)
      assert_equal(["baz1", "baz2"], @context.arg_parser.data[:baz])
    end

    describe "format_candidate" do
      it "formats a bare final candidate" do
        candidate = Toys::Completion::Candidate.new("hello")
        assert_equal("hello ", completion.format_candidate(candidate, :bare))
      end

      it "formats a bare partial candidate without trailing space" do
        candidate = Toys::Completion::Candidate.new("foo/", partial: true)
        assert_equal("foo/", completion.format_candidate(candidate, :bare))
      end

      it "formats a single-quoted final candidate" do
        candidate = Toys::Completion::Candidate.new("hello")
        assert_equal("'hello' ", completion.format_candidate(candidate, :single))
      end

      it "formats a single-quoted partial candidate" do
        candidate = Toys::Completion::Candidate.new("foo/", partial: true)
        assert_equal("'foo/", completion.format_candidate(candidate, :single))
      end

      it "formats a double-quoted final candidate" do
        candidate = Toys::Completion::Candidate.new("hello")
        assert_equal('"hello" ', completion.format_candidate(candidate, :double))
      end

      it "formats a double-quoted partial candidate" do
        candidate = Toys::Completion::Candidate.new("foo/", partial: true)
        assert_equal("\"foo/", completion.format_candidate(candidate, :double))
      end

      it "falls back to bare if candidate contains a single quote in single-quoted context" do
        candidate = Toys::Completion::Candidate.new("it's")
        assert_equal("it\\'s ", completion.format_candidate(candidate, :single))
      end
    end
  end

  describe "for zsh" do
    let(:completion) {
      @context = nil
      Toys::Utils::CompletionEngine::Zsh.new(cli)
    }

    it "detects failure to find executable name" do
      result = completion.run_internal("toys")
      assert_nil(result)
    end

    it "completes empty input" do
      _qt, candidates = completion.run_internal("toys ")
      assert_equal(["five", "one", "three", "two"], candidates.map(&:string))
      assert(candidates.none?(&:partial?))
    end

    it "completes t" do
      _qt, candidates = completion.run_internal("toys t")
      assert_equal(["three", "two"], candidates.map(&:string))
    end

    it "completes tw" do
      _qt, candidates = completion.run_internal("toys tw")
      assert_equal(["two"], candidates.map(&:string))
    end

    it "completes key=t" do
      _qt, candidates = completion.run_internal("toys key=t")
      assert_equal([], candidates)
    end

    it "completes subtool" do
      _qt, candidates = completion.run_internal("toys three ")
      assert_equal(["four"], candidates.map(&:string))
    end

    it "completes subtool with colon" do
      _qt, candidates = completion.run_internal("toys three:")
      assert_equal(["four"], candidates.map(&:string))
    end

    it "completes subtool with period" do
      _qt, candidates = completion.run_internal("toys three.")
      assert_equal(["three.four"], candidates.map(&:string))
    end

    it "does not complete subtool with slash" do
      _qt, candidates = completion.run_internal("toys three/")
      assert_equal([], candidates)
    end

    it "completes flag names and first arg" do
      _qt, candidates = completion.run_internal("toys one ")
      assert_equal(["--hello", "--ruby", "--world", "-w", "lish", "sball"], candidates.map(&:string))
    end

    it "completes first arg with prefix" do
      _qt, candidates = completion.run_internal("toys one key=")
      assert_equal([], candidates)
    end

    it "completes flag names only" do
      _qt, candidates = completion.run_internal("toys one --")
      assert_equal(["--hello", "--ruby", "--world"], candidates.map(&:string))
    end

    it "completes flag names and second arg" do
      _qt, candidates = completion.run_internal("toys one x ")
      assert_equal(["--hello", "--ruby", "--world", "-w", "k", "n"], candidates.map(&:string))
    end

    it "completes flag names and second arg with a valid prefix" do
      _qt, candidates = completion.run_internal("toys one x pre=")
      assert_equal(["k", "n"], candidates.map(&:string))
    end

    it "completes flag names and second arg with an invalid prefix" do
      _qt, candidates = completion.run_internal("toys one x PRE=")
      assert_equal([], candidates)
    end

    it "completes flag names and remaining arg" do
      _qt, candidates = completion.run_internal("toys one x y z ")
      assert_equal(["--hello", "--ruby", "--world", "-w", "aar", "ooka"], candidates.map(&:string))
    end

    it "completes after flag with no argument" do
      _qt, candidates = completion.run_internal("toys one --hello ")
      assert_equal(["--hello", "--ruby", "--world", "-w", "lish", "sball"], candidates.map(&:string))
    end

    it "completes empty string after flag with required argument" do
      _qt, candidates = completion.run_internal("toys one --world ")
      assert_equal(["building", "news"], candidates.map(&:string))
    end

    it "completes empty string after flag with required argument and =" do
      _qt, candidates = completion.run_internal("toys one --world=")
      assert_equal(["building", "news"], candidates.map(&:string))
    end

    it "completes empty string after flag with required argument and = with prefixed value" do
      _qt, candidates = completion.run_internal("toys one --world=key=b")
      assert_equal([], candidates)
    end

    it "completes empty string after flag with optional argument" do
      _qt, candidates = completion.run_internal("toys one --ruby ")
      assert_equal(["--hello", "--ruby", "--world", "-w", "gems", "tuesday"], candidates.map(&:string))
    end

    it "completes empty string after flag with optional argument and =" do
      _qt, candidates = completion.run_internal("toys one --ruby=")
      assert_equal(["gems", "tuesday"], candidates.map(&:string))
    end

    it "completes apparent flag after flag with optional argument" do
      _qt, candidates = completion.run_internal("toys one --ruby -")
      assert_equal(["--hello", "--ruby", "--world", "-w"], candidates.map(&:string))
    end

    it "completes after flag with its argument" do
      _qt, candidates = completion.run_internal("toys one --ruby together ")
      assert_equal(["--hello", "--ruby", "--world", "-w", "lish", "sball"], candidates.map(&:string))
    end

    it "completes after flag ender" do
      _qt, candidates = completion.run_internal("toys one -- ")
      assert_equal(["lish", "sball"], candidates.map(&:string))
    end

    it "completes for delegating tools" do
      _qt, candidates = completion.run_internal("toys five ")
      assert_equal(["--hello", "--ruby", "--world", "-w", "lish", "sball", "six"], candidates.map(&:string))
    end

    it "returns raw unquoted strings for single-quoted input" do
      _qt, candidates = completion.run_internal("toys 't")
      assert_equal(["three", "two"], candidates.map(&:string))
    end

    it "returns raw unquoted strings for double-quoted input" do
      _qt, candidates = completion.run_internal('toys "t')
      assert_equal(["three", "two"], candidates.map(&:string))
    end

    it "sets shell param to :zsh" do
      completion.run_internal("toys three four --hello 123")
      assert_equal(:zsh, @context[:params][:shell])
    end

    it "constructs context for no active flag" do
      completion.run_internal("toys three four --hello 123")
      assert_equal("123", @context.fragment)
      assert_nil(@context.arg_parser.active_flag_def)
    end

    it "constructs context for long flag with value" do
      completion.run_internal("toys three four --world 123")
      assert_equal("123", @context.fragment)
      assert_equal(:world, @context.arg_parser.active_flag_def.key)
    end

    it "constructs context for several remaining args" do
      completion.run_internal("toys three four foo bar baz1 baz2 ")
      assert_equal("", @context.fragment)
      assert_equal(["baz1", "baz2"], @context.arg_parser.data[:baz])
    end

    describe "#run" do
      def capture_run(line)
        old_stdout = $stdout
        $stdout = StringIO.new
        ::ENV["COMP_LINE"] = line
        ::ENV["COMP_POINT"] = "-1"
        status = completion.run
        output = $stdout.string.chomp
        [status, output.split("\n", -1)]
      ensure
        $stdout = old_stdout
        ::ENV.delete("COMP_LINE")
        ::ENV.delete("COMP_POINT")
      end

      it "returns 2 if COMP_LINE is not set" do
        ::ENV.delete("COMP_LINE")
        ::ENV.delete("COMP_POINT")
        assert_equal(2, completion.run)
      end

      it "returns 2 if COMP_POINT is not set" do
        ::ENV["COMP_LINE"] = "toys "
        ::ENV.delete("COMP_POINT")
        assert_equal(2, completion.run)
      ensure
        ::ENV.delete("COMP_LINE")
      end

      it "returns 1 for an unparseable line" do
        status, _lines = capture_run("toys")
        assert_equal(1, status)
      end

      it "returns 0 for a valid completion" do
        status, _lines = capture_run("toys ")
        assert_equal(0, status)
      end

      it "emits final candidates before the separator" do
        _status, lines = capture_run("toys t")
        sep = lines.index("")
        refute_nil(sep)
        assert_equal(["three", "two"], lines[0, sep])
      end

      it "emits an empty partials section for all-final candidates" do
        _status, lines = capture_run("toys t")
        sep = lines.index("")
        assert_equal([], lines[(sep + 1)..])
      end

      it "emits partials" do
        _status, lines = capture_run("toys two par")
        sep = lines.index("")
        refute_nil(sep)
        part = lines.index("partial-hello")
        refute_nil(part)
        assert(part > sep)
      end
    end
  end
end
