# frozen_string_literal: true

require "helper"
require "toys/utils/terminal"

describe Toys::Utils::Terminal do
  let(:input) { ::StringIO.new }
  let(:output) { ::StringIO.new }
  let(:terminal) { Toys::Utils::Terminal.new(input: input, output: output, styled: true) }

  describe "remove_style_escapes" do
    it "removes clear code" do
      str = Toys::Utils::Terminal.remove_style_escapes(Toys::Utils::Terminal::CLEAR_CODE)
      assert_equal("", str)
    end

    it "removes multiple sequences" do
      str = "\e[12;34mhi\e[9m"
      str = Toys::Utils::Terminal.remove_style_escapes(str)
      assert_equal("hi", str)
    end
  end

  describe "style interpretation" do
    it "interprets symbolic colors" do
      str = terminal.apply_styles("hello", :yellow)
      assert_equal("\e[33mhello\e[0m", str)
    end

    it "interprets 8*3-bit rgb colors" do
      str = terminal.apply_styles("hello", "fe126a")
      assert_equal("\e[38;2;254;18;106mhello\e[0m", str)
    end

    it "interprets 4*3-bit rgb colors" do
      str = terminal.apply_styles("hello", "05f")
      assert_equal("\e[38;2;0;85;255mhello\e[0m", str)
    end

    it "supports empty style set" do
      str = terminal.apply_styles("hello")
      assert_equal("hello", str)
    end

    it "converts the input to string" do
      str = terminal.apply_styles(:hello, :yellow)
      assert_equal("\e[33mhello\e[0m", str)
    end
  end

  describe "styled output" do
    describe "write" do
      it "writes and clears styles" do
        terminal.write("hello", :bold)
        assert_equal("\e[1mhello\e[0m", output.string)
      end

      it "preserves existing styles" do
        terminal.write("hel\e[3mlo", :bold)
        assert_equal("\e[1mhel\e[3mlo\e[0m", output.string)
      end

      it "does not clear when no style is present" do
        terminal.write("hello")
        assert_equal("hello", output.string)
      end

      it "defines named styles" do
        terminal.define_style(:bold_red, :bold, :red)
        terminal.write("hello", :bold_red)
        assert_equal("\e[1;31mhello\e[0m", output.string)
      end

      it "converts the input to string" do
        terminal.write(:hello, :bold)
        assert_equal("\e[1mhello\e[0m", output.string)
      end
    end

    describe "puts" do
      it "adds a newline" do
        terminal.puts("hello", :bold)
        assert_equal("\e[1mhello\n\e[0m", output.string)
      end

      it "does not add an extra newline" do
        terminal.puts("hello\n", :bold)
        assert_equal("\e[1mhello\n\e[0m", output.string)
      end

      it "converts the input to string" do
        terminal.puts(:hello, :bold)
        assert_equal("\e[1mhello\n\e[0m", output.string)
      end
    end
  end

  describe "unstyled output" do
    let(:terminal) { Toys::Utils::Terminal.new(input: input, output: output, styled: false) }

    describe "write" do
      it "does not include styles" do
        terminal.write("hello", :bold)
        assert_equal("hello", output.string)
      end

      it "indeed removes existing styles" do
        terminal.write("\e[1mhello\e[0m")
        assert_equal("hello", output.string)
      end
    end

    describe "puts" do
      it "adds a newline" do
        terminal.puts("hello")
        assert_equal("hello\n", output.string)
      end

      it "does not add an extra newline" do
        terminal.puts("hello\n")
        assert_equal("hello\n", output.string)
      end
    end
  end

  describe "NO_COLOR integration" do
    let(:output_with_tty) do
      def output.tty?
        true
      end
      output
    end
    let(:terminal) { Toys::Utils::Terminal.new(input: input, output: output_with_tty) }

    before do
      @save_no_color = ::ENV["NO_COLOR"]
    end

    after do
      ::ENV["NO_COLOR"] = @save_no_color
    end

    it "uses tty when NO_COLOR is not set" do
      assert(terminal.styled)
    end

    it "disables styling when NO_COLOR is set" do
      ::ENV["NO_COLOR"] = "true"
      refute(terminal.styled)
    end
  end

  describe "ask" do
    it "Displays a prompt and gets a result" do
      input = StringIO.new "hello\n"
      terminal = Toys::Utils::Terminal.new(input: input, output: output)
      assert_equal("hello", terminal.ask("What? "))
      assert_equal("What? ", output.string)
    end

    it "Displays a prompt with default and gets a default result" do
      input = StringIO.new "\n"
      terminal = Toys::Utils::Terminal.new(input: input, output: output)
      assert_equal("hi", terminal.ask("What?  ", default: "hi"))
      assert_equal("What? [hi]  ", output.string)
    end

    it "Converts a prompt to a string" do
      input = StringIO.new "hello\n"
      terminal = Toys::Utils::Terminal.new(input: input, output: output)
      assert_equal("hello", terminal.ask(:What))
      assert_equal("What", output.string)
    end
  end

  describe "confirm" do
    it "Displays a default prompt" do
      input = StringIO.new "y\n"
      terminal = Toys::Utils::Terminal.new(input: input, output: output)
      assert_equal(true, terminal.confirm)
      assert_equal("Proceed? (y/n) ", output.string)
    end

    it "Displays a custom prompt" do
      input = StringIO.new "n\n"
      terminal = Toys::Utils::Terminal.new(input: input, output: output)
      assert_equal(false, terminal.confirm("ok? "))
      assert_equal("ok? (y/n) ", output.string)
    end

    it "Converts a prompt to a string" do
      input = StringIO.new "n\n"
      terminal = Toys::Utils::Terminal.new(input: input, output: output)
      assert_equal(false, terminal.confirm(:Ok))
      assert_equal("Ok (y/n)", output.string)
    end

    it "Displays a prompt with default of yes" do
      input = StringIO.new "\n"
      terminal = Toys::Utils::Terminal.new(input: input, output: output)
      assert_equal(true, terminal.confirm("ok? ", default: true))
      assert_equal("ok? (Y/n) ", output.string)
    end

    it "Displays a prompt with default of no" do
      input = StringIO.new "\n"
      terminal = Toys::Utils::Terminal.new(input: input, output: output)
      assert_equal(false, terminal.confirm("ok? ", default: false))
      assert_equal("ok? (y/N) ", output.string)
    end

    it "Handles input EOF" do
      input = StringIO.new
      terminal = Toys::Utils::Terminal.new(input: input, output: output)
      assert_equal(true, terminal.confirm(default: true))
      assert_equal("Proceed? (Y/n) ", output.string)
    end
  end

  describe "nil streams" do
    let(:terminal) { Toys::Utils::Terminal.new(input: nil, output: nil) }

    it "allows write" do
      terminal.write("hello")
    end

    it "allows puts" do
      terminal.puts("hello")
    end

    it "allows ask" do
      resp = terminal.ask("prompt", default: "hello", trailing_text: "trailing")
      assert_equal("hello", resp)
    end

    it "allows confirm with a default" do
      resp = terminal.confirm(default: true)
      assert(resp)
    end

    it "errors on confirm with no default" do
      assert_raises(Toys::Utils::Terminal::TerminalError) do
        terminal.confirm
      end
    end
  end

  describe "spinner" do
    it "outputs leading and final text" do
      terminal.spinner(leading_text: "hello", final_text: "world") do
        # Do nothing
      end
      assert_equal("helloworld", output.string)
    end
  end
end
