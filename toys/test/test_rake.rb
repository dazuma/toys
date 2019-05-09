# frozen_string_literal: true

# Copyright 2018 Daniel Azuma
#
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice,
#   this list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# * Neither the name of the copyright holder, nor the names of any other
#   contributors to this software, may be used to endorse or promote products
#   derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
;

require "helper"

describe "rake template" do
  let(:logger) {
    Logger.new(StringIO.new).tap do |lgr|
      lgr.level = Logger::WARN
    end
  }
  let(:binary_name) { "toys" }
  let(:cli) {
    Toys::CLI.new(
      binary_name: binary_name,
      logger: logger,
      middleware_stack: [],
      template_lookup: Toys::ModuleLookup.new.add_path("toys/templates")
    )
  }
  let(:loader) { cli.loader }

  it "creates tools" do
    loader.add_block do
      expand :rake, rakefile_path: File.join(__dir__, "rakefiles/Rakefile1")
    end
    tool, remaining = loader.lookup(["foo1", "bar"])
    assert_equal(["foo1"], tool.full_name)
    assert_equal("Foo1 description", tool.desc.to_s)
    assert_equal(["bar"], remaining)
    tool, remaining = loader.lookup(["ns1", "foo2", "bar"])
    assert_equal(["ns1", "foo2"], tool.full_name)
    assert_equal("Foo2 description", tool.desc.to_s)
    assert_equal(["bar"], remaining)
  end

  it "does not replace existing tools" do
    loader.add_block do
      tool "foo1" do
        desc "Real foo1 description"
      end
      expand :rake, rakefile_path: File.join(__dir__, "rakefiles/Rakefile1")
    end
    tool, remaining = loader.lookup(["foo1", "bar"])
    assert_equal(["foo1"], tool.full_name)
    assert_equal("Real foo1 description", tool.desc.to_s)
    assert_equal(["bar"], remaining)
    tool, remaining = loader.lookup(["ns1", "foo2", "bar"])
    assert_equal(["ns1", "foo2"], tool.full_name)
    assert_equal("Foo2 description", tool.desc.to_s)
    assert_equal(["bar"], remaining)
  end

  it "creates tools from multiple rakefiles" do
    loader.add_block do
      expand :rake, rakefile_path: File.join(__dir__, "rakefiles/Rakefile2")
    end
    loader.add_block do
      expand :rake, rakefile_path: File.join(__dir__, "rakefiles/Rakefile1")
    end
    tool, remaining = loader.lookup(["foo1", "bar"])
    assert_equal(["foo1"], tool.full_name)
    assert_equal("Foo1 description from 2", tool.desc.to_s)
    assert_equal(["bar"], remaining)
    tool, remaining = loader.lookup(["ns1", "foo2", "bar"])
    assert_equal(["ns1", "foo2"], tool.full_name)
    assert_equal("Foo2 description", tool.desc.to_s)
    assert_equal(["bar"], remaining)
  end

  it "executes tools honoring rake dependencies" do
    rakefile_path = File.join(__dir__, "rakefiles/Rakefile2")
    loader.add_block do
      expand :rake, rakefile_path: rakefile_path
    end
    assert_output("executing bar1 from 2\nexecuting foo1 from 2\n") do
      cli.run("foo1")
    end
  end

  it "creates and executes a tool with arguments" do
    rakefile_path = File.join(__dir__, "rakefiles/Rakefile3")
    loader.add_block do
      expand :rake, rakefile_path: rakefile_path
    end
    tool, _remaining = loader.lookup(["foo"])
    assert_equal(2, tool.optional_arg_definitions.size)
    assert(tool.flag_definitions.empty?)
    assert_equal(:one_two, tool.optional_arg_definitions[0].key)
    assert_equal(:three, tool.optional_arg_definitions[1].key)
    assert_output("executing foo\n\"hello\"\nnil\n") do
      cli.run("foo", "hello")
    end
  end

  it "creates and executes a tool with flags for arguments" do
    rakefile_path = File.join(__dir__, "rakefiles/Rakefile3")
    loader.add_block do
      expand :rake, rakefile_path: rakefile_path, use_flags: true
    end
    tool, _remaining = loader.lookup(["foo"])
    assert_equal(2, tool.flag_definitions.size)
    assert(tool.optional_arg_definitions.empty?)
    assert_equal(:one_two, tool.flag_definitions[0].key)
    assert_equal(:three, tool.flag_definitions[1].key)
    assert_output("executing foo\n\"hi\"\n\"there\"\n") do
      cli.run("foo", "--one_two=hi", "--three", "there")
    end
  end

  it "allows dashes in flags" do
    rakefile_path = File.join(__dir__, "rakefiles/Rakefile3")
    loader.add_block do
      expand :rake, rakefile_path: rakefile_path, use_flags: true
    end
    assert_output("executing foo\n\"hello\"\nnil\n") do
      cli.run("foo", "--one-two=hello")
    end
  end

  it "creates tools without a description by default" do
    rakefile_path = File.join(__dir__, "rakefiles/Rakefile3")
    loader.add_block do
      expand :rake, rakefile_path: rakefile_path
    end
    tool, remaining = loader.lookup(["bar"])
    assert_equal(["bar"], tool.full_name)
    assert_equal([], remaining)
  end

  it "does not creates tools without a description if requested" do
    rakefile_path = File.join(__dir__, "rakefiles/Rakefile3")
    loader.add_block do
      expand :rake, rakefile_path: rakefile_path, only_described: true
    end
    tool, remaining = loader.lookup(["bar"])
    assert_equal([], tool.full_name)
    assert_equal(["bar"], remaining)
  end

  it "searches up the directory tree for rakefiles" do
    Dir.chdir(File.join(__dir__, "rake-dirs", "dir1", "dir2")) do
      loader.add_path(File.join(__dir__, "rake-dirs", ".toys.rb"))
      tool, remaining = loader.lookup(["foo1", "bar"])
      assert_equal(["foo1"], tool.full_name)
      assert_equal(["bar"], remaining)
      rakefile_path = File.join(__dir__, "rake-dirs", "dir1", "Rakefile")
      expected_comments = [
        "Foo1 description", "",
        "Defined as a Rake task in #{rakefile_path}"
      ]
      assert_equal(expected_comments, tool.long_desc.map(&:to_s))
    end
  end

  it "sets the current working directory to the Rakefile directory" do
    Dir.chdir(File.join(__dir__, "rake-dirs", "dir1", "dir2")) do
      loader.add_path(File.join(__dir__, "rake-dirs", ".toys.rb"))
      assert_output("Found = true\n") do
        cli.run("foo1")
      end
    end
  end
end
