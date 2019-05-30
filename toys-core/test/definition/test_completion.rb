# frozen_string_literal: true

# Copyright 2019 Daniel Azuma
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.
;

require "helper"

describe Toys::Completion do
  def context(str)
    Toys::Completion::Context.new(nil, [], str, {})
  end

  describe ".create" do
    it "recognizes nil" do
      completion = Toys::Completion.create(nil)
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

    it "recognizes an array" do
      completion = Toys::Completion.create(["one", :two, ["three"]])
      assert_instance_of(Toys::Completion::Values, completion)
      expected = Toys::Completion::Candidate.new_multi(["one", "three", "two"])
      assert_equal(expected, completion.values)
    end

    it "recognizes a proc" do
      my_proc = proc { |s| [s] }
      completion = Toys::Completion.create(my_proc)
      assert_equal(my_proc, completion)
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
  let(:data_dir) { ::File.join(::File.dirname(__dir__), "data") }
  let(:completion) { Toys::Completion::FileSystem.new(cwd: data_dir) }
  def context(str)
    Toys::Completion::Context.new(nil, [], str, {})
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

describe Toys::Completion::Values do
  let(:completion) { Toys::Completion::Values.new(["one", :two, ["three"]]) }
  def context(str)
    Toys::Completion::Context.new(nil, [], str, {})
  end

  it "returns all values when given an empty string" do
    candidates = completion.call(context(""))
    expected = Toys::Completion::Candidate.new_multi(["one", "three", "two"])
    assert_equal(expected, candidates)
  end

  it "returns values when given a prefix" do
    candidates = completion.call(context("t"))
    expected = Toys::Completion::Candidate.new_multi(["three", "two"])
    assert_equal(expected, candidates)
  end

  it "returns nothing when given an unfulfilled prefix" do
    candidates = completion.call(context("w"))
    assert_equal([], candidates)
  end
end
