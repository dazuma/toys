# frozen_string_literal: true

module Toys
  ##
  # Information about source toys directories and files.
  #
  class SourceInfo
    ##
    # Create a SourceInfo.
    # @private
    #
    def initialize(parent, context_directory, source_type, source_path, source_proc,
                   source_name, data_dir_name, lib_dir_name)
      @parent = parent
      @context_directory = context_directory
      @source_type = source_type
      @source = source_type == :proc ? source_proc : source_path
      @source_path = source_path
      @source_proc = source_proc
      @source_name = source_name
      @data_dir_name = data_dir_name
      @lib_dir_name = lib_dir_name
      @data_dir = find_special_dir(data_dir_name)
      @lib_dir = find_special_dir(lib_dir_name)
    end

    ##
    # The parent of this SourceInfo.
    #
    # @return [Toys::SourceInfo] The parent.
    # @return [nil] if this SourceInfo is the root.
    #
    attr_reader :parent

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
    # Create a child SourceInfo relative to the parent path.
    # @private
    #
    def relative_child(filename)
      raise "relative_child is valid only on a directory source" unless source_type == :directory
      child_path = ::File.join(source_path, filename)
      child_path, type = SourceInfo.check_path(child_path, true)
      return nil unless child_path
      SourceInfo.new(self, context_directory, type, child_path, nil, child_path,
                     @data_dir_name, @lib_dir_name)
    end

    ##
    # Create a child SourceInfo with an absolute path.
    # @private
    #
    def absolute_child(child_path)
      child_path, type = SourceInfo.check_path(child_path, false)
      SourceInfo.new(self, context_directory, type, child_path, nil, child_path,
                     @data_dir_name, @lib_dir_name)
    end

    ##
    # Create a proc child SourceInfo
    # @private
    #
    def proc_child(child_proc, source_name = nil)
      source_name ||= self.source_name
      SourceInfo.new(self, context_directory, :proc, source_path, child_proc, source_name,
                     @data_dir_name, @lib_dir_name)
    end

    ##
    # Create a root source info for a file path.
    # @private
    #
    def self.create_path_root(source_path, data_dir_name, lib_dir_name)
      source_path, type = check_path(source_path, false)
      context_directory = ::File.dirname(source_path)
      new(nil, context_directory, type, source_path, nil, source_path, data_dir_name, lib_dir_name)
    end

    ##
    # Create a root source info for a proc.
    # @private
    #
    def self.create_proc_root(source_proc, source_name, data_dir_name, lib_dir_name)
      new(nil, nil, :proc, nil, source_proc, source_name, data_dir_name, lib_dir_name)
    end

    ##
    # Check a path and determine the canonical path and type.
    # @private
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
