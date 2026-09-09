# frozen_string_literal: true

module Toys
  module StandardMiddleware
    ##
    # A middleware that applies the given block to all tool configurations.
    #
    class ApplyConfig
      ##
      # Create an ApplyConfig middleware.
      #
      # This middleware works in one of two modes:
      #
      #  1. Tied to a provided `parent_source`. This is generally used when
      #     the middleware is invoked during tool loading, e.g. via the
      #     {Toys::DSL::Tool#subtool_apply} DSL directive. The block will be
      #     associated with a new "proc" source under the given parent, and
      #     will apply only to tools from the same source tree (i.e. the same
      #     priority.)
      #  2. Not tied to a source, i.e. the no `parent_source` provided. This is
      #     generally used when the middleware is installed globally in the
      #     loader. The block will be applied to _every_ tool, regardless of
      #     the tool's source, and will be associated with a separate "proc"
      #     source for every tool source tree (i.e. every priority).
      #
      # Your block cannot create or modify subtools of the tool being modified.
      # (This is because the same middleware could be expected to apply to that
      # subtool as well, and the semantics of the resulting recursion would be
      # messy and ambiguous.) Thus, within the block:
      #
      #  *  You cannot use the `tool` directive.
      #  *  You cannot create a `Toys::Tool` subclass.
      #  *  You cannot use a `subtool_apply` directive.
      #  *  You cannot pass the `as:` parameter to any `load` or related
      #     directive.
      #  *  You cannot use any `load` or related directive that references a
      #     directory. (You can, however, load a file directly, as long as it
      #     does not use the `as:` parameter, and the file's contents do not
      #     violate any of these rules.)
      #
      # @param parent_source [Toys::SourceInfo,nil] The SourceInfo corresponding
      #     to the source where this block is provided, to apply this block only
      #     to that source tree. Or, omit to apply this block to every tool
      #     regardless of source.
      # @param source_name [String] A user-visible name for the source, or
      #     `nil` to use the default.
      # @param block [Proc] The configuration to apply.
      #
      def initialize(parent_source: nil, source_name: nil, &block)
        @block = block
        if parent_source
          @source = parent_source.proc_child(block, source_name: source_name)
          @mutex = @sources_by_root = @source_name = nil
        else
          @source_name = source_name
          @sources_by_root = {}
          @mutex = ::Mutex.new
          @source = nil
        end
      end

      ##
      # Appends the configuration block.
      #
      # @private
      #
      def config(tool, loader)
        tool_class = tool.tool_class
        source = find_source(tool.source_root)
        if source
          DSL::Internal.setup_class_dsl(tool_class)
          # Remaining words are empty rather than nil: the block is evaluated
          # against a tool that has already been located, so any source it
          # loads is relevant now and must be evaluated inline rather than
          # deferred to the worklist.
          Loader::LoadState.prepare(tool_class, loader, tool.full_name, [], source) do
            tool_class.class_eval(&@block)
          end
        end
        yield
      end

      private

      def find_source(source_root)
        if @source
          @source.root == source_root ? @source : nil
        else
          @mutex.synchronize do
            @sources_by_root[source_root] ||= source_root.proc_child(@block, source_name: @source_name)
          end
        end
      end
    end
  end
end
