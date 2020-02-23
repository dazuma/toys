# frozen_string_literal: true

require "helper"

describe Toys::Completion do
  def context(str)
    Toys::Completion::Context.new(cli: nil, fragment: str)
  end

  describe ".create" do
    it "passes through an existing completion" do
      completion = Toys::Completion.create(["one", :two, ["three"]])
      completion2 = Toys::Completion.create(completion)
      assert_equal(completion, completion2)
    end

    it "recognizes nil" do
      completion = Toys::Completion.create(nil)
      assert_equal(Toys::Completion::EMPTY, completion)
    end

    it "recognizes :default" do
      completion = Toys::Completion.create(:default)
      assert_equal(Toys::Completion::EMPTY, completion)
    end

    it "recognizes :empty" do
      completion = Toys::Completion.create(:empty)
      assert_equal(Toys::Completion::EMPTY, completion)
    end

    it "recognizes :file_system" do
      completion = Toys::Completion.create(:file_system)
      assert_instance_of(Toys::Completion::FileSystem, completion)
      assert(completion.include_files)
      assert(completion.include_directories)
    end

    it "recognizes :file_system with options" do
      completion = Toys::Completion.create(:file_system, omit_directories: true)
      assert_instance_of(Toys::Completion::FileSystem, completion)
      assert(completion.include_files)
      refute(completion.include_directories)
    end

    it "recognizes an array" do
      completion = Toys::Completion.create(["one", :two, ["three"]])
      assert_instance_of(Toys::Completion::Enum, completion)
      expected = Toys::Completion::Candidate.new_multi(["one", "three", "two"])
      assert_equal(expected, completion.values)
      assert_equal("", completion.prefix_constraint)
    end

    it "recognizes an array wiht options" do
      completion = Toys::Completion.create(["one", :two, ["three"]], prefix_constraint: "hi")
      assert_instance_of(Toys::Completion::Enum, completion)
      expected = Toys::Completion::Candidate.new_multi(["one", "three", "two"])
      assert_equal(expected, completion.values)
      assert_equal("hi", completion.prefix_constraint)
    end

    it "recognizes a proc" do
      my_proc = proc { |s| [s] }
      completion = Toys::Completion.create(my_proc)
      assert_equal(my_proc, completion)
    end

    it "errors on unrecognized spec" do
      assert_raises(Toys::ToolDefinitionError) do
        Toys::Completion.create(:hiho)
      end
    end
  end

  describe "EMPTY" do
    it "returns nothing" do
      completion = Toys::Completion::EMPTY
      assert_equal([], completion.call(context("")))
    end
  end
end

describe Toys::Completion::FileSystem do
  let(:data_dir) { ::File.join(__dir__, "data") }
  let(:completion) { Toys::Completion::FileSystem.new(cwd: data_dir) }
  def context(str)
    Toys::Completion::Context.new(cli: nil, fragment: str)
  end

  it "returns objects when passed an empty string" do
    candidates = completion.call(context(""))
    expected = [
      Toys::Completion::Candidate.new(".dotfile"),
      Toys::Completion::Candidate.new("indirectory/", partial: true),
      Toys::Completion::Candidate.new("input.txt"),
    ]
    assert_equal(expected, candidates)
  end

  it "returns objects when passed a prefix" do
    candidates = completion.call(context("in"))
    expected = [
      Toys::Completion::Candidate.new("indirectory/", partial: true),
      Toys::Completion::Candidate.new("input.txt"),
    ]
    assert_equal(expected, candidates)
  end

  it "returns nothing when passed an unfulfilled prefix" do
    candidates = completion.call(context("out"))
    assert_equal([], candidates)
  end

  it "returns objects when passed a glob that begins with a star" do
    candidates = completion.call(context("*.txt"))
    expected = Toys::Completion::Candidate.new_multi(["input.txt"])
    assert_equal(expected, candidates)
  end

  it "returns dotfiles when passed a glob that begins with a dot" do
    candidates = completion.call(context(".*"))
    expected = Toys::Completion::Candidate.new_multi([".dotfile"])
    assert_equal(expected, candidates)
  end

  it "returns non dotfiles when passed a star" do
    candidates = completion.call(context("*"))
    expected = [
      Toys::Completion::Candidate.new("indirectory/", partial: true),
      Toys::Completion::Candidate.new("input.txt"),
    ]
    assert_equal(expected, candidates)
  end

  it "returns a directory given the entire name" do
    candidates = completion.call(context("indirectory"))
    expected = Toys::Completion::Candidate.new_multi(["indirectory/"], partial: true)
    assert_equal(expected, candidates)
  end

  it "returns contents of a directory when ending with a slash" do
    candidates = completion.call(context("indirectory/"))
    expected = Toys::Completion::Candidate.new_multi(
      ["indirectory/.anotherdot", "indirectory/content.txt"]
    )
    assert_equal(expected, candidates)
  end

  it "returns glob in a directory" do
    candidates = completion.call(context("indirectory/c*"))
    expected = Toys::Completion::Candidate.new_multi(["indirectory/content.txt"])
    assert_equal(expected, candidates)
  end

  it "returns prefix in a directory" do
    candidates = completion.call(context("indirectory/."))
    expected = Toys::Completion::Candidate.new_multi(["indirectory/.anotherdot"])
    assert_equal(expected, candidates)
  end

  it "returns files only" do
    completion = Toys::Completion::FileSystem.new(cwd: data_dir, omit_directories: true)
    candidates = completion.call(context("in"))
    expected = Toys::Completion::Candidate.new_multi(["input.txt"])
    assert_equal(expected, candidates)
  end

  it "returns directories only" do
    completion = Toys::Completion::FileSystem.new(cwd: data_dir, omit_files: true)
    candidates = completion.call(context("in"))
    expected = Toys::Completion::Candidate.new_multi(["indirectory/"], partial: true)
    assert_equal(expected, candidates)
  end
end

describe Toys::Completion::Enum do
  let(:completion) { Toys::Completion::Enum.new(["one", :two, ["three"]]) }
  def context(str, prefix: "")
    Toys::Completion::Context.new(cli: nil, fragment: str, fragment_prefix: prefix)
  end

  it "returns all values when given an empty string" do
    candidates = completion.call(context(""))
    expected = Toys::Completion::Candidate.new_multi(["one", "three", "two"])
    assert_equal(expected, candidates)
  end

  it "returns values when given a fragment" do
    candidates = completion.call(context("t"))
    expected = Toys::Completion::Candidate.new_multi(["three", "two"])
    assert_equal(expected, candidates)
  end

  it "returns nothing when given a fragment and a bad prefix" do
    candidates = completion.call(context("t", prefix: "hi="))
    assert_equal([], candidates)
  end

  it "returns nothing when given an unfulfilled fragment" do
    candidates = completion.call(context("w"))
    assert_equal([], candidates)
  end

  describe "with a prefix constraint" do
    let(:completion) {
      Toys::Completion::Enum.new(["one", :two, ["three"]], prefix_constraint: /^[a-z]+=$/)
    }

    it "returns nothing when given a nonconforming prefix" do
      candidates = completion.call(context("t"))
      assert_equal([], candidates)
    end

    it "returns values when given the right prefix" do
      candidates = completion.call(context("t", prefix: "hello="))
      expected = Toys::Completion::Candidate.new_multi(["three", "two"])
      assert_equal(expected, candidates)
    end
  end
end
