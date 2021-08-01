# frozen_string_literal: true

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
            parent_source.proc_child(block, source_name: source_name)
          else
            SourceInfo.create_proc_root(block, source_name: source_name)
          end
        @block = block
      end

      ##
      # Appends the configuration block.
      # @private
      #
      def config(tool, loader)
        tool_class = tool.tool_class
        DSL::Internal.prepare(tool_class, tool.full_name, tool.priority, nil, @source_info,
                              loader) do
          tool_class.class_eval(&@block)
        end
        yield
      end
    end
  end
end
