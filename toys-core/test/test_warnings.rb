# frozen_string_literal: true

require "helper"

describe Toys::Warnings do
  let(:simple_message) { "This is a message" }
  let(:suppression_hint) { "to suppress these warnings altogether, set TOYS_SUPPRESS_WARNINGS to a nonempty value" }

  before do
    @old_env = ENV[Toys::Warnings::SUPPRESS_WARNINGS_ENV]
    @old_max_count = Toys::Warnings.max_count
    Toys::Warnings.reset_counts
    Toys::Warnings.max_count = Toys::Warnings::DEFAULT_MAX_COUNT
    ENV[Toys::Warnings::SUPPRESS_WARNINGS_ENV] = nil
  end

  after do
    Toys::Warnings.reset_counts
    Toys::Warnings.max_count = @old_max_count
    ENV[Toys::Warnings::SUPPRESS_WARNINGS_ENV] = @old_env
  end

  def warn_now(identifier: :my_warning, message: nil, uplevel: nil, max_count: :default, expect_count: nil)
    message ||= simple_message
    kwargs = {uplevel: uplevel, max_count: max_count}
    count = Toys::Warnings.warn(identifier, message, **kwargs); line = __LINE__ # rubocop:disable Style/Semicolon
    assert_equal(expect_count, count) if expect_count
    line
  end

  def expected_prefix(line)
    "test/test_warnings.rb:#{line}: warning"
  end

  describe "with uplevel" do
    it "formats the message for uplevel=nil" do
      _out, err = capture_io do
        warn_now(expect_count: 1)
      end
      expected_lines = ["#{simple_message} (#{suppression_hint})"]
      assert_equal(expected_lines, err.split("\n"))
    end

    it "formats the message for uplevel=0" do
      line = nil
      _out, err = capture_io do
        line = warn_now(uplevel: 0, expect_count: 1)
      end
      assert_includes(err, "#{expected_prefix(line)}: #{simple_message} (#{suppression_hint})\n")
    end

    it "formats the message for uplevel=1" do
      line = nil
      _out, err = capture_io do
        warn_now(uplevel: 1, expect_count: 1); line = __LINE__ # rubocop:disable Style/Semicolon
      end
      assert_includes(err, "#{expected_prefix(line)}: #{simple_message} (#{suppression_hint})\n")
    end

    it "formats the message for a large uplevel" do
      _out, err = capture_io do
        warn_now(uplevel: 1000, expect_count: 1)
      end
      expected_lines = ["warning: #{simple_message} (#{suppression_hint})"]
      assert_equal(expected_lines, err.split("\n"))
    end
  end

  describe "with repeats" do
    it "displays repeated messages with counts" do
      _out, err = capture_io do
        warn_now(expect_count: 1)
        warn_now(expect_count: 2)
      end
      expected_lines = [
        "#{simple_message} (#{suppression_hint})",
        "#{simple_message} (count: 2)",
      ]
      assert_equal(expected_lines, err.split("\n"))
    end

    it "displays messages with different identifiers" do
      _out, err = capture_io do
        warn_now(identifier: 1, message: "message1", expect_count: 1)
        warn_now(identifier: 2, message: "message2", expect_count: 1)
        warn_now(identifier: 2, message: "message3", expect_count: 2)
      end
      expected_lines = [
        "message1 (#{suppression_hint})",
        "message2 (#{suppression_hint})",
        "message3 (count: 2)",
      ]
      assert_equal(expected_lines, err.split("\n"))
    end
  end

  describe "with max_count" do
    it "limits repeated messages to DEFAULT_MAX_COUNT per-identifier" do
      _out, err = capture_io do
        (1..8).each do |count|
          warn_now(identifier: 1, message: "message1", expect_count: count)
          warn_now(identifier: 2, message: "message2", expect_count: count)
        end
      end
      expected_lines = [
        "message1 (#{suppression_hint})",
        "message2 (#{suppression_hint})",
        "message1 (count: 2)",
        "message2 (count: 2)",
        "message1 (count: 3)",
        "message2 (count: 3)",
        "message1 (count: 4)",
        "message2 (count: 4)",
        "message1 (count: 5, further warnings suppressed)",
        "message2 (count: 5, further warnings suppressed)",
      ]
      assert_equal(expected_lines, err.split("\n"))
    end

    it "limits repeated messages to a set max_count per-identifier" do
      _out, err = capture_io do
        (1..8).each do |count|
          warn_now(identifier: 1, message: "message1", max_count: 3, expect_count: count)
          warn_now(identifier: 2, message: "message2", max_count: 5, expect_count: count)
        end
      end
      expected_lines = [
        "message1 (#{suppression_hint})",
        "message2 (#{suppression_hint})",
        "message1 (count: 2)",
        "message2 (count: 2)",
        "message1 (count: 3, further warnings suppressed)",
        "message2 (count: 3)",
        "message2 (count: 4)",
        "message2 (count: 5, further warnings suppressed)",
      ]
      assert_equal(expected_lines, err.split("\n"))
    end

    it "handles max_count=1" do
      _out, err = capture_io do
        (1..3).each do |count|
          warn_now(max_count: 1, expect_count: count)
        end
      end
      expected_lines = [
        "#{simple_message} (further warnings suppressed, #{suppression_hint})",
      ]
      assert_equal(expected_lines, err.split("\n"))
    end

    it "handles max_count=0" do
      _out, err = capture_io do
        (1..3).each do |count|
          warn_now(max_count: 0, expect_count: count)
        end
      end
      assert_empty(err)
    end

    it "honors a nil max_count" do
      _out, err = capture_io do
        (1..8).each do |count|
          warn_now(identifier: 1, message: "message1", max_count: 3, expect_count: count)
          warn_now(identifier: 2, message: "message2", max_count: nil, expect_count: count)
        end
      end
      expected_lines = [
        "message1 (#{suppression_hint})",
        "message2 (#{suppression_hint})",
        "message1 (count: 2)",
        "message2 (count: 2)",
        "message1 (count: 3, further warnings suppressed)",
        "message2 (count: 3)",
        "message2 (count: 4)",
        "message2 (count: 5)",
        "message2 (count: 6)",
        "message2 (count: 7)",
        "message2 (count: 8)",
      ]
      assert_equal(expected_lines, err.split("\n"))
    end
  end

  describe "with global max_count" do
    it "set to a number limits repeated messages to the new value" do
      Toys::Warnings.max_count = 3
      _out, err = capture_io do
        (1..10).each { |count| warn_now(expect_count: count) }
      end
      expected_lines = [
        "This is a message (#{suppression_hint})",
        "This is a message (count: 2)",
        "This is a message (count: 3, further warnings suppressed)",
      ]
      assert_equal(expected_lines, err.split("\n"))
    end

    it "set to nil does not limit repeated messages" do
      Toys::Warnings.max_count = nil
      _out, err = capture_io do
        (1..8).each { |count| warn_now(expect_count: count) }
      end
      expected_lines = [
        "This is a message (#{suppression_hint})",
        "This is a message (count: 2)",
        "This is a message (count: 3)",
        "This is a message (count: 4)",
        "This is a message (count: 5)",
        "This is a message (count: 6)",
        "This is a message (count: 7)",
        "This is a message (count: 8)",
      ]
      assert_equal(expected_lines, err.split("\n"))
    end
  end

  describe "with environment variable" do
    it "suppresses warnings but still returns count when the environment variable is set" do
      ::ENV[Toys::Warnings::SUPPRESS_WARNINGS_ENV] = "1"
      _out, err = capture_io do
        warn_now(expect_count: 1)
        warn_now(expect_count: 2)
      end
      assert_empty(err)
    end

    it "does not suppress warnings if the environment variable is empty" do
      ::ENV[Toys::Warnings::SUPPRESS_WARNINGS_ENV] = ""
      _out, err = capture_io do
        warn_now(expect_count: 1)
      end
      refute_empty(err)
    end
  end

  describe "validation" do
    it "accepts valid global max_count values" do
      [0, 3, nil].each do |value|
        Toys::Warnings.max_count = value
        assert_equal(value.inspect, Toys::Warnings.max_count.inspect)
      end
    end

    it "rejects invalid global max_count values" do
      [-1, "3", 3.0, :default].each do |value|
        assert_raises(ArgumentError) do
          Toys::Warnings.max_count = value
        end
      end
      assert_equal(Toys::Warnings::DEFAULT_MAX_COUNT, Toys::Warnings.max_count)
    end

    it "rejects an invalid max_count argument without counting or displaying" do
      _out, err = capture_io do
        [-1, "3", 3.0].each do |value|
          assert_raises(ArgumentError) do
            Toys::Warnings.warn(:my_warning, simple_message, max_count: value)
          end
        end
        warn_now(expect_count: 1)
      end
      expected_lines = ["#{simple_message} (#{suppression_hint})"]
      assert_equal(expected_lines, err.split("\n"))
    end

    it "rejects an invalid uplevel argument without counting or displaying" do
      _out, err = capture_io do
        [-1, "1", 1.0].each do |value|
          assert_raises(ArgumentError) do
            Toys::Warnings.warn(:my_warning, simple_message, uplevel: value)
          end
        end
        warn_now(expect_count: 1)
      end
      expected_lines = ["#{simple_message} (#{suppression_hint})"]
      assert_equal(expected_lines, err.split("\n"))
    end
  end
end
