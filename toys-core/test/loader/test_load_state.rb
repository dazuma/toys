# frozen_string_literal: true

require "helper"

describe Toys::Loader::LoadState do
  let(:load_state_class) { Toys::Loader::LoadState }
  let(:source_list) { Toys::SourceList.new }
  let(:tool_name_splitter) { Toys::ToolNameSplitter.new(":") }
  let(:loader) { Toys::Loader.new(source_list, tool_name_splitter: tool_name_splitter) }
  let(:source) { Toys::SourceInfo.create_empty_root(0) }
  let(:state) { load_state_class.new(loader, ["foo"], ["bar", "baz"], source) }

  describe ".descend_name" do
    it "returns the inputs unchanged given no new words" do
      assert_equal([["foo"], ["bar"]], load_state_class.descend_name(["foo"], ["bar"], []))
    end

    it "appends new words to the tool name" do
      words, = load_state_class.descend_name(["foo"], [], ["bar", "baz"])
      assert_equal(["foo", "bar", "baz"], words)
    end

    it "converts new words to strings" do
      words, = load_state_class.descend_name([], [], [:foo, :bar])
      assert_equal(["foo", "bar"], words)
    end

    it "consumes matching words from the remaining words" do
      _words, remaining = load_state_class.descend_name([], ["foo", "bar", "baz"], ["foo", "bar"])
      assert_equal(["baz"], remaining)
    end

    it "keeps the remaining words empty once they are exhausted" do
      _words, remaining = load_state_class.descend_name(["foo"], [], ["bar", "baz"])
      assert_equal([], remaining)
    end

    it "prunes when a word does not match the remaining words" do
      _words, remaining = load_state_class.descend_name([], ["foo", "bar"], ["foo", "nope"])
      assert_nil(remaining)
    end

    it "stays pruned once the remaining words are nil" do
      _words, remaining = load_state_class.descend_name(["foo"], nil, ["bar"])
      assert_nil(remaining)
    end

    it "builds the tool name even when pruning" do
      words, remaining = load_state_class.descend_name(["foo"], nil, ["bar", "baz"])
      assert_equal(["foo", "bar", "baz"], words)
      assert_nil(remaining)
    end

    it "does not mutate its arguments" do
      words = ["foo"]
      remaining = ["bar", "baz"]
      load_state_class.descend_name(words, remaining, ["bar"])
      assert_equal(["foo"], words)
      assert_equal(["bar", "baz"], remaining)
    end
  end

  describe "fields" do
    it "provides the source" do
      assert_same(source, state.source)
    end

    it "freezes the words it adopts" do
      words = ["foo"]
      remaining = ["bar"]
      load_state_class.new(loader, words, remaining, source)
      assert(words.frozen?)
      assert(remaining.frozen?)
    end
  end

  describe "#descend_name" do
    it "handles nil remaining words" do
      state = load_state_class.new(loader, ["foo"], nil, source)
      words, remaining = state.descend_name(["bar"])
      assert_equal(["foo", "bar"], words)
      assert_nil(remaining)
    end

    it "consumes matching remaining words" do
      words, remaining = state.descend_name(["bar"])
      assert_equal(["foo", "bar"], words)
      assert_equal(["baz"], remaining)
    end
  end

  describe "#canonical_absolute_tool_name" do
    it "handles an array" do
      assert_equal(["foo", "bar"], state.canonical_absolute_tool_name(["foo", "bar"]))
    end

    it "handles string with delimiters" do
      assert_equal(["foo", "bar"], state.canonical_absolute_tool_name("foo:bar"))
    end
  end

  describe "#canonical_relative_tool_name" do
    it "handles an array" do
      assert_equal(["foo", "foo", "bar"], state.canonical_relative_tool_name(["foo", "bar"]))
    end

    it "handles string with delimiters" do
      assert_equal(["foo", "foo", "bar"], state.canonical_relative_tool_name("foo:bar"))
    end
  end

  describe "#tool_display_name" do
    it "displays a tool name with one word" do
      assert_equal('"foo"', state.tool_display_name)
    end

    it "displays a tool name with multiple words" do
      state = load_state_class.new(loader, ["foo", "bar", "baz"], nil, source)
      assert_equal('"foo bar baz"', state.tool_display_name)
    end

    it "displays a root tool name" do
      state = load_state_class.new(loader, [], nil, source)
      assert_equal("(root)", state.tool_display_name)
    end
  end
end
