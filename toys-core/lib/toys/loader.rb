# frozen_string_literal: true

module Toys
  ##
  # The Loader service loads tools from tool sources, and finds the
  # appropriate tool given a set of command line arguments.
  #
  class Loader
    ##
    # Create a Loader.
    #
    # Note that the middleware stack and lookup objects are needed only for
    # building ToolDefinition objects, and are necessary because the Loader is
    # the factory for these objects.
    #
    # @param source_list [Toys::SourceList] The list of sources to use. The
    #     sources are snapshotted from the SourceList on construction, so if
    #     the SourceList is modified later, those modifications are not
    #     reflected in the constructed Loader.
    # @param tool_name_splitter [Toys::ToolNameSplitter] The splitter that
    #     interprets delimiters in tool names. Defaults to
    #     {Toys::ToolNameSplitter::DEFAULT}, which recognizes only whitespace.
    # @param middleware_stack [Array<Toys::Middleware::Spec>] An array of
    #     middleware that will be used by default for all tools loaded by this
    #     loader.
    # @param mixin_lookup [Toys::ModuleLookup] A lookup for well-known
    #     mixin modules. Defaults to an empty lookup.
    # @param middleware_lookup [Toys::ModuleLookup] A lookup for
    #     well-known middleware classes. Defaults to an empty lookup.
    # @param template_lookup [Toys::ModuleLookup] A lookup for
    #     well-known template classes. Defaults to an empty lookup.
    #
    def initialize(source_list,
                   tool_name_splitter: nil,
                   middleware_stack: [],
                   mixin_lookup: nil,
                   middleware_lookup: nil,
                   template_lookup: nil)
      require "monitor"
      # This mutex serializes all loading. It could be held for arbitrary
      # amounts of time because it surrounds the loading of tools files.
      @mutex = ::Monitor.new
      @mixin_lookup = mixin_lookup || ModuleLookup.new
      @template_lookup = template_lookup || ModuleLookup.new
      @middleware_lookup = middleware_lookup || ModuleLookup.new
      @tool_data = {}
      @stop_priority = -999_999
      @min_loaded_priority = 999_999
      @middleware_stack = Middleware.stack(middleware_stack)
      @tool_name_splitter = tool_name_splitter || ToolNameSplitter::DEFAULT
      @worklist = []
      @roots_by_priority = {}
      source_list.each do |source|
        @worklist << [source, [], source.priority]
        # SourceList enforces the invariant that each extant source priority
        # has exactly one root
        @roots_by_priority[source.priority] = source.root
      end
      @git_cache = source_list.git_cache
      @gems_util = source_list.gems_util
      get_tool([], -999_999)
    end

    ##
    # The splitter that interprets delimiters in the tool names handled by this
    # loader. Use it to convert a delimited name into words.
    #
    # @return [Toys::ToolNameSplitter]
    #
    attr_reader :tool_name_splitter

    ##
    # Given a list of command line arguments, find the appropriate tool to
    # handle the command, loading it from its source if necessary.
    # This always returns a tool. If the specific tool path is not defined and
    # cannot be found in any source, it finds the nearest namespace that
    # *would* contain that tool, up to the root tool.
    #
    # Returns a tuple of the found tool, and the array of remaining arguments
    # that are not part of the tool name and should be passed as tool args.
    #
    # @param args [Array<String>] Command line arguments. The first argument
    #     may be a full tool name with delimiters.
    # @return [Array(Toys::ToolDefinition,Array<String>)]
    #
    def lookup(args)
      orig_prefix, args = find_orig_prefix(args)
      # Start looking for a tool with the entire prefix, and continue to
      # shorten it until a tool is found. Because the root tool always exists,
      # the final fallback of the empty prefix will always succeed.
      prefix = orig_prefix
      loop do
        tool = lookup_specific(prefix)
        return [tool, args.slice(prefix.length..-1)] if tool
        prefix = prefix.slice(0..-2)
      end
    end

    ##
    # Given a tool name, looks up the specific tool, loading it from its source
    # if necessary.
    #
    # If there is an active tool, returns it; otherwise, returns the highest
    # priority tool that has been defined. If no tool has been defined with
    # the given name, returns `nil`.
    #
    # @param words [Array<String>] The tool name. It must be in the form of
    #     an array of strings; it cannot be a single string with delimiters.
    # @return [Toys::ToolDefinition] if the tool was found
    # @return [nil] if no such tool exists
    #
    def lookup_specific(words)
      load_for_prefix(words)
      tool = @mutex.synchronize { get_tool_data(words, false)&.cur_definition }
      finish_definitions_in_tree(words) if tool
      tool
    end

    ##
    # Returns a list of subtools for the given path, loading from their sources
    # if necessary. The list will be sorted by name.
    #
    # @param words [Array<String>] The name of the parent tool. It must be an
    #     array of strings; it cannot be a single string with delimiters.
    # @param recursive [boolean] If true, return all subtools recursively
    #     rather than just the immediate children (the default)
    # @param include_hidden [boolean] If true, include hidden subtools,
    #     i.e. names beginning with underscores. Defaults to false.
    # @param include_namespaces [boolean] If true, include namespaces,
    #     i.e. tools that are not runnable but have descendents that would have
    #     been listed by the current filters. Defaults to false.
    # @param include_non_runnable [boolean] If true, include tools that have
    #     no children and are not runnable. Defaults to false.
    # @return [Array<Toys::ToolDefinition>] An array of subtools.
    #
    def list_subtools(words,
                      recursive: false,
                      include_hidden: false,
                      include_namespaces: false,
                      include_non_runnable: false)
      load_for_prefix(words)
      len = words.length
      found_tools = all_cur_definitions.find_all do |tool|
        name = tool.full_name
        name.length > len && name.slice(0, len) == words &&
          (include_hidden || name[len..].none? { |word| word.start_with?("_") })
      end
      found_tools.sort_by!(&:full_name)
      found_tools = filter_non_runnable_tools(found_tools, include_namespaces, include_non_runnable)
      found_tools.select! { |tool| tool.full_name.length == len + 1 } unless recursive
      found_tools
    end

    ##
    # Returns true if the given path has at least one subtool, even if they are
    # hidden or non-runnable. Loads from the sources if necessary.
    #
    # @param words [Array<String>] The name of the parent tool. It must be an
    #     array of strings; it cannot be a single string with delimiters.
    # @return [boolean]
    #
    def has_subtools?(words) # rubocop:disable Naming/PredicatePrefix
      load_for_prefix(words)
      len = words.length
      all_cur_definitions.any? do |tool|
        name = tool.full_name
        name.length > len && name.slice(0, len) == words
      end
    end

    #### INTERNAL METHODS ####

    ##
    # Get or create the tool definition for the given name and priority.
    #
    # @private This interface is internal and subject to change without warning.
    #
    def get_tool(words, priority, tool_class = nil)
      @mutex.synchronize do
        get_tool_data(words, true).get_tool(priority, self, tool_class)
      end
    end

    ##
    # Returns the active tool specified by the given words, with the given
    # priority, without doing any loading. If the given priority matches the
    # currently active tool, returns it. If the given priority is lower than
    # the active priority, returns `nil`. If the given priority is higher than
    # the active priority, returns and activates a new tool.
    #
    # @private This interface is internal and subject to change without warning.
    #
    def activate_tool(words, priority)
      @mutex.synchronize do
        get_tool_data(words, true).activate_tool(priority, self)
      end
    end

    ##
    # Returns true if the given tool name currently exists in the loader.
    # Does not load the tool if not found.
    #
    # @private This interface is internal and subject to change without warning.
    #
    def tool_defined?(words)
      @tool_data.key?(words)
    end

    ##
    # Build a new tool.
    # Called only from ToolData.
    #
    # @private This interface is internal and subject to change without warning.
    #
    def build_tool(words, priority, tool_class = nil)
      parent = words.empty? ? nil : get_tool(words.slice(0..-2), priority)
      middleware_stack = parent ? parent.subtool_middleware_stack : @middleware_stack
      ToolDefinition.new(parent, words, priority, @roots_by_priority[priority],
                         middleware_stack, @middleware_lookup, tool_class)
    end

    ##
    # Stop search at the given priority. Returns true if successful.
    # Called only from the DSL.
    #
    # @private This interface is internal and subject to change without warning.
    #
    def stop_loading_at_priority(priority)
      @mutex.synchronize do
        return false if priority > @min_loaded_priority || priority < @stop_priority
        @stop_priority = priority
        true
      end
    end

    ##
    # Loads the subtree under the given prefix.
    #
    # @private This interface is internal and subject to change without warning.
    #
    def load_for_prefix(prefix)
      @mutex.synchronize do
        cur_worklist = @worklist
        @worklist = []
        cur_worklist.each do |source, words, priority|
          next if priority < @stop_priority
          remaining_words = calc_remaining_words(prefix, words)
          if source.source_proc
            load_proc(source, words, remaining_words, priority)
          elsif source.source_path
            load_validated_path(source, words, remaining_words, priority)
          end
        end
      end
      self
    end

    ##
    # Attempt to get a well-known mixin module for the given symbolic name.
    #
    # @private This interface is internal and subject to change without warning.
    #
    def resolve_standard_mixin(name)
      @mixin_lookup.lookup(name)
    end

    ##
    # Attempt to get a well-known template class for the given symbolic name.
    #
    # @private This interface is internal and subject to change without warning.
    #
    def resolve_standard_template(name)
      @template_lookup.lookup(name)
    end

    ##
    # Load tools from the given path. This is called from the `load` directive
    # in the DSL.
    #
    # @private This interface is internal and subject to change without warning.
    #
    def load_path(parent_source, path, words, remaining_words, priority)
      if parent_source.git_remote
        raise ToolDefinitionError, "Git source #{parent_source.source_name} tried to load from the local file system"
      end
      source = parent_source.absolute_child(path)
      @mutex.synchronize do
        load_validated_path(source, words, remaining_words, priority)
      end
    end

    ##
    # Load tools from the given git remote. This is called from the `load_git`
    # directive in the DSL.
    #
    # @private This interface is internal and subject to change without warning.
    #
    def load_git(parent_source, git_remote, git_path, git_commit, update,
                 words, remaining_words, priority)
      source = parent_source.git_child(git_remote,
                                       child_git_path: git_path,
                                       child_git_commit: git_commit,
                                       git_cache: @git_cache,
                                       update: update)
      @mutex.synchronize do
        load_validated_path(source, words, remaining_words, priority)
      end
    end

    ##
    # Load tools from the given gem. This is called from the `load_gem`
    # directive in the DSL.
    #
    # @private This interface is internal and subject to change without warning.
    #
    def load_gem(parent_source, gem_name, gem_version, gem_toys_dir, gem_path,
                 words, remaining_words, priority)
      source = parent_source.gem_child(gem_name,
                                       child_gem_version: gem_version,
                                       child_gem_path: gem_path,
                                       gem_toys_dir: gem_toys_dir,
                                       gems_util: @gems_util)
      @mutex.synchronize do
        load_validated_path(source, words, remaining_words, priority)
      end
    end

    ##
    # Load a subtool block. Called from the `tool` directive in the DSL.
    #
    # @private This interface is internal and subject to change without warning.
    #
    def load_block(parent_source, block, words, remaining_words, priority)
      source = parent_source.proc_child(block)
      @mutex.synchronize do
        load_proc(source, words, remaining_words, priority)
      end
    end

    ##
    # Determine the next setting for remaining_words, given a word.
    #
    # @private This interface is internal and subject to change without warning.
    #
    def self.next_remaining_words(remaining_words, word)
      if remaining_words.nil?
        nil
      elsif remaining_words.empty?
        remaining_words
      elsif remaining_words.first == word
        remaining_words.slice(1..-1)
      end
    end

    ##
    # An internal object managing the various definitions for a specific tool
    # tool name and their priorities, and tracking which, if any, has been
    # activated.
    #
    # This class is not thread-safe by itself. The caller must protect access
    # with a mutex.
    #
    # @private
    #
    class ToolData
      ##
      # Create an empty tool data with no definitions.
      #
      # @private
      #
      def initialize(words)
        @words = validate_words(words)
        @definitions = {}
        @top_priority = @active_priority = nil
      end

      ##
      # Return the current "best" definition, which is either the active
      # definition, or, if none, the current highest-priority definition.
      #
      # @private
      #
      def cur_definition
        active_definition || top_definition
      end

      ##
      # @private
      #
      def empty?
        @definitions.empty?
      end

      ##
      # Ensure there is a tool definition of the given priority, creating it if
      # needed, and return it. A tool class may be provided, but only if the
      # tool definition has not yet been created.
      #
      # @private
      #
      def get_tool(priority, loader, tool_class = nil)
        if @top_priority.nil? || @top_priority < priority
          @top_priority = priority
        end
        if tool_class && @definitions.include?(priority)
          raise ToolDefinitionError, "Tool already defined for #{@words.inspect}"
        end
        @definitions[priority] ||= loader.build_tool(@words, priority, tool_class)
      end

      ##
      # Attempt to activate the tool with the given priority, and return it.
      # If the given priority tool is already active, returns it.
      # If a lower priority tool is already active, activates the given higher
      # priority tool and returns it.
      # If a higher priority tool is already active, does nothing and returns
      # nil.
      #
      # @private
      #
      def activate_tool(priority, loader)
        return active_definition if @active_priority == priority
        return nil if @active_priority && @active_priority > priority
        @active_priority = priority
        get_tool(priority, loader)
      end

      private

      def validate_words(words)
        words.each do |word|
          if /[[:cntrl:] #"$&'()*;<>\[\\\]\^`{|}]/.match(word)
            raise ToolDefinitionError, "Illegal characters in name #{word.inspect}"
          end
        end
        words
      end

      def top_definition
        @top_priority ? @definitions[@top_priority] : nil
      end

      def active_definition
        @active_priority ? @definitions[@active_priority] : nil
      end
    end

    private

    ##
    # Determine the longest prefix of the given command line arguments that
    # could name a tool, along with the arguments to search it in.
    #
    # If the first argument spells a multi-word name using delimiters, that
    # name is the prefix, and its words replace that argument in the returned
    # arguments. Otherwise the prefix is the leading arguments that do not look
    # like flags, and the arguments are returned unchanged.
    #
    def find_orig_prefix(args)
      first_split = @tool_name_splitter.split(args.first || "")
      if first_split.size > 1
        args = first_split + args.slice(1..-1)
        return [first_split, args]
      end
      orig_prefix = args.take_while { |arg| !arg.start_with?("-") }
      [orig_prefix, args]
    end

    ##
    # Return a snapshot of all the current tool definitions that have been
    # loaded. No additional loading is done. The returned array is not in any
    # particular order.
    #
    def all_cur_definitions
      result = []
      @mutex.synchronize do
        @tool_data.each_value do |td|
          tool = td.cur_definition
          result << tool unless tool.nil?
        end
      end
      result
    end

    ##
    # Get or create the ToolData for the given name.
    # Caller must own the mutex.
    #
    def get_tool_data(words, create)
      create ? (@tool_data[words] ||= ToolData.new(words)) : @tool_data[words]
    end

    ##
    # Finishes all tool definitions under the given path. This generally means
    # installing middleware.
    #
    def finish_definitions_in_tree(words)
      load_for_prefix(words)
      len = words.length
      all_cur_definitions.each do |tool|
        name = tool.full_name
        next if name.length < len || name.slice(0, len) != words
        tool.finish_definition(self)
      end
    end

    ##
    # Loads from a proc source.
    # Caller must own the mutex.
    #
    def load_proc(source, words, remaining_words, priority)
      if remaining_words
        update_min_loaded_priority(priority)
        tool_class = get_tool(words, priority).tool_class
        DSL::Internal.prepare(tool_class, words, priority, remaining_words, source, self) do
          ContextualError.capture(banner: "Error while evaluating tool definition") do
            tool_class.class_eval(&source.source_proc)
          end
        end
      else
        @worklist << [source, words, priority]
      end
    end

    ##
    # Load from a file path source that is known to exist.
    # Caller must own the mutex.
    #
    def load_validated_path(source, words, remaining_words, priority)
      if remaining_words
        load_relevant_path(source, words, remaining_words, priority)
      else
        @worklist << [source, words, priority]
      end
    end

    ##
    # Load from a file path source that is known to exist and is known to be
    # relevant to the current load request.
    # Caller must own the mutex.
    #
    def load_relevant_path(source, words, remaining_words, priority)
      if source.source_type == :file
        update_min_loaded_priority(priority)
        tool_class = get_tool(words, priority).tool_class
        InputFile.evaluate(tool_class, words, priority, remaining_words, source, self)
      else
        source.find_preload_files.each do |file|
          require file
        end
        load_index_in(source, words, remaining_words, priority)
        ::Dir.entries(source.source_path).each do |child|
          load_child_in(source, child, words, remaining_words, priority)
        end
      end
    end

    ##
    # Load an index file in a directory source.
    # Caller must own the mutex.
    #
    def load_index_in(source, words, remaining_words, priority)
      index_source = source.index_child
      load_relevant_path(index_source, words, remaining_words, priority) if index_source
    end

    ##
    # Load non-index file in a directory source.
    # Caller must own the mutex.
    #
    def load_child_in(source, child, words, remaining_words, priority)
      return if child.start_with?(".")
      # Reminder: Also bail if in the future any special files/directories do
      # not begin with a dot.
      child_source = source.relative_child(child)
      return unless child_source
      child_word = ::File.basename(child, ".rb")
      next_words = words + [child_word]
      next_remaining = Loader.next_remaining_words(remaining_words, child_word)
      load_validated_path(child_source, next_words, next_remaining, priority)
    end

    ##
    # Update min_loaded_priority to the given value.
    # Caller must own the mutex.
    #
    def update_min_loaded_priority(priority)
      @min_loaded_priority = priority if @min_loaded_priority > priority
    end

    ##
    # This checks if words1 (a target prefix we're looking for) matches words2
    # (a source we could load).
    # If the source doesn't match the target and shouldn't be loaded at all,
    # returns nil.
    # Otherwise, returns an array indicating the part of target that doesn't
    # match the source, indicating what to look for as we descend down further
    # sources. This could be the empty array if we've exhausted the entire
    # desired target, and thus we should load everything from this point down.
    #
    def calc_remaining_words(words1, words2)
      index = 0
      lengths = [words1.length, words2.length]
      loop do
        return words1.slice(index..-1) if lengths.include?(index)
        return nil if words1[index] != words2[index]
        index += 1
      end
    end

    ##
    # Given a sorted list of tools, filter out non-runnable tools, subject to
    # the given settings.
    #
    def filter_non_runnable_tools(tools, include_namespaces, include_non_runnable)
      return tools if include_namespaces && include_non_runnable

      # This is a bit of a clever algorithm, sorry. We iterate over the sorted
      # list of tools backwards (i.e. a reverse depth-first traversal) and
      # apply the runnable and namespace filters.
      # We determine whether a non-runnable tool is a namespace (i.e. has a
      # runnable descendent) by tracking the state "kept_depth" representing
      # the longest tool name length of a tool that we have kept and whose
      # parent has yet to be traversed. Thus, when we traverse a non-runnable
      # node, we can tell whether we have kept at least one child.
      kept_depth = 0
      tools.reverse_each.select do |tool|
        cur_len = tool.full_name.length
        keep = tool.runnable? || (kept_depth > cur_len ? include_namespaces : include_non_runnable)
        kept_depth = cur_len if keep || kept_depth > cur_len
        keep
      end.reverse
    end
  end
end
