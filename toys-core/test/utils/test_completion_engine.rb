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
      result = completion.run_internal("toys ")
      assert_equal(["five ", "one ", "three ", "two "], result)
    end

    it "completes t" do
      result = completion.run_internal("toys t")
      assert_equal(["three ", "two "], result)
    end

    it "completes tw" do
      result = completion.run_internal("toys tw")
      assert_equal(["two "], result)
    end

    it "completes key=t" do
      result = completion.run_internal("toys key=t")
      assert_equal([], result)
    end

    it "completes subtool" do
      result = completion.run_internal("toys three ")
      assert_equal(["four "], result)
    end

    it "completes subtool with colon" do
      result = completion.run_internal("toys three:")
      assert_equal(["four "], result)
    end

    it "completes subtool with period" do
      result = completion.run_internal("toys three.")
      assert_equal(["three.four "], result)
    end

    it "does not complete subtool with slash" do
      result = completion.run_internal("toys three/")
      assert_equal([], result)
    end

    it "completes flag names and first arg" do
      result = completion.run_internal("toys one ")
      assert_equal(["--hello ", "--ruby ", "--world ", "-w ", "lish ", "sball "], result)
    end

    it "completes first arg with prefix" do
      result = completion.run_internal("toys one key=")
      assert_equal([], result)
    end

    it "completes flag names only" do
      result = completion.run_internal("toys one --")
      assert_equal(["--hello ", "--ruby ", "--world "], result)
    end

    it "completes flag names and second arg" do
      result = completion.run_internal("toys one x ")
      assert_equal(["--hello ", "--ruby ", "--world ", "-w ", "k ", "n "], result)
    end

    it "completes flag names and second arg with a valid prefix" do
      result = completion.run_internal("toys one x pre=")
      assert_equal(["k ", "n "], result)
    end

    it "completes flag names and second arg with an invalid prefix" do
      result = completion.run_internal("toys one x PRE=")
      assert_equal([], result)
    end

    it "completes flag names and remaining arg" do
      result = completion.run_internal("toys one x y z ")
      assert_equal(["--hello ", "--ruby ", "--world ", "-w ", "aar ", "ooka "], result)
    end

    it "completes after flag with no argument" do
      result = completion.run_internal("toys one --hello ")
      assert_equal(["--hello ", "--ruby ", "--world ", "-w ", "lish ", "sball "], result)
    end

    it "completes empty string after flag with required argument" do
      result = completion.run_internal("toys one --world ")
      assert_equal(["building ", "news "], result)
    end

    it "completes empty string after flag with required argument and =" do
      result = completion.run_internal("toys one --world=")
      assert_equal(["building ", "news "], result)
    end

    it "completes empty string after flag with required argument and = with prefixed value" do
      result = completion.run_internal("toys one --world=key=b")
      assert_equal([], result)
    end

    it "completes empty string after flag with optional argument" do
      result = completion.run_internal("toys one --ruby ")
      assert_equal(["--hello ", "--ruby ", "--world ", "-w ", "gems ", "tuesday "], result)
    end

    it "completes empty string after flag with optional argument and =" do
      result = completion.run_internal("toys one --ruby=")
      assert_equal(["gems ", "tuesday "], result)
    end

    it "completes apparent flag after flag with optional argument" do
      result = completion.run_internal("toys one --ruby -")
      assert_equal(["--hello ", "--ruby ", "--world ", "-w "], result)
    end

    it "completes after flag with its argument" do
      result = completion.run_internal("toys one --ruby together ")
      assert_equal(["--hello ", "--ruby ", "--world ", "-w ", "lish ", "sball "], result)
    end

    it "completes after flag ender" do
      result = completion.run_internal("toys one -- ")
      assert_equal(["lish ", "sball "], result)
    end

    it "completes for delegating tools" do
      result = completion.run_internal("toys five ")
      assert_equal(["--hello ", "--ruby ", "--world ", "-w ", "lish ", "sball ", "six "], result)
    end

    it "recognizes closed single quotes" do
      result = completion.run_internal("toys 't'")
      assert_equal(["'three' ", "'two' "], result)
    end

    it "recognizes open single quotes" do
      result = completion.run_internal("toys 't")
      assert_equal(["'three' ", "'two' "], result)
    end

    it "recognizes closed double quotes" do
      result = completion.run_internal('toys "t"')
      assert_equal(['"three" ', '"two" '], result)
    end

    it "recognizes open double quotes" do
      result = completion.run_internal('toys "t')
      assert_equal(['"three" ', '"two" '], result)
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
  end
end
