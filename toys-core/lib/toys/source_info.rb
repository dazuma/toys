# frozen_string_literal: true

module Toys
  ##
  # Information about the source of a tool, such as the file, git repository,
  # or block that defined it.
  #
  # This object represents a source of tool information and definitions. Such a
  # source could include:
  #
  # * A toys directory
  # * A single toys file
  # * A file or directory loaded from git
  # * A file or directory loaded from a gem
  # * A config block passed directly to the CLI
  # * A tool block within a toys file
  #
  # The SourceInfo provides information such as the tool's context directory,
  # and locates data and lib directories appropriate to the tool. It also
  # locates the tool's source code so it can be reported when an error occurs.
  #
  # Each tool has a unique SourceInfo with all the information specific to that
  # tool. Additionally, SourceInfo objects are arranged in a containment
  # hierarchy. For example, a SourceInfo object representing a toys files could
  # have a parent representing a toys directory, and an object representing a
  # tool block could have a parent representing an enclosing block or a file.
  #
  # Child SourceInfo objects generally inherit some attributes of their parent.
  # For example, the `.toys` directory in a project directory defines the
  # context directory as that project directory. Then all tools defined under
  # that directory will share that context directory, so all SourceInfo objects
  # descending from that root will inherit that value (unless it's changed
  # explicitly).
  #
  # SourceInfo objects can be obtained in the DSL from
  # {Toys::DSL::Tool#source_info} or at runtime by getting the
  # {Toys::Context::Key::TOOL_SOURCE} key. However, they are created internally
  # by the Loader and should not be created manually.
  #
  class SourceInfo
    ##
    # The parent of this SourceInfo.
    #
    # @return [Toys::SourceInfo] The parent.
    # @return [nil] if this SourceInfo is a root.
    #
    attr_reader :parent

    ##
    # The root ancestor of this SourceInfo. This generally represents a source
    # that was added directly to a CLI in code.
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
    # This is not affected by setting a custom context directory for a tool.
    #
    # @return [String] The context directory path.
    # @return [nil] if there is no context directory (perhaps because the root
    #     source was a block)
    #
    attr_reader :context_directory

    ##
    # The source, which may be a path or a proc depending on the {#source_type}.
    #
    # @return [String] Path to the source file or directory.
    # @return [Proc] The block serving as the source.
    #
    attr_reader :source

    ##
    # The type of source. This could be:
    #
    # * `:file`, representing a single toys file. The {#source} will be the
    #   filesystem path to that file.
    # * `:directory`, representing a toys directory. The {#source} will be the
    #   filesystem path to that directory.
    # * `:proc`, representing a proc, which could be a toplevel block added
    #   directly to a CLI, a `tool` block within a toys file, or a block within
    #   another block. The {#source} will be the proc itself.
    #
    # @return [:file,:directory,:proc]
    #
    attr_reader :source_type

    ##
    # The path of the current source file or directory.
    #
    # This could be set even if {#source_type} is `:proc`, if that proc is
    # defined within a toys file. The only time this is not set is if the
    # source is added directly to a CLI in a code block.
    #
    # @return [String] The source path
    # @return [nil] if this source has no file system path.
    #
    attr_reader :source_path

    ##
    # The source proc. This is set if {#source_type} is `:proc`.
    #
    # @return [Proc] The source proc
    # @return [nil] if this source has no proc.
    #
    attr_reader :source_proc

    ##
    # The git remote. This is set if the source, or one of its ancestors, comes
    # from git.
    #
    # @return [String] The git remote
    # @return [nil] if this source is not fron git.
    #
    attr_reader :git_remote

    ##
    # The git path. This is set if the source, or one of its ancestors, comes
    # from git.
    #
    # @return [String] The git path. This could be the empty string.
    # @return [nil] if this source is not fron git.
    #
    attr_reader :git_path

    ##
    # The git commit. This is set if the source, or one of its ancestors, comes
    # from git.
    #
    # @return [String] The git commit.
    # @return [nil] if this source is not fron git.
    #
    attr_reader :git_commit

    ##
    # The gem name. This is set if the source, or one of its ancestors, comes
    # from a gem.
    #
    # @return [String] The gem name.
    # @return [nil] if this source is not from a gem.
    #
    attr_reader :gem_name

    ##
    # The gem version. This is set if the source, or one of its ancestors,
    # comes from a gem.
    #
    # @return [Gem::Version] The gem version.
    # @return [nil] if this source is not from a gem.
    #
    attr_reader :gem_version

    ##
    # The path within the gem, including the toys root directory in the gem.
    #
    # @return [String] The path.
    # @return [nil] if this source is not from a gem.
    #
    attr_reader :gem_path

    ##
    # A user-visible name of this source.
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
    def initialize(parent, priority, context_directory,
                   source_type, source_path, source_proc,
                   git_remote, git_path, git_commit, gem_name, gem_version, gem_path,
                   source_name, data_dir_name, lib_dir_name)
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
      @gem_name = gem_name
      @gem_version = gem_version
      @gem_path = gem_path
      @source_name = source_name || default_source_name
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
      child_path, type = SourceInfo.check_path(::File.join(source_path, filename), true)
      return nil unless child_path
      child_git_path = git_path.empty? ? filename : ::File.join(git_path, filename) if git_path
      child_gem_path = gem_path.empty? ? filename : ::File.join(gem_path, filename) if gem_path
      SourceInfo.new(self, priority, context_directory, type, child_path, nil,
                     git_remote, child_git_path, git_commit, gem_name, gem_version, child_gem_path,
                     source_name, @data_dir_name, @lib_dir_name)
    end

    ##
    # Create a child SourceInfo with an absolute path.
    #
    # @private This interface is internal and subject to change without warning.
    #
    def absolute_child(child_path, source_name: nil)
      child_path, type = SourceInfo.check_path(child_path, false)
      SourceInfo.new(self, priority, context_directory, type, child_path, nil,
                     nil, nil, nil, nil, nil, nil,
                     source_name, @data_dir_name, @lib_dir_name)
    end

    ##
    # Create a child SourceInfo with a git source.
    #
    # @private This interface is internal and subject to change without warning.
    #
    def git_child(child_git_remote, child_git_path, child_git_commit, child_path, source_name: nil)
      child_path, type = SourceInfo.check_path(child_path, false)
      SourceInfo.new(self, priority, context_directory, type, child_path, nil,
                     child_git_remote, child_git_path, child_git_commit, nil, nil, nil,
                     source_name, @data_dir_name, @lib_dir_name)
    end

    ##
    # Create a child SourceInfo with a gem source.
    #
    # @private This interface is internal and subject to change without warning.
    #
    def gem_child(child_gem_name, child_gem_version, child_gem_path, child_path, source_name: nil)
      child_path, type = SourceInfo.check_path(child_path, false)
      SourceInfo.new(self, priority, context_directory, type, child_path, nil,
                     nil, nil, nil, child_gem_name, child_gem_version, child_gem_path,
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
                     git_remote, git_path, git_commit, gem_name, gem_version, gem_path,
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
      new(nil, priority, context_directory, type, source_path, nil,
          nil, nil, nil, nil, nil, nil,
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
      new(nil, priority, context_directory, type, source_path, nil,
          git_remote, git_path, git_commit, nil, nil, nil,
          source_name, data_dir_name, lib_dir_name)
    end

    ##
    # Create a root source info for a loaded gem.
    #
    # @private This interface is internal and subject to change without warning.
    #
    def self.create_gem_root(gem_name, gem_version, gem_path, source_path, priority,
                             context_directory: nil,
                             data_dir_name: nil,
                             lib_dir_name: nil,
                             source_name: nil)
      source_path, type = check_path(source_path, false)
      new(nil, priority, context_directory, type, source_path, nil,
          nil, nil, nil, gem_name, gem_version, gem_path,
          source_name, data_dir_name, lib_dir_name)
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
      new(nil, priority, context_directory, :proc, nil, source_proc,
          nil, nil, nil, nil, nil, nil,
          source_name, data_dir_name, lib_dir_name)
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

    def default_source_name
      if @git_remote
        "git(remote=#{@git_remote} path=#{@git_path} commit=#{@git_commit})"
      elsif @gem_name
        "gem(name=#{@gem_name} version=#{@gem_version} path=#{@gem_path})"
      elsif @source_type == :proc
        "(code block #{@source_proc.object_id})"
      else
        @source_path
      end
    end

    def find_special_dir(dir_name)
      return nil if @source_type != :directory || dir_name.nil?
      dir = ::File.join(@source_path, dir_name)
      dir if ::File.directory?(dir) && ::File.readable?(dir)
    end
  end
end
