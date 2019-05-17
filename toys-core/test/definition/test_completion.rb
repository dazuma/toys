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

describe Toys::Definition::Completion do
  describe ".create" do
    it "recognizes nil" do
      completion = Toys::Definition::Completion.create(nil)
      assert_equal(Toys::Definition::Completion::EMPTY, completion)
    end

    it "recognizes :empty" do
      completion = Toys::Definition::Completion.create(:empty)
      assert_equal(Toys::Definition::Completion::EMPTY, completion)
    end

    it "recognizes :file_system" do
      completion = Toys::Definition::Completion.create(:file_system)
      assert_instance_of(Toys::Definition::FileSystemCompletion, completion)
      assert(completion.include_files)
      assert(completion.include_directories)
    end

    it "recognizes :files_only" do
      completion = Toys::Definition::Completion.create(:files_only)
      assert_instance_of(Toys::Definition::FileSystemCompletion, completion)
      assert(completion.include_files)
      refute(completion.include_directories)
    end

    it "recognizes :directories_only" do
      completion = Toys::Definition::Completion.create(:directories_only)
      assert_instance_of(Toys::Definition::FileSystemCompletion, completion)
      refute(completion.include_files)
      assert(completion.include_directories)
    end

    it "recognizes an array" do
      completion = Toys::Definition::Completion.create(["one", :two, ["three"]])
      assert_instance_of(Toys::Definition::ValuesCompletion, completion)
      assert_equal(["one", "three", "two"], completion.values)
    end

    it "recognizes a proc" do
      my_proc = proc { |s| [s] }
      completion = Toys::Definition::Completion.create(my_proc)
      assert_equal(my_proc, completion)
    end
  end

  describe "EMPTY" do
    it "returns nothing" do
      completion = Toys::Definition::Completion::EMPTY
      assert_equal([], completion.call(""))
    end
  end
end

describe Toys::Definition::FileSystemCompletion do
  let(:data_dir) { ::File.join(::File.dirname(__dir__), "data") }
  let(:completion) { Toys::Definition::FileSystemCompletion.new(cwd: data_dir) }

  it "returns objects when passed an empty string" do
    candidates = completion.call("")
    assert_equal([".dotfile", "indirectory", "input.txt"], candidates)
  end

  it "returns objects when passed a prefix" do
    candidates = completion.call("in")
    assert_equal(["indirectory", "input.txt"], candidates)
  end

  it "returns nothing when passed an unfulfilled prefix" do
    candidates = completion.call("out")
    assert_equal([], candidates)
  end

  it "returns objects when passed a glob that begins with a star" do
    candidates = completion.call("*.txt")
    assert_equal(["input.txt"], candidates)
  end

  it "returns dotfiles when passed a glob that begins with a dot" do
    candidates = completion.call(".*")
    assert_equal([".dotfile"], candidates)
  end

  it "returns non dotfiles when passed a star" do
    candidates = completion.call("*")
    assert_equal(["indirectory", "input.txt"], candidates)
  end

  it "returns a directory given the entire name" do
    candidates = completion.call("indirectory")
    assert_equal(["indirectory"], candidates)
  end

  it "returns contents of a directory when ending with a slash" do
    candidates = completion.call("indirectory/")
    assert_equal([".anotherdot", "content.txt"], candidates)
  end

  it "returns glob in a directory" do
    candidates = completion.call("indirectory/c*")
    assert_equal(["content.txt"], candidates)
  end

  it "returns prefix in a directory" do
    candidates = completion.call("indirectory/.")
    assert_equal([".anotherdot"], candidates)
  end

  it "returns files only" do
    completion = Toys::Definition::FileSystemCompletion.new(cwd: data_dir, omit_directories: true)
    candidates = completion.call("in")
    assert_equal(["input.txt"], candidates)
  end

  it "returns directories only" do
    completion = Toys::Definition::FileSystemCompletion.new(cwd: data_dir, omit_files: true)
    candidates = completion.call("in")
    assert_equal(["indirectory"], candidates)
  end
end

describe Toys::Definition::ValuesCompletion do
  let(:completion) { Toys::Definition::ValuesCompletion.new(["one", :two, ["three"]]) }

  it "returns all values when given an empty string" do
    candidates = completion.call("")
    assert_equal(["one", "three", "two"], candidates)
  end

  it "returns values when given a prefix" do
    candidates = completion.call("t")
    assert_equal(["three", "two"], candidates)
  end

  it "returns nothing when given an unfulfilled prefix" do
    candidates = completion.call("w")
    assert_equal([], candidates)
  end
end
