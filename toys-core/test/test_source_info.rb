# frozen_string_literal: true

require "helper"

describe Toys::SourceInfo do
  let(:lookup_cases_dir) { File.join(__dir__, "lookup-cases") }
  let(:directory_path) { File.join(lookup_cases_dir, "config-items") }
  let(:file_path) { File.join(directory_path, ".toys.rb") }
  let(:path_with_data) { File.join(lookup_cases_dir, "data-finder") }
  let(:bad_path) { File.join(lookup_cases_dir, "doesnotexist") }
  let(:git_remote) { "https://github.com/dazuma/toys.git" }
  let(:git_commit) { "main" }
  let(:git_directory_path) { "toys-core/test/lookup-cases/config-items" }
  let(:git_file_path) { "toys-core/test/lookup-cases/config-items/.toys.rb" }
  let(:git_path_with_data) { "toys-core/test/lookup-cases/data-finder" }
  let(:my_proc) { proc { :a } }
  let(:my_proc2) { proc { :b } }
  let(:data_dir_name) { ".data" }
  let(:lib_dir_name) { ".lib" }
  let(:custom_source_name) { "mysource" }
  let(:priority) { -1 }

  describe "creation" do
    it "creates a file system root pointing to a directory" do
      si = Toys::SourceInfo.create_path_root(directory_path, priority,
                                             context_directory: :path,
                                             data_dir_name: data_dir_name,
                                             lib_dir_name: lib_dir_name)
      assert_nil(si.parent)
      assert_equal(si, si.root)
      assert_equal(priority, si.priority)
      assert_equal(directory_path, si.context_directory)
      assert_equal(directory_path, si.source)
      assert_equal(:directory, si.source_type)
      assert_equal(directory_path, si.source_path)
      assert_nil(si.source_proc)
      assert_nil(si.git_remote)
      assert_nil(si.git_path)
      assert_nil(si.git_commit)
      assert_equal(directory_path, si.source_name)
    end

    it "creates a file system root pointing to a file" do
      si = Toys::SourceInfo.create_path_root(file_path, priority,
                                             context_directory: :parent,
                                             data_dir_name: data_dir_name,
                                             lib_dir_name: lib_dir_name)
      assert_nil(si.parent)
      assert_equal(si, si.root)
      assert_equal(priority, si.priority)
      assert_equal(directory_path, si.context_directory)
      assert_equal(file_path, si.source)
      assert_equal(:file, si.source_type)
      assert_equal(file_path, si.source_path)
      assert_nil(si.source_proc)
      assert_nil(si.git_remote)
      assert_nil(si.git_path)
      assert_nil(si.git_commit)
      assert_equal(file_path, si.source_name)
    end

    it "creates a proc root" do
      si = Toys::SourceInfo.create_proc_root(my_proc, priority,
                                             source_name: custom_source_name,
                                             data_dir_name: data_dir_name,
                                             lib_dir_name: lib_dir_name)
      assert_nil(si.parent)
      assert_equal(si, si.root)
      assert_equal(priority, si.priority)
      assert_nil(si.context_directory)
      assert_equal(my_proc, si.source)
      assert_equal(:proc, si.source_type)
      assert_nil(si.source_path)
      assert_equal(my_proc, si.source_proc)
      assert_nil(si.git_remote)
      assert_nil(si.git_path)
      assert_nil(si.git_commit)
      assert_equal(custom_source_name, si.source_name)
    end

    it "creates a git root pointing to a directory" do
      si = Toys::SourceInfo.create_git_root(git_remote, git_directory_path, git_commit,
                                            directory_path, priority,
                                            data_dir_name: data_dir_name,
                                            lib_dir_name: lib_dir_name)
      assert_nil(si.parent)
      assert_equal(si, si.root)
      assert_equal(priority, si.priority)
      assert_nil(si.context_directory)
      assert_equal(directory_path, si.source)
      assert_equal(:directory, si.source_type)
      assert_equal(directory_path, si.source_path)
      assert_nil(si.source_proc)
      assert_equal(git_remote, si.git_remote)
      assert_equal(git_directory_path, si.git_path)
      assert_equal(git_commit, si.git_commit)
      assert_equal("git(remote=#{git_remote} path=#{git_directory_path} commit=#{git_commit})",
                   si.source_name)
    end

    it "errors when attempting to create a file system root with a nonexistent path" do
      assert_raises(Toys::LoaderError) do
        Toys::SourceInfo.create_path_root(bad_path, priority,
                                          data_dir_name: data_dir_name,
                                          lib_dir_name: lib_dir_name)
      end
    end
  end

  describe "#relative_child" do
    it "creates a relative child of a file system root" do
      parent = Toys::SourceInfo.create_path_root(directory_path, priority,
                                                 context_directory: :parent,
                                                 data_dir_name: data_dir_name,
                                                 lib_dir_name: lib_dir_name)
      si = parent.relative_child(".toys.rb")
      assert_equal(parent, si.parent)
      assert_equal(parent, si.root)
      assert_equal(priority, si.priority)
      assert_equal(lookup_cases_dir, si.context_directory)
      assert_equal(file_path, si.source)
      assert_equal(:file, si.source_type)
      assert_equal(file_path, si.source_path)
      assert_nil(si.source_proc)
      assert_nil(si.git_remote)
      assert_nil(si.git_path)
      assert_nil(si.git_commit)
      assert_equal(file_path, si.source_name)
    end

    it "creates a relative child of a git root" do
      parent = Toys::SourceInfo.create_git_root(git_remote, git_directory_path, git_commit,
                                                directory_path, priority,
                                                data_dir_name: data_dir_name,
                                                lib_dir_name: lib_dir_name)
      si = parent.relative_child(".toys.rb")
      assert_equal(parent, si.parent)
      assert_equal(parent, si.root)
      assert_equal(priority, si.priority)
      assert_nil(si.context_directory)
      assert_equal(file_path, si.source)
      assert_equal(:file, si.source_type)
      assert_equal(file_path, si.source_path)
      assert_nil(si.source_proc)
      assert_equal(git_remote, si.git_remote)
      assert_equal(git_file_path, si.git_path)
      assert_equal(git_commit, si.git_commit)
      assert_equal("git(remote=#{git_remote} path=#{git_file_path} commit=#{git_commit})",
                   si.source_name)
    end

    it "errors when attempting to create a relative child of a file" do
      parent = Toys::SourceInfo.create_path_root(file_path, priority,
                                                 data_dir_name: data_dir_name,
                                                 lib_dir_name: lib_dir_name)
      assert_raises(Toys::LoaderError) do
        parent.relative_child(".toys.rb")
      end
    end

    it "errors when attempting to create a relative child of a proc" do
      parent = Toys::SourceInfo.create_proc_root(my_proc, priority,
                                                 source_name: custom_source_name,
                                                 data_dir_name: data_dir_name,
                                                 lib_dir_name: lib_dir_name)
      assert_raises(Toys::LoaderError) do
        parent.relative_child(".toys.rb")
      end
    end
  end

  describe "#absolute_child" do
    it "creates an absolute child of a file system root" do
      parent = Toys::SourceInfo.create_path_root(path_with_data, priority,
                                                 context_directory: lookup_cases_dir,
                                                 data_dir_name: data_dir_name,
                                                 lib_dir_name: lib_dir_name)
      si = parent.absolute_child(file_path)
      assert_equal(parent, si.parent)
      assert_equal(parent, si.root)
      assert_equal(priority, si.priority)
      assert_equal(lookup_cases_dir, si.context_directory)
      assert_equal(file_path, si.source)
      assert_equal(:file, si.source_type)
      assert_equal(file_path, si.source_path)
      assert_nil(si.source_proc)
      assert_nil(si.git_remote)
      assert_nil(si.git_path)
      assert_nil(si.git_commit)
      assert_equal(file_path, si.source_name)
    end

    it "creates an absolute child of a proc root" do
      parent = Toys::SourceInfo.create_proc_root(my_proc, priority,
                                                 source_name: custom_source_name,
                                                 data_dir_name: data_dir_name,
                                                 lib_dir_name: lib_dir_name)
      si = parent.absolute_child(file_path)
      assert_equal(parent, si.parent)
      assert_equal(parent, si.root)
      assert_equal(priority, si.priority)
      assert_nil(si.context_directory)
      assert_equal(file_path, si.source)
      assert_equal(:file, si.source_type)
      assert_equal(file_path, si.source_path)
      assert_nil(si.source_proc)
      assert_nil(si.git_remote)
      assert_nil(si.git_path)
      assert_nil(si.git_commit)
      assert_equal(file_path, si.source_name)
    end
  end

  describe "#git_child" do
    it "creates a git child of a file system root" do
      parent = Toys::SourceInfo.create_path_root(path_with_data, priority,
                                                 context_directory: lookup_cases_dir,
                                                 data_dir_name: data_dir_name,
                                                 lib_dir_name: lib_dir_name)
      si = parent.git_child(git_remote, git_directory_path, git_commit, directory_path)
      assert_equal(parent, si.parent)
      assert_equal(parent, si.root)
      assert_equal(priority, si.priority)
      assert_equal(lookup_cases_dir, si.context_directory)
      assert_equal(directory_path, si.source)
      assert_equal(:directory, si.source_type)
      assert_equal(directory_path, si.source_path)
      assert_nil(si.source_proc)
      assert_equal(git_remote, si.git_remote)
      assert_equal(git_directory_path, si.git_path)
      assert_equal(git_commit, si.git_commit)
      assert_equal("git(remote=#{git_remote} path=#{git_directory_path} commit=#{git_commit})",
                   si.source_name)
    end

    it "creates a git child of a git root" do
      parent = Toys::SourceInfo.create_git_root(git_remote, git_path_with_data, git_commit,
                                                path_with_data, priority,
                                                data_dir_name: data_dir_name,
                                                lib_dir_name: lib_dir_name)
      si = parent.git_child(git_remote, git_directory_path, git_commit, directory_path)
      assert_equal(parent, si.parent)
      assert_equal(parent, si.root)
      assert_equal(priority, si.priority)
      assert_nil(si.context_directory)
      assert_equal(directory_path, si.source)
      assert_equal(:directory, si.source_type)
      assert_equal(directory_path, si.source_path)
      assert_nil(si.source_proc)
      assert_equal(git_remote, si.git_remote)
      assert_equal(git_directory_path, si.git_path)
      assert_equal(git_commit, si.git_commit)
      assert_equal("git(remote=#{git_remote} path=#{git_directory_path} commit=#{git_commit})",
                   si.source_name)
    end

    it "creates a git child of a proc root" do
      parent = Toys::SourceInfo.create_proc_root(my_proc, priority,
                                                 source_name: custom_source_name,
                                                 data_dir_name: data_dir_name,
                                                 lib_dir_name: lib_dir_name)
      si = parent.git_child(git_remote, git_directory_path, git_commit, directory_path)
      assert_equal(parent, si.parent)
      assert_equal(parent, si.root)
      assert_equal(priority, si.priority)
      assert_nil(si.context_directory)
      assert_equal(directory_path, si.source)
      assert_equal(:directory, si.source_type)
      assert_equal(directory_path, si.source_path)
      assert_nil(si.source_proc)
      assert_equal(git_remote, si.git_remote)
      assert_equal(git_directory_path, si.git_path)
      assert_equal(git_commit, si.git_commit)
      assert_equal("git(remote=#{git_remote} path=#{git_directory_path} commit=#{git_commit})",
                   si.source_name)
    end
  end

  describe "#proc_child" do
    it "creates a proc child of a file system root" do
      parent = Toys::SourceInfo.create_path_root(file_path, priority,
                                                 context_directory: :parent,
                                                 data_dir_name: data_dir_name,
                                                 lib_dir_name: lib_dir_name)
      si = parent.proc_child(my_proc)
      assert_equal(parent, si.parent)
      assert_equal(parent, si.root)
      assert_equal(priority, si.priority)
      assert_equal(directory_path, si.context_directory)
      assert_equal(my_proc, si.source)
      assert_equal(:proc, si.source_type)
      assert_equal(file_path, si.source_path)
      assert_equal(my_proc, si.source_proc)
      assert_nil(si.git_remote)
      assert_nil(si.git_path)
      assert_nil(si.git_commit)
      assert_equal(file_path, si.source_name)
    end

    it "creates a proc child of a git root" do
      parent = Toys::SourceInfo.create_git_root(git_remote, git_file_path, git_commit,
                                                file_path, priority,
                                                data_dir_name: data_dir_name,
                                                lib_dir_name: lib_dir_name)
      si = parent.proc_child(my_proc)
      assert_equal(parent, si.parent)
      assert_equal(parent, si.root)
      assert_equal(priority, si.priority)
      assert_nil(si.context_directory)
      assert_equal(my_proc, si.source)
      assert_equal(:proc, si.source_type)
      assert_equal(file_path, si.source_path)
      assert_equal(my_proc, si.source_proc)
      assert_equal(git_remote, si.git_remote)
      assert_equal(git_file_path, si.git_path)
      assert_equal(git_commit, si.git_commit)
      assert_equal("git(remote=#{git_remote} path=#{git_file_path} commit=#{git_commit})",
                   si.source_name)
    end

    it "creates a proc child of a proc root" do
      parent = Toys::SourceInfo.create_proc_root(my_proc, priority,
                                                 source_name: custom_source_name,
                                                 data_dir_name: data_dir_name,
                                                 lib_dir_name: lib_dir_name)
      si = parent.proc_child(my_proc2)
      assert_equal(parent, si.parent)
      assert_equal(parent, si.root)
      assert_equal(priority, si.priority)
      assert_nil(si.context_directory)
      assert_equal(my_proc2, si.source)
      assert_equal(:proc, si.source_type)
      assert_nil(si.source_path)
      assert_equal(my_proc2, si.source_proc)
      assert_nil(si.git_remote)
      assert_nil(si.git_path)
      assert_nil(si.git_commit)
      assert_equal(custom_source_name, si.source_name)
    end
  end

  it "looks up data from a root" do
    si = Toys::SourceInfo.create_path_root(path_with_data, priority,
                                           data_dir_name: data_dir_name,
                                           lib_dir_name: lib_dir_name)
    path = si.find_data("foo/root.txt")
    assert_equal(File.join(path_with_data, data_dir_name, "foo", "root.txt"), path)
  end
end
