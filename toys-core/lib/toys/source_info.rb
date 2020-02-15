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
                   source_name, data_dir, lib_dir)
      @parent = parent
      @context_directory = context_directory
      @source_type = source_type
      @source = source_type == :proc ? source_proc : source_path
      @source_path = source_path
      @source_proc = source_proc
      @source_name = source_name
      @data_dir = data_dir
      @lib_dir = lib_dir
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
    def relative_child(filename, data_dir_name, lib_dir_name)
      raise "no parent path for relative_child" unless source_path
      child_path = ::File.join(source_path, filename)
      child_path, type = SourceInfo.check_path(child_path, true)
      return nil unless child_path
      data_dir = SourceInfo.find_special_dir(type, child_path, data_dir_name)
      lib_dir = SourceInfo.find_special_dir(type, child_path, lib_dir_name)
      SourceInfo.new(self, context_directory, type, child_path, source_proc, child_path,
                     data_dir, lib_dir)
    end

    ##
    # Create a child SourceInfo with an absolute path.
    # @private
    #
    def absolute_child(child_path)
      child_path, type = SourceInfo.check_path(child_path, false)
      SourceInfo.new(self, context_directory, type, child_path, source_proc, child_path, nil, nil)
    end

    ##
    # Create a proc child SourceInfo
    # @private
    #
    def proc_child(child_proc, source_name = nil)
      source_name ||= self.source_name
      SourceInfo.new(self, context_directory, :proc, source_path, child_proc, source_name, nil, nil)
    end

    ##
    # Create a root source info for a file path.
    # @private
    #
    def self.create_path_root(source_path)
      source_path, type = check_path(source_path, false)
      context_directory = ::File.dirname(source_path)
      new(nil, context_directory, type, source_path, nil, source_path, nil, nil)
    end

    ##
    # Create a root source info for a proc.
    # @private
    #
    def self.create_proc_root(source_proc, source_name)
      new(nil, nil, :proc, nil, source_proc, source_name, nil, nil)
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

    ##
    # Determine the data directory path, if any.
    # @private
    #
    def self.find_special_dir(type, source_path, dir_name)
      return nil if source_path.nil? || dir_name.nil?
      source_path = ::File.dirname(source_path) if type == :file
      dir = ::File.join(source_path, dir_name)
      dir if ::File.directory?(dir) && ::File.readable?(dir)
    end
  end
end
