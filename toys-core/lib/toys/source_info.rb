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
    def initialize(parent, context_directory, source, source_type, source_name, data_dir_name)
      @parent = parent
      @context_directory = context_directory
      @source = source
      @source_type = source_type
      @source_path = source if source.is_a?(::String)
      @source_proc = source if source.is_a?(::Proc)
      @source_name = source_name
      @data_dir =
        if data_dir_name && @source_path
          dir = ::File.join(::File.dirname(@source_path), data_dir_name)
          dir if ::File.directory?(dir) && ::File.readable?(dir)
        end
    end

    ##
    # Return the parent SourceInfo, or nil if this is the root.
    # @return [Toys::SourceInfo,nil]
    #
    attr_reader :parent

    ##
    # Return the context directory path (normally the directory containing
    # the toplevel toys file or directory). May return nil if there is no
    # context (e.g. the tool is being defined from a block).
    # @return [String,nil]
    #
    attr_reader :context_directory

    ##
    # Return the source, which may be a path or a proc.
    # @return [String,Proc]
    #
    attr_reader :source

    ##
    # Return the type of source.
    # @return [:file,:directory,:proc]
    #
    attr_reader :source_type

    ##
    # Return the path of the current source file or directory, or nil if this
    # source is not a file system path.
    # @return [String,nil]
    #
    attr_reader :source_path

    ##
    # Return the source proc, or nil if this source is not a proc.
    # @return [Proc,nil]
    #
    attr_reader :source_proc

    ##
    # Return the user-visible name of this source.
    # @return [String]
    #
    attr_reader :source_name
    alias to_s source_name

    ##
    # Return the absolute path to the given data file or directory.
    #
    # @param path [String] The relative path to find
    # @param type [nil,:file,:directory] Type of file system object to find,
    #     or nil (the default) to return any type.
    # @return [String,nil] Absolute path of the result, or nil if not found.
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
    # Create a child SourceInfo relative to the parent path.
    # @private
    #
    def relative_child(filename, data_dir_name)
      raise "Cannot create relative child of a proc" unless source_path
      child_path = ::File.join(source_path, filename)
      child_path, type = SourceInfo.check_path(child_path, true)
      return nil unless child_path
      SourceInfo.new(self, context_directory, child_path, type, child_path, data_dir_name)
    end

    ##
    # Create a child SourceInfo with an absolute path.
    # @private
    #
    def absolute_child(child_path)
      child_path, type = SourceInfo.check_path(child_path, false)
      SourceInfo.new(self, context_directory, child_path, type, child_path, nil)
    end

    ##
    # Create a root source info for a file path.
    # @private
    #
    def self.create_path_root(source_path)
      source_path, type = check_path(source_path, false)
      context_directory = ::File.dirname(source_path)
      new(nil, context_directory, source_path, type, source_path, nil)
    end

    ##
    # Create a root source info for a proc.
    # @private
    #
    def self.create_proc_root(source_proc, source_name)
      new(nil, nil, source_proc, :proc, source_name, nil)
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
  end
end
