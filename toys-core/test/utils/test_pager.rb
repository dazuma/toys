# frozen_string_literal: true

require "helper"
require "toys/utils/pager"

describe Toys::Utils::Pager do
  let(:fallback_io) { StringIO.new }

  it "writes to fallback io if disabled" do
    out, _err = capture_subprocess_io do
      Toys::Utils::Pager.start(command: false, fallback_io: fallback_io) do |io|
        io.puts "hello"
      end
    end
    assert_empty(out)
    assert_equal("hello\n", fallback_io.string)
  end

  it "writes to fallback io if the pager command fails" do
    out, _err = capture_subprocess_io do
      Toys::Utils::Pager.start(command: "blahblah", fallback_io: fallback_io) do |io|
        io.puts "hello"
      end
    end
    assert_empty(out)
    assert_equal("hello\n", fallback_io.string)
  end

  it "calls the default command" do
    skip "Skipped test on Windows" if Toys::Compat.windows?
    out, _err = capture_subprocess_io do
      Toys::Utils::Pager.start(fallback_io: fallback_io) do |io|
        io.puts "ruby rulz"
      end
    end
    assert_equal("ruby rulz\n", out)
    assert_empty(fallback_io.string)
  end

  it "calls a custom command" do
    skip "Skipped test on Windows" if Toys::Compat.windows?
    cat_path = `which cat`.strip
    out, _err = capture_subprocess_io do
      Toys::Utils::Pager.start(command: cat_path, fallback_io: fallback_io) do |io|
        io.puts "ruby rox"
      end
    end
    assert_equal("ruby rox\n", out)
    assert_empty(fallback_io.string)
  end

  describe "with an output stream" do
    let(:output) { StringIO.new }

    it "writes pager output to a non-fd output stream" do
      skip "Skipped test on Windows" if Toys::Compat.windows?
      cat_path = `which cat`.strip
      out, _err = capture_subprocess_io do
        Toys::Utils::Pager.start(command: cat_path, output: output, fallback_io: fallback_io) do |io|
          io.puts "ruby rox"
        end
      end
      assert_empty(out)
      assert_equal("ruby rox\n", output.string)
      assert_empty(fallback_io.string)
    end

    it "writes pager output to an fd output stream" do
      skip "Skipped test on Windows" if Toys::Compat.windows?
      cat_path = `which cat`.strip
      reader, writer = ::IO.pipe
      out, _err = capture_subprocess_io do
        Toys::Utils::Pager.start(command: cat_path, output: writer) do |io|
          io.puts "ruby rox"
        end
      end
      writer.close
      assert_empty(out)
      assert_equal("ruby rox\n", reader.read)
    ensure
      reader&.close
      writer&.close
    end

    it "uses the output stream as the fallback if disabled" do
      out, _err = capture_subprocess_io do
        Toys::Utils::Pager.start(command: false, output: output) do |io|
          io.puts "hello"
        end
      end
      assert_empty(out)
      assert_equal("hello\n", output.string)
    end

    it "uses the output stream as the fallback if the pager command fails" do
      out, _err = capture_subprocess_io do
        Toys::Utils::Pager.start(command: "blahblah", output: output) do |io|
          io.puts "hello"
        end
      end
      assert_empty(out)
      assert_equal("hello\n", output.string)
    end

    it "prefers fallback_io over the output stream for the fallback" do
      Toys::Utils::Pager.start(command: false, output: output, fallback_io: fallback_io) do |io|
        io.puts "hello"
      end
      assert_empty(output.string)
      assert_equal("hello\n", fallback_io.string)
    end

    it "exposes the output stream as an attribute" do
      pager = Toys::Utils::Pager.new(command: false, output: output)
      assert_same(output, pager.output)
    end

    it "uses an output stream set after construction as the fallback" do
      pager = Toys::Utils::Pager.new(command: false)
      pager.output = output
      pager.start do |io|
        io.puts "hello"
      end
      assert_equal("hello\n", output.string)
    end
  end

  it "returns the pager result code" do
    skip "Skipped test on Windows" if Toys::Compat.windows?
    command = [::RbConfig.ruby, "-e", "exit(12)"]
    code = Toys::Utils::Pager.start(command: command, fallback_io: fallback_io) do |io|
      io.puts "ruby rox"
    end
    assert_equal(12, code)
  end

  it "catches broken pipes" do
    skip "Skipped test on Windows" if Toys::Compat.windows?
    command = [::RbConfig.ruby, "-e", "$stdin.read(10); $stdin.close"]
    Toys::Utils::Pager.start(command: command, fallback_io: fallback_io) do |io|
      100.times do
        io.puts "hello ruby hello ruby"
        sleep(0.1)
      end
      flunk("Never got a broken pipe")
    end
  end
end
