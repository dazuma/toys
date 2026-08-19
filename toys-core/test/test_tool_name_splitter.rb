# frozen_string_literal: true

require "helper"

describe Toys::ToolNameSplitter do
  let(:default_splitter) { Toys::ToolNameSplitter.new }
  let(:delimiter_splitter) { Toys::ToolNameSplitter.new(".:") }

  describe "construction" do
    it "defaults to no extra delimiters" do
      assert_equal("", Toys::ToolNameSplitter.new.extra_delimiters)
    end

    it "reports the extra delimiters it was constructed with" do
      assert_equal(".:", delimiter_splitter.extra_delimiters)
    end

    it "allows period, colon, slash, and whitespace" do
      splitter = Toys::ToolNameSplitter.new(".:/ ")
      assert_equal(".:/ ", splitter.extra_delimiters)
      assert_equal(["one", "two", "three", "four"], splitter.split("one.two:three/four"))
    end

    it "raises if a delimiter is not allowed" do
      error = assert_raises(::ArgumentError) do
        Toys::ToolNameSplitter.new(",")
      end
      assert_includes(error.message, "Illegal delimiters")
    end

    it "raises if only one of several delimiters is not allowed" do
      assert_raises(::ArgumentError) do
        Toys::ToolNameSplitter.new(".,:")
      end
    end

    it "includes the extra delimiters in its inspect string" do
      assert_includes(delimiter_splitter.inspect, ".:")
    end
  end

  describe "DEFAULT" do
    it "has no extra delimiters" do
      assert_equal("", Toys::ToolNameSplitter::DEFAULT.extra_delimiters)
    end

    it "is the splitter used by a loader that is given none" do
      assert_same(Toys::ToolNameSplitter::DEFAULT, Toys::Loader.new(Toys::SourceList.new).tool_name_splitter)
    end

    it "is frozen" do
      assert(Toys::ToolNameSplitter::DEFAULT.frozen?)
    end
  end

  describe "#split" do
    it "splits at an extra delimiter" do
      assert_equal(["namespace-1", "tool"], delimiter_splitter.split("namespace-1.tool"))
    end

    it "splits at several different delimiters" do
      assert_equal(["one", "two", "three"], delimiter_splitter.split("one.two:three"))
    end

    it "splits at whitespace" do
      assert_equal(["namespace-1", "tool"], delimiter_splitter.split("namespace-1 tool"))
    end

    it "splits at whitespace when no extra delimiters are configured" do
      assert_equal(["one", "two"], default_splitter.split("one two"))
    end

    it "does not split at a delimiter that is not configured" do
      assert_equal(["one.two"], default_splitter.split("one.two"))
    end

    it "returns an empty array for an empty string" do
      # This is ToolNameSplitter#split, not String#split, so StringChars does
      # not apply.
      assert_equal([], delimiter_splitter.split("")) # rubocop:disable Style/StringChars
    end

    it "converts a symbol to a single word" do
      assert_equal(["tool"], delimiter_splitter.split(:tool))
    end

    it "splits a symbol at delimiters" do
      assert_equal(["namespace-1", "tool"], delimiter_splitter.split(:"namespace-1.tool"))
    end

    it "passes an array of strings through" do
      assert_equal(["namespace-1", "tool"], delimiter_splitter.split(["namespace-1", "tool"]))
    end

    it "converts array elements to strings" do
      assert_equal(["namespace-1", "tool"], delimiter_splitter.split([:"namespace-1", "tool"]))
    end

    it "does not split the elements of an array" do
      assert_equal(["one.two"], delimiter_splitter.split(["one.two"]))
    end

    it "returns an empty array for an empty array" do
      assert_equal([], delimiter_splitter.split([]))
    end

    it "does not modify the array passed in" do
      input = ["namespace-1", "tool"]
      delimiter_splitter.split(input)
      assert_equal(["namespace-1", "tool"], input)
    end
  end

  describe "#split_partial" do
    it "splits at the final delimiter" do
      assert_equal(["namespace-1.", "tool"], delimiter_splitter.split_partial("namespace-1.tool"))
    end

    it "splits at the final of several delimiters" do
      assert_equal(["one.two:", "three"], delimiter_splitter.split_partial("one.two:three"))
    end

    it "returns an empty trailing word when the string ends with a delimiter" do
      assert_equal(["namespace-1.", ""], delimiter_splitter.split_partial("namespace-1."))
    end

    it "returns an empty prefix when there is no delimiter" do
      assert_equal(["", "tool"], delimiter_splitter.split_partial("tool"))
    end

    it "does not treat a leading delimiter as a separator" do
      assert_equal(["", ".tool"], delimiter_splitter.split_partial(".tool"))
    end

    it "splits at whitespace" do
      assert_equal(["namespace-1 ", "tool"], delimiter_splitter.split_partial("namespace-1 tool"))
    end

    it "does not split at a delimiter that is not configured" do
      assert_equal(["", "one.two"], default_splitter.split_partial("one.two"))
    end

    it "splits at whitespace when no extra delimiters are configured" do
      assert_equal(["one ", "two"], default_splitter.split_partial("one two"))
    end

    it "returns an empty prefix for an empty string" do
      assert_equal(["", ""], delimiter_splitter.split_partial(""))
    end
  end
end
