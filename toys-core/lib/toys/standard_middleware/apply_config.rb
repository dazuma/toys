# frozen_string_literal: true

# Copyright 2020 Daniel Azuma
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
  module StandardMiddleware
    ##
    # A middleware that applies the given block to all tool configurations.
    #
    class ApplyConfig
      ##
      # Create an ApplyConfig middleware
      #
      # @param parent_source [Toys::SourceInfo] The SourceInfo corresponding to
      #     the source where this block is provided, or `nil` (the default) if
      #     the block does not come from a Toys file.
      # @param source_name [String] A user-visible name for the source, or
      #     `nil` to use the default.
      # @param block [Proc] The configuration to apply.
      #
      def initialize(parent_source: nil, source_name: nil, &block)
        @source_info =
          if parent_source
            parent_source.proc_child(block, source_name)
          else
            SourceInfo.create_proc_root(block, source_name)
          end
        @block = block
      end

      ##
      # Appends the configuration block.
      # @private
      #
      def config(tool, _loader)
        tool_class = tool.tool_class
        DSL::Tool.prepare(tool_class, nil, @source_info) do
          tool_class.class_eval(&@block)
        end
        yield
      end
    end
  end
end
