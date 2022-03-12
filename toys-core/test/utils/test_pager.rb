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
    skip if Toys::Compat.windows?
    out, _err = capture_subprocess_io do
      Toys::Utils::Pager.start(fallback_io: fallback_io) do |io|
        io.puts "ruby rulz"
      end
    end
    assert_equal("ruby rulz\n", out)
    assert_empty(fallback_io.string)
  end

  it "calls a custom command" do
    skip if Toys::Compat.windows?
    cat_path = `which cat`.strip
    out, _err = capture_subprocess_io do
      Toys::Utils::Pager.start(command: cat_path, fallback_io: fallback_io) do |io|
        io.puts "ruby rox"
      end
    end
    assert_equal("ruby rox\n", out)
    assert_empty(fallback_io.string)
  end
end
