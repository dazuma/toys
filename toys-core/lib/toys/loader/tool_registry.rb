# frozen_string_literal: true

module Toys
  class Loader
    ##
    # A ToolRegistry is the collection of tool definitions from a Loader,
    # indexed by tool name. For each name it holds one definition per priority,
    # tracks which is the highest, and tracks which, if any, has been activated.
    # It is also the factory for {Toys::ToolDefinition} objects.
    #
    # Note this class is not thread-safe by itself, so access should be
    # protected by an external lock.
    #
    # @private This interface is internal and subject to change without warning.
    #
    class ToolRegistry
      ##
      # Create an empty ToolRegistry.
      #
      # @private This interface is internal and subject to change without warning.
      #
      # @param middleware_stack [Array<Toys::Middleware::Spec>] An array of
      #     middleware that will be used by default for all tools built by this
      #     registry.
      # @param middleware_lookup [Toys::ModuleLookup] A lookup for well-known
      #     middleware classes. Defaults to an empty lookup.
      #
      def initialize(middleware_stack: [], middleware_lookup: nil)
        @middleware_stack = Middleware.stack(middleware_stack)
        @middleware_lookup = middleware_lookup || ModuleLookup.new
        @entries = {}
        @roots_by_priority = {}
      end

      ##
      # Get a specific tool definition with the given name and priority.
      #
      # If a `tool_class` argument is provided, it is an assertion of the tool's
      # class. If the tool needs to be newly constructed, the given class will
      # be used. If the tool exists, and its class is not the same as the given
      # class, an error will be raised. (This could happen if the tool is being
      # defined using a Toys::Tool subclass, where it had already previously been
      # defined through some other means.)
      #
      # If `activate` is set to true, it is an assertion that the returned tool
      # is the active one, of the given priority or higher. Thus, if there is no
      # currently active tool, or the active tool has a lower priority than given,
      # the current priority tool is activated and returned. If the currently
      # active tool has a higher priority than given, *nil is returned*, i.e. you
      # cannot activate a lower-priority tool than what is already active.
      #
      # @private This interface is internal and subject to change without warning.
      #
      def get_tool(words, priority, activate: false, tool_class: nil)
        unless @roots_by_priority.key?(priority)
          raise ToolDefinitionError, "Unrecorded priority: #{priority}"
        end
        entry = entry_for(words, true)
        return nil if activate && entry.active_priority && entry.active_priority > priority
        existing_tool = entry[priority]
        if tool_class && existing_tool && existing_tool.tool_class != tool_class
          raise ToolDefinitionError, "Tool already defined for #{words.inspect}"
        end
        entry.ensure_tool(priority, activate) { build_tool(words, priority, tool_class) }
      end

      ##
      # Returns true if the given tool name currently has an entry in this
      # registry. Does not create one if not found.
      #
      # @private This interface is internal and subject to change without warning.
      #
      def tool_defined?(words)
        !entry_for(words, false).nil?
      end

      ##
      # Returns the current "best" definition for the given name, which is
      # either the active definition, or, if none, the current highest-priority
      # definition. Returns nil if the name has no definitions.
      #
      # @private This interface is internal and subject to change without warning.
      #
      def cur_definition(words)
        entry_for(words, false)&.cur_definition
      end

      ##
      # Iterates over the current definitions (i.e. the activated or highest
      # priority, if one exists) for every name in this registry, in no
      # particular order.
      #
      # @private This interface is internal and subject to change without warning.
      #
      def each_cur_definition
        @entries.each_value do |entry|
          definition = entry.cur_definition
          yield definition if definition
        end
      end

      ##
      # Record the source root for the given priority.
      #
      # @private This interface is internal and subject to change without warning.
      #
      # @param priority [Integer] The priority level.
      # @param source [Toys::SourceInfo] The root source for that priority. If
      #     not provided, defaults to an empty source.
      # @return [self]
      # @raise [Toys::ToolDefinitionError] if that priority already has a root.
      #
      def record_root(priority, source = nil)
        if @roots_by_priority.key?(priority)
          raise ToolDefinitionError, "Tool source root already recorded for priority #{priority}"
        end
        @roots_by_priority[priority] = source || SourceInfo.resolve(SourceSpec::EMPTY, priority: priority)
        self
      end

      private

      ##
      # Build a new tool definition.
      #
      def build_tool(words, priority, tool_class)
        parent = words.empty? ? nil : get_tool(words.slice(0..-2), priority)
        middleware_stack = parent ? parent.subtool_middleware_stack : @middleware_stack
        ToolDefinition.new(parent, words, @roots_by_priority[priority],
                           middleware_stack, @middleware_lookup, tool_class)
      end

      ##
      # Get the entry for the given name, creating it if requested.
      #
      # The creating and non-creating forms are both explicit at every call site
      # on purpose. Toys::Loader#lookup walks shortening prefixes of whatever
      # the user typed, so a creating read would validate names that were never
      # meant to define anything, and raise on any argument carrying a shell
      # metacharacter that reached the process unexpanded.
      #
      # Caller must own the mutex.
      #
      def entry_for(words, create)
        entry = @entries[words]
        if create
          unless entry
            # Ensure that tool names contain no illegal characters before
            # creating an entry
            words.each do |word|
              if /[[:cntrl:] #"$&'()*;<>\[\\\]\^`{|}]/.match(word)
                raise ToolDefinitionError, "Illegal characters in name #{word.inspect}"
              end
            end
            @entries[words] = entry = Entry.new
          end
        end
        entry
      end

      ##
      # The definitions of a single tool name, by priority, along with which of
      # them is the highest and which, if any, has been activated.
      #
      # This class is not thread-safe by itself. Its caller, the registry, holds
      # its own lock around every access.
      #
      # @private This interface is internal and subject to change without warning.
      #
      class Entry
        ##
        # Create an empty entry with no definitions.
        #
        # @private This interface is internal and subject to change without warning.
        #
        def initialize
          @definitions = {}
          @top_priority = @active_priority = nil
        end

        ##
        # The priority of the activated definition, or nil if none is active.
        #
        # @private This interface is internal and subject to change without warning.
        #
        attr_reader :active_priority

        ##
        # Return the current definition at the given priority without building
        # a new one, or nil if there is none.
        #
        # @private This interface is internal and subject to change without warning.
        #
        def [](priority)
          @definitions[priority]
        end

        ##
        # Return the current "best" definition, which is either the active
        # definition, or, if none, the current highest-priority definition.
        #
        # @private This interface is internal and subject to change without warning.
        #
        def cur_definition
          active_definition || top_definition
        end

        ##
        # Ensure a tool definition is created at the given priority. Returns
        # the existing tool at that priority, or the one created by the given
        # block. Also activates the tool if requested. This is the only
        # mutating method on Entry.
        #
        # @private This interface is internal and subject to change without warning.
        #
        def ensure_tool(priority, should_activate)
          tool = @definitions[priority]
          unless @definitions.key?(priority)
            @definitions[priority] = tool = yield
            @top_priority = priority if @top_priority.nil? || @top_priority < priority
          end
          @active_priority = priority if should_activate
          tool
        end

        private

        ##
        # Return the highest-priority definition, or nil if there is none.
        #
        def top_definition
          @top_priority ? @definitions[@top_priority] : nil
        end

        ##
        # Return the activated definition, or nil if none is active.
        #
        def active_definition
          @active_priority ? @definitions[@active_priority] : nil
        end
      end

      private_constant :Entry
    end
  end
end
