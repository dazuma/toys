# frozen_string_literal: true

module Toys
  class Loader
    ##
    # A LoadState holds loading state applicable while defining a tool class.
    # It is created by the Loader and read by the DSL. Each tool class holds a
    # LoadState (in an ivar), which is created the first time the DSL runs for
    # that tool, and is updated in place each subsequent time.
    #
    # The internal state comprises four values: `loader`, `words`,
    # `remaining_words`, `source`. The first two are always consistent (i.e. a
    # tool class is always built by a single loader for a single tool name),
    # and are set in the constructor and never modified. The latter two could
    # be different due to evaluating different sources at different points
    # during loading, and are thus updated during the `enter` block.
    #
    # Note this class is not thread-safe by itself, so access should be
    # protected by an external lock. (In practice every mutation happens under
    # the Loader's mutex.)
    #
    # @private This interface is internal and subject to change without warning.
    #
    class LoadState
      # The tool class instance variable in which the load state is stored.
      # This name is reserved: tool class bodies are user-facing and can set
      # class instance variables of their own.
      IVAR_NAME = :@__toys_load_state
      private_constant :IVAR_NAME

      # The fiber-local slot holding a flag indicating whether the loader is
      # currently evaluating a block. This is used to determine whether it is
      # legal to subclass Toys::Tool.
      FIBER_LOCAL_KEY = :__toys_is_loading_block
      private_constant :FIBER_LOCAL_KEY

      class << self
        ##
        # Prepare a tool class in a block or at the top level of a tool file,
        # by setting up the class's LoadState and evaluating the given block
        # with this state active.
        #
        # @private This interface is internal and subject to change without warning.
        #
        # @param tool_class [Class] The tool class being loaded
        # @param loader [Toys::Loader] The loader
        # @param words [Array<String>] The tool name
        # @param remaining_words [Array<String>,nil] Remaining name segments
        # @param source [Toys::SourceInfo] The source being loaded
        # @return [Object] The value of the block
        #
        def prepare(tool_class, loader, words, remaining_words, source, &block)
          state = get(tool_class) ||
                  set(tool_class, new(loader, words, remaining_words, source))
          state.enter(remaining_words, source, &block)
        end

        ##
        # Prepare a tool class that was created by subclassing Toys::Tool,
        # by setting up the class's LoadState.
        #
        # @private This interface is internal and subject to change without warning.
        #
        # @param tool_class [Class] The tool class being loaded
        # @param given_name [String,nil] Any explicitly-provided tool name, or
        #     nil (the default) to infer one from the class name
        #
        def prepare_subclass(tool_class, given_name: nil)
          return if tool_class.name.nil? || get(tool_class)
          validate_parent_source

          mod_names = tool_class.name.split("::")
          class_name = mod_names.pop
          parent_state = parent_state_from_mod_name_segments(mod_names)
          parent_state.current_tool(false).check_definition_state(is_descending: true)
          loader = parent_state.loader
          name = given_name ? loader.tool_name_splitter.split(given_name) : class_name_to_tool_name(class_name)
          source = parent_state.source.subclass_child(tool_class)
          words, remaining_words = parent_state.descend_name(name)
          subtool = loader.get_tool(words, source.priority, tool_class: tool_class)
          set(tool_class, new(loader, words, remaining_words, source, cur_tool: subtool))
        end

        ##
        # The load state of the given tool class, or nil if the class has not
        # been prepared for loading.
        #
        # @private This interface is internal and subject to change without warning.
        #
        # @param tool_class [Class] The tool class
        # @return [Toys::Loader::LoadState,nil]
        #
        def get(tool_class)
          tool_class.instance_variable_defined?(IVAR_NAME) ? tool_class.instance_variable_get(IVAR_NAME) : nil
        end

        ##
        # Given a tool name, the name segments still outstanding in the current
        # lookup, and a set of new name segments to descend, return the
        # resulting tool name along with the resulting remaining words, which
        # are nil if the resulting name is not on the path to the name being
        # looked up.
        #
        # This computation is pure. No argument is modified, and callers must
        # treat the results as read-only because they may alias the arguments.
        # {LoadState} freezes them when it adopts them.
        #
        # @private This interface is internal and subject to change without warning.
        #
        # @param words [Array<String>] The current tool name
        # @param remaining_words [Array<String>,nil] Remaining name segments
        #     still outstanding in the current lookup
        # @param new_words [Array<String>] Name segments to descend
        # @return [Array(Array<String>,(Array<String>|nil))] The tool name with
        #     the new segments appended, and either the remaining name segments
        #     in the lookup if the descent followed it, or nil if the descent
        #     strayed from the lookup.
        #
        def descend_name(words, remaining_words, new_words)
          new_words = new_words.map(&:to_s)
          next_remaining = new_words.reduce(remaining_words) do |cur_remaining, word|
            if cur_remaining.nil?
              nil
            elsif cur_remaining.empty?
              cur_remaining
            elsif cur_remaining.first == word
              cur_remaining.slice(1..-1)
            end
          end
          [words + new_words, next_remaining]
        end

        private

        # Record the given state in the tool class's ivar.
        def set(tool_class, state)
          tool_class.instance_variable_set(IVAR_NAME, state)
        end

        # Infer a tool name from the class name
        def class_name_to_tool_name(class_name)
          name = class_name.to_s.sub(/^_+/, "").sub(/_+$/, "").gsub(/_+/, "-")
          while name.sub!(/([^-])([A-Z])/, "\\1-\\2") do end
          [name.downcase]
        end

        # Given the fully qualified module name for a Toys::Tool subclass's
        # namespace parent, return the LoadState for that parent.
        def parent_state_from_mod_name_segments(mod_names)
          parent = mod_names.reduce(::Object) do |running_mod, seg|
            running_mod.const_get(seg)
          end
          # This case is when the namespace is the outer module created when
          # loading via InputFile. InputFile sets that level's tool class in
          # this class instance variable.
          if parent.instance_variable_defined?(:@__tool_class)
            parent = parent.instance_variable_get(:@__tool_class)
          end
          state = get(parent)
          unless state
            # If the parent has no state, it generally means a Toys::Tool
            # subclass was put within a module that was not itself a tool class,
            # or otherwise was not directly created within the DSL.
            raise ToolDefinitionError, "Toys::Tool can be subclassed only from the Toys DSL"
          end
          state
        end

        # Raises if not currently evaluating a tool file or if in the middle of
        # evaluating a block in the DSL. Subclassing Toys::Tool is illegal in
        # both cases. This does not depend on having access to a LoadState,
        # because it might be called from the inherited callback for Toys::Tool
        # where there is no context to get the parent LoadState. Instead, it
        # uses the fiber-local variable set up in LoadState.prepare.
        def validate_parent_source
          case ::Thread.current[FIBER_LOCAL_KEY]
          when nil
            # No value set means we are not within a LoadState.prepare block,
            # hence not currently loading a tool from a tool file.
            raise ToolDefinitionError, "Toys::Tool can be subclassed only from a Toys tool file"
          when true
            # True means the innermost prepare block used a :proc source. We
            # disallow subclassing Toys::Tool here because the parent class of
            # the subclass would not match the parent tool.
            raise ToolDefinitionError, "Toys::Tool cannot be subclassed inside a tool block"
          end
          # False is the only legal value. It would indicate the enclosing
          # source is the file itself (source_type == :file) or another
          # subclass.
        end
      end

      ##
      # Create a LoadState. Use {LoadState.prepare} or
      # {LoadState.prepare_subclass} rather than calling this directly.
      #
      # @private This interface is internal and subject to change without warning.
      #
      # @param loader [Toys::Loader] The loader
      # @param words [Array<String>] The tool name
      # @param remaining_words [Array<String>,nil] Remaining name segments still
      #     outstanding in the current lookup, or nil if this name is not on the
      #     path to the name being looked up.
      # @param source [Toys::SourceInfo] The current source
      # @param cur_tool [Toys::ToolDefinition,nil] The current tool, seeded if
      #     available.
      #
      def initialize(loader, words, remaining_words, source, cur_tool: nil)
        @loader = loader
        @words = words.freeze
        @remaining_words = remaining_words.freeze
        @source = source
        @cur_tool = cur_tool
      end

      ##
      # Adopt the given load parameters, evaluate the given block, and then
      # restore the old parameters.
      # Called only from {LoadState.prepare}.
      #
      # @private This interface is internal and subject to change without warning.
      #
      # @param remaining_words [Array<String>,nil] Remaining name segments still
      #     outstanding in the current lookup, or nil if this name is not on the
      #     path to the name being looked up.
      # @param source [Toys::SourceInfo] The current source
      #
      # @return [Object] The value of the block
      #
      def enter(remaining_words, source)
        old_remaining_words = @remaining_words
        old_source = @source
        old_is_proc_flag = ::Thread.current[FIBER_LOCAL_KEY]
        begin
          @remaining_words = remaining_words.freeze
          @source = source
          ::Thread.current[FIBER_LOCAL_KEY] = source.source_type == :proc
          yield
        ensure
          @remaining_words = old_remaining_words
          @source = old_source
          ::Thread.current[FIBER_LOCAL_KEY] = old_is_proc_flag
        end
      end

      ##
      # The current source.
      #
      # @return [Toys::SourceInfo]
      #
      attr_reader :source

      ##
      # Descend the given name segments from this state's current name.
      # See {LoadState.descend_name}.
      #
      # @param new_words [Array<String>] Name segments to descend
      # @return [Array(Array<String>,(Array<String>|nil))]
      #
      def descend_name(new_words)
        LoadState.descend_name(@words, @remaining_words, new_words)
      end

      ##
      # Canonicalizes a given tool name, which could be an array or a single
      # string with delimiters.
      #
      # @param input_name [String,Array<String>] any allowed tool name format
      # @return [Array<String>] canonical format as array of strings
      #
      def canonical_absolute_tool_name(input_name)
        @loader.tool_name_splitter.split(input_name)
      end

      ##
      # Canonicalizes a given relative tool name, which could be an array or a
      # single string with delimiters, and returns the full absolute name
      # relative to the current tool name (words).
      #
      # @param input_name [String,Array<String>] any allowed tool name format
      # @return [Array<String>] canonical format as array of strings
      #
      def canonical_relative_tool_name(input_name)
        @words + canonical_absolute_tool_name(input_name)
      end

      ##
      # Get, and optionally activate, the tool definition being defined. The
      # result is memoized, separately for the activating and non-activating
      # cases.
      #
      # @param activate [boolean] Whether to activate the tool
      # @return [Toys::ToolDefinition] The tool definition
      # @return [nil] if activation failed because a higher-priority definition
      #     is already active.
      #
      def current_tool(activate)
        activate ? active_tool : cur_tool
      end

      ##
      # Resolve a mixin spec, which could be a mixin name defined in a tool
      # (i.e. a string), a well-known mixin name (i.e. a symbol) or a module.
      #
      # @param mixin [String,Symbol,Module] The mixin spec
      # @return [Module] The resolved mixin module
      # @raise [Toys::ToolDefinitionError] if the mixin name was not found
      #
      def resolve_mixin(mixin)
        mod =
          case mixin
          when ::String
            cur_tool.lookup_mixin(mixin)
          when ::Symbol
            @loader.resolve_standard_mixin(mixin)
          when ::Module
            mixin
          end
        raise ToolDefinitionError, "Mixin not found: #{mixin.inspect}" unless mod
        mod
      end

      ##
      # Resolve a template spec, which could be a template name defined in a
      # tool (i.e. a string), a well-known template name (i.e. a symbol) or a
      # class.
      #
      # @param template [String,Symbol,Class] The template spec
      # @return [Class] The resolved template class
      # @raise [Toys::ToolDefinitionError] if the template name was not found
      #
      def resolve_template(template)
        resolved =
          case template
          when ::String
            cur_tool.lookup_template(template)
          when ::Symbol
            @loader.resolve_standard_template(template)
          when ::Class
            template
          end
        raise ToolDefinitionError, "Template not found: #{template.inspect}" unless resolved
        resolved
      end

      ##
      # Set the loader to stop loading at the current priority, if possible.
      #
      # @raise [Toys::ToolDefinitionError] if lower-priority tools have already
      #     been loaded.
      #
      def stop_loading_at_current_priority
        unless @loader.stop_loading_at_priority(@source.priority)
          raise ToolDefinitionError,
                "Cannot truncate load path because tools have already been loaded"
        end
      end

      ##
      # Load the given source spec under the current load context, but without
      # inheriting SourceInfo fields (i.e. a separate source than the context.)
      #
      # @param spec [Toys::SourceSpec] The source to load
      # @return [self]
      #
      def load_source(spec)
        @loader.load_source(@source, spec, @words, @remaining_words)
        self
      end

      ##
      # Evaluate the given tool block with the given name under the current
      # load context, inheriting the current SourceInfo's fields.
      #
      # @param block [::Proc] the block to evaluate
      # @param subtool_name [String,Array<String>] the tool name
      # @param if_defined [:combine,:reset,:ignore] what to do if a definition
      #     is already present for the tool.
      # @return [self]
      #
      def eval_tool_block(block, subtool_name, if_defined)
        subtool_words, next_remaining = descend_name(@loader.tool_name_splitter.split(subtool_name))
        subtool = @loader.get_tool(subtool_words, @source.priority)
        if subtool.includes_definition?
          case if_defined
          when :ignore
            return self
          when :reset
            subtool.reset_definition
          end
        end
        @loader.load_block(@source, block, subtool_words, next_remaining) if block
        self
      end

      ##
      # Return a displayable name for the tool being evaluated
      #
      # @return [String]
      #
      def tool_display_name
        @words.empty? ? "(root)" : @words.join(" ").inspect
      end

      ##
      # A terse description of this state. Deliberately does not include the
      # source itself, whose inspection prints its entire parent chain.
      #
      # @return [String]
      #
      def inspect
        memos = []
        memos << "cur" if @cur_tool
        memos << "active" if defined?(@active_tool)
        "#<#{self.class}: words=#{@words.inspect} source=#{@source&.source_name.inspect}" \
          " memos=[#{memos.join(',')}]>"
      end

      ##
      # The loader.
      #
      # @private This interface is internal and subject to change without warning.
      #
      attr_reader :loader

      private

      # A non-activating fetch never returns nil, because ToolRegistry#get_tool
      # refuses only activation requests, so a plain memo suffices here.
      def cur_tool
        @cur_tool ||= @loader.get_tool(@words, @source.priority)
      end

      # An activating fetch returns nil when a higher-priority definition is
      # already active, which ToolRegistry#get_tool checks before it does
      # anything else. That nil is a stable answer, not a transient one:
      # Entry#ensure_tool assigns the active priority only on a request that
      # got past that check, so the active priority never decreases. Hence the
      # negative result is cached rather than retried.
      def active_tool
        return @active_tool if defined?(@active_tool)
        tool = @loader.get_tool(@words, @source.priority, activate: true)
        tool&.lock_source(@source)
        @cur_tool ||= tool
        @active_tool = tool
      end
    end
  end
end
