# frozen_string_literal: true

module Toys
  ##
  # Information about the source of a tool, such as the file, git repository,
  # or block that defined it.
  #
  class SourceInfo
    ##
    # The parent of this SourceInfo.
    #
    # @return [Toys::SourceInfo] The parent.
    # @return [nil] if this SourceInfo is the root.
    #
    attr_reader :parent

    ##
    # The root ancestor of this SourceInfo.
    #
    # @return [Toys::SourceInfo] The root ancestor.
    #
    attr_reader :root

    ##
    # The priority of tools defined by this source. Higher values indicate a
    # higher priority. Lower priority values could be negative.
    #
    # @return [Integer] The priority.
    #
    attr_reader :priority

    ##
    # The context directory path (normally the directory containing the
    # toplevel toys file or directory).
    #
    # @return [String] The context directory path.
    # @return [nil] if there is no context directory (perhaps because the tool
    #     is being defined from a block)
    #
    attr_reader :context_directory

    ##
    # The source, which may be a path or a proc.
    #
    # @return [String] Path to the source file or directory.
    # @return [Proc] The block serving as the source.
    #
    attr_reader :source

    ##
    # Return the type of source.
    #
    # @return [:file,:directory,:proc]
    #
    attr_reader :source_type

    ##
    # The path of the current source file or directory.
    #
    # @return [String] The source path
    # @return [nil] if this source has no file system path.
    #
    attr_reader :source_path

    ##
    # The source proc.
    #
    # @return [Proc] The source proc
    # @return [nil] if this source has no proc.
    #
    attr_reader :source_proc

    ##
    # The git remote.
    #
    # @return [String] The git remote
    # @return [nil] if this source is not fron git.
    #
    attr_reader :git_remote

    ##
    # The git path.
    #
    # @return [String] The git path. This could be the empty string.
    # @return [nil] if this source is not fron git.
    #
    attr_reader :git_path

    ##
    # The git commit.
    #
    # @return [String] The git commit.
    # @return [nil] if this source is not fron git.
    #
    attr_reader :git_commit

    ##
    # The user-visible name of this source.
    #
    # @return [String]
    #
    attr_reader :source_name
    alias to_s source_name

    ##
    # Locate the given data file or directory and return an absolute path.
    #
    # @param path [String] The relative path to find
    # @param type [nil,:file,:directory] Type of file system object to find,
    #     or nil (the default) to return any type.
    # @return [String] Absolute path of the resulting data.
    # @return [nil] if the data was not found.
    #
    def find_data(path, type: nil)
      if @data_dir
        full_path = ::File.join(@data_dir, path)
        case type
        when :file
          return full_path if ::File.file?(full_path)
        when :directory
          return full_path if ::File.directory?(full_path)
        else
          return full_path if ::File.readable?(full_path)
        end
      end
      parent&.find_data(path, type: type)
    end

    ##
    # Apply all lib paths in order from high to low priority
    #
    # @return [self]
    #
    def apply_lib_paths
      parent&.apply_lib_paths
      $LOAD_PATH.unshift(@lib_dir) if @lib_dir && !$LOAD_PATH.include?(@lib_dir)
      self
    end

    ##
    # Create a SourceInfo.
    #
    # @private This interface is internal and subject to change without warning.
    #
    def initialize(parent, priority, context_directory, source_type, source_path, source_proc,
                   git_remote, git_path, git_commit, source_name, data_dir_name, lib_dir_name)
      @parent = parent
      @root = parent&.root || self
      @priority = priority
      @context_directory = context_directory
      @source_type = source_type
      @source = source_type == :proc ? source_proc : source_path
      @source_path = source_path
      @source_proc = source_proc
      @git_remote = git_remote
      @git_path = git_path
      @git_commit = git_commit
      @source_name = source_name
      @data_dir_name = data_dir_name
      @lib_dir_name = lib_dir_name
      @data_dir = find_special_dir(data_dir_name)
      @lib_dir = find_special_dir(lib_dir_name)
    end

    ##
    # Create a child SourceInfo relative to the parent path.
    #
    # @private This interface is internal and subject to change without warning.
    #
    def relative_child(filename, source_name: nil)
      unless source_type == :directory
        raise LoaderError, "relative_child is valid only on a directory source"
      end
      child_path = ::File.join(source_path, filename)
      child_path, type = SourceInfo.check_path(child_path, true)
      return nil unless child_path
      child_git_path = ::File.join(git_path, filename) if git_path
      source_name ||=
        if git_path
          "git(remote=#{git_remote} path=#{child_git_path} commit=#{git_commit})"
        else
          child_path
        end
      SourceInfo.new(self, priority, context_directory, type, child_path, nil,
                     git_remote, child_git_path, git_commit,
                     source_name, @data_dir_name, @lib_dir_name)
    end

    ##
    # Create a child SourceInfo with an absolute path.
    #
    # @private This interface is internal and subject to change without warning.
    #
    def absolute_child(child_path, source_name: nil)
      child_path, type = SourceInfo.check_path(child_path, false)
      source_name ||= child_path
      SourceInfo.new(self, priority, context_directory, type, child_path, nil, nil, nil, nil,
                     source_name, @data_dir_name, @lib_dir_name)
    end

    ##
    # Create a child SourceInfo with a git source.
    #
    # @private This interface is internal and subject to change without warning.
    #
    def git_child(child_git_remote, child_git_path, child_git_commit, child_path,
                  source_name: nil)
      child_path, type = SourceInfo.check_path(child_path, false)
      source_name ||=
        "git(remote=#{child_git_remote} path=#{child_git_path} commit=#{child_git_commit})"
      SourceInfo.new(self, priority, context_directory, type, child_path, nil,
                     child_git_remote, child_git_path, child_git_commit,
                     source_name, @data_dir_name, @lib_dir_name)
    end

    ##
    # Create a proc child SourceInfo
    #
    # @private This interface is internal and subject to change without warning.
    #
    def proc_child(child_proc, source_name: nil)
      source_name ||= self.source_name
      SourceInfo.new(self, priority, context_directory, :proc, source_path, child_proc,
                     git_remote, git_path, git_commit,
                     source_name, @data_dir_name, @lib_dir_name)
    end

    ##
    # Create a root source info for a file path.
    #
    # @private This interface is internal and subject to change without warning.
    #
    def self.create_path_root(source_path, priority,
                              context_directory: nil,
                              data_dir_name: nil,
                              lib_dir_name: nil,
                              source_name: nil)
      source_path, type = check_path(source_path, false)
      case context_directory
      when :parent
        context_directory = ::File.dirname(source_path)
      when :path
        context_directory = source_path
      end
      source_name ||= source_path
      new(nil, priority, context_directory, type, source_path, nil, nil, nil, nil,
          source_name, data_dir_name, lib_dir_name)
    end

    ##
    # Create a root source info for a cached git repo.
    #
    # @private This interface is internal and subject to change without warning.
    #
    def self.create_git_root(git_remote, git_path, git_commit, source_path, priority,
                             context_directory: nil,
                             data_dir_name: nil,
                             lib_dir_name: nil,
                             source_name: nil)
      source_path, type = check_path(source_path, false)
      source_name ||= "git(remote=#{git_remote} path=#{git_path} commit=#{git_commit})"
      new(nil, priority, context_directory, type, source_path, nil, git_remote,
          git_path, git_commit, source_name, data_dir_name, lib_dir_name)
    end

    ##
    # Create a root source info for a proc.
    #
    # @private This interface is internal and subject to change without warning.
    #
    def self.create_proc_root(source_proc, priority,
                              context_directory: nil,
                              data_dir_name: nil,
                              lib_dir_name: nil,
                              source_name: nil)
      source_name ||= "(code block #{source_proc.object_id})"
      new(nil, priority, context_directory, :proc, nil, source_proc, nil, nil,
          nil, source_name, data_dir_name, lib_dir_name)
    end

    ##
    # Check a path and determine the canonical path and type.
    #
    # @private This interface is internal and subject to change without warning.
    #
    def self.check_path(path, lenient)
      path = ::File.expand_path(path)
      unless ::File.readable?(path)
        raise LoaderError, "Cannot read: #{path}" unless lenient
        return [nil, nil]
      end
      if ::File.file?(path)
        unless ::File.extname(path) == ".rb"
          raise LoaderError, "File is not a ruby file: #{path}" unless lenient
          return [nil, nil]
        end
        [path, :file]
      elsif ::File.directory?(path)
        [path, :directory]
      else
        raise LoaderError, "Unknown type: #{path}" unless lenient
        [nil, nil]
      end
    end

    private

    def find_special_dir(dir_name)
      return nil if @source_type != :directory || dir_name.nil?
      dir = ::File.join(@source_path, dir_name)
      dir if ::File.directory?(dir) && ::File.readable?(dir)
    end
  end
end
