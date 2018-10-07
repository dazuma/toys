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

module Toys
  module Definition
    ##
    # Finds data files.
    #
    class DataFinder
      ##
      # Create a new finder.
      #
      # @param [String,nil] data_name Name of the data directory, or nil if
      #     data directories are disabled.
      # @param [Toys::Definition::DataFinder,nil] parent The parent, or nil if
      #     this is the root.
      # @param [String,nil] directory The data directory, or nil for none.
      # @private
      #
      def initialize(data_name, parent, directory)
        @data_name = data_name
        @parent = parent
        @directory = directory
      end

      ##
      # Create a new finder for the given directory.
      #
      # @param [String] directory Toys directory path
      # @return [Toys::Definition::DataFinder] The finder
      #
      def finder_for(directory)
        return self if @data_name.nil?
        directory = ::File.join(directory, @data_name)
        return self unless ::File.directory?(directory)
        DataFinder.new(@data_name, self, directory)
      end

      ##
      # Return the absolute path to the given data file or directory.
      #
      # @param [String] path The relative path to find
      # @param [nil,:file,:directory] type Type of file system object to find,
      #     or nil to return any type.
      # @return [String,nil] Absolute path of the result, or nil if not found.
      #
      def find_data(path, type: nil)
        return nil if @directory.nil?
        full_path = ::File.join(@directory, path)
        case type
        when :file
          return full_path if ::File.file?(full_path)
        when :directory
          return full_path if ::File.directory?(full_path)
        else
          return full_path if ::File.readable?(full_path)
        end
        @parent.find_data(path, type: type)
      end

      ##
      # Create an empty finder.
      #
      # @param [String,nil] data_name Name of the data directory, or nil if
      #     data directories are disabled.
      # @return [Toys::Definition::DataFinder]
      #
      def self.create_empty(data_name)
        new(data_name, nil, nil)
      end

      ##
      # A default empty finder.
      #
      # @return [Toys::Definition::DataFinder]
      #
      EMPTY = create_empty(nil)
    end
  end
end
