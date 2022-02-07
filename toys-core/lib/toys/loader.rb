# frozen_string_literal: true

require "monitor"

module Toys
  ##
  # The Loader service loads tools from configuration files, and finds the
  # appropriate tool given a set of command line arguments.
  #
  class Loader
    ##
    # Create a Loader
    #
    # @param index_file_name [String,nil] A file with this name that appears
    #     in any configuration directory (not just a toplevel directory) is
    #     loaded first as a standalone configuration file. If not provided,
    #     standalone configuration files are disabled.
    # @param preload_file_name [String,nil] A file with this name that appears
    #     in any configuration directory is preloaded before any tools in that
    #     configuration directory are defined.
    # @param preload_dir_name [String,nil] A directory with this name that
    #     appears in any configuration directory is searched for Ruby files,
    #     which are preloaded before any tools in that configuration directory
    #     are defined.
    # @param data_dir_name [String,nil] A directory with this name that appears
    #     in any configuration directory is added to the data directory search
    #     path for any tool file in that directory.
    # @param lib_dir_name [String,nil] A directory with this name that appears
    #     in any configuration directory is added to the Ruby load path for any
    #     tool file in that directory.
    # @param middleware_stack [Array<Toys::Middleware::Spec>] An array of
    #     middleware that will be used by default for all tools loaded by this
    #     loader.
    # @param extra_delimiters [String] A string containing characters that can
    #     function as delimiters in a tool name. Defaults to empty. Allowed
    #     characters are period, colon, and slash.
    # @param mixin_lookup [Toys::ModuleLookup] A lookup for well-known
    #     mixin modules. Defaults to an empty lookup.
    # @param middleware_lookup [Toys::ModuleLookup] A lookup for
    #     well-known middleware classes. Defaults to an empty lookup.
    # @param template_lookup [Toys::ModuleLookup] A lookup for
    #     well-known template classes. Defaults to an empty lookup.
    #
    def initialize(index_file_name: nil,
                   preload_dir_name: nil,
                   preload_file_name: nil,
                   data_dir_name: nil,
                   lib_dir_name: nil,
                   middleware_stack: [],
                   extra_delimiters: "",
                   mixin_lookup: nil,
                   middleware_lookup: nil,
                   template_lookup: nil,
                   git_cache: nil)
      if index_file_name && ::File.extname(index_file_name) != ".rb"
        raise ::ArgumentError, "Illegal index file name #{index_file_name.inspect}"
      end
      @mutex = ::Monitor.new
      @mixin_lookup = mixin_lookup || ModuleLookup.new
      @template_lookup = template_lookup || ModuleLookup.new
      @middleware_lookup = middleware_lookup || ModuleLookup.new
      @index_file_name = index_file_name
      @preload_file_name = preload_file_name
      @preload_dir_name = preload_dir_name
      @data_dir_name = data_dir_name
      @lib_dir_name = lib_dir_name
      @loading_started = false
      @worklist = []
      @tool_data = {}
      @roots_by_priority = {}
      @max_priority = @min_priority = 0
      @stop_priority = -999_999
      @min_loaded_priority = 999_999
      @middleware_stack = Middleware.stack(middleware_stack)
      @delimiter_handler = DelimiterHandler.new(extra_delimiters)
      @git_cache = git_cache
      get_tool([], -999_999)
    end

    ##
    # Add a configuration file/directory to the loader.
    #
    # @param path [String] A single path to add.
    # @param high_priority [Boolean] If true, add this path at the top of the
    #     priority list. Defaults to false, indicating the new path should be
    #     at the bottom of the priority list.
    # @param source_name [String] A custom name for the root source. Optional.
    # @param context_directory [String,nil,:path,:parent] The context directory
    #     for tools loaded from this path. You can pass a directory path as a
    #     string, `:path` to denote the given path, `:parent` to denote the
    #     given path's parent directory, or `nil` to denote no context.
    #     Defaults to `:parent`.
    # @return [self]
    #
    def add_path(path,
                 high_priority: false,
                 source_name: nil,
                 context_directory: :parent)
      @mutex.synchronize do
        raise "Cannot add a path after tool loading has started" if @loading_started
        priority = high_priority ? (@max_priority += 1) : (@min_priority -= 1)
        source = SourceInfo.create_path_root(path, priority,
                                             context_directory: context_directory,
                                             data_dir_name: @data_dir_name,
                                             lib_dir_name: @lib_dir_name,
                                             source_name: source_name)
        @roots_by_priority[priority] = source
        @worklist << [source, [], priority]
      end
      self
    end

    ##
    # Add a set of configuration files/directories from a common directory to
    # the loader. The set of paths will be added at the same priority level and
    # will share a root.
    #
    # @param root_path [String] A root path to be seen as the root source. This
    #     should generally be a directory containing the paths to add.
    # @param relative_paths [String,Array<String>] One or more paths to add, as
    #     relative paths from the common root.
    # @param high_priority [Boolean] If true, add the paths at the top of the
    #     priority list. Defaults to false, indicating the new paths should be
    #     at the bottom of the priority list.
    # @param context_directory [String,nil,:path,:parent] The context directory
    #     for tools loaded from this path. You can pass a directory path as a
    #     string, `:path` to denote the given root path, `:parent` to denote
    #     the given root path's parent directory, or `nil` to denote no context.
    #     Defaults to `:path`.
    # @return [self]
    #
    def add_path_set(root_path, relative_paths,
                     high_priority: false,
                     context_directory: :path)
      relative_paths = Array(relative_paths)
      @mutex.synchronize do
        raise "Cannot add a path after tool loading has started" if @loading_started
        priority = high_priority ? (@max_priority += 1) : (@min_priority -= 1)
        root_source = SourceInfo.create_path_root(root_path, priority,
                                                  context_directory: context_directory,
                                                  data_dir_name: @data_dir_name,
                                                  lib_dir_name: @lib_dir_name)
        @roots_by_priority[priority] = root_source
        relative_paths.each do |path, individual_name|
          source = root_source.relative_child(path, source_name: individual_name)
          @worklist << [source, [], priority]
        end
      end
      self
    end

    ##
    # Add a configuration block to the loader.
    #
    # @param high_priority [Boolean] If true, add this block at the top of the
    #     priority list. Defaults to false, indicating the block should be at
    #     the bottom of the priority list.
    # @param source_name [String] The source name that will be shown in
    #     documentation for tools defined in this block. If omitted, a default
    #     unique string will be generated.
    # @param block [Proc] The block of configuration, executed in the context
    #     of the tool DSL {Toys::DSL::Tool}.
    # @param context_directory [String,nil] The context directory for tools
    #     loaded from this block. You can pass a directory path as a string, or
    #     `nil` to denote no context. Defaults to `nil`.
    # @return [self]
    #
    def add_block(high_priority: false,
                  source_name: nil,
                  context_directory: nil,
                  &block)
      @mutex.synchronize do
        raise "Cannot add a block after tool loading has started" if @loading_started
        priority = high_priority ? (@max_priority += 1) : (@min_priority -= 1)
        source = SourceInfo.create_proc_root(block, priority,
                                             context_directory: context_directory,
                                             source_name: source_name,
                                             data_dir_name: @data_dir_name,
                                             lib_dir_name: @lib_dir_name)
        @roots_by_priority[priority] = source
        @worklist << [source, [], priority]
      end
      self
    end

    ##
    # Add a configuration git source to the loader.
    #
    # @param git_remote [String] The git repo URL
    # @param git_path [String] The path to the relevant file or directory in
    #     the repo. Specify the empty string to use the entire repo.
    # @param git_commit [String] The git ref (i.e. SHA, tag, or branch name)
    # @param high_priority [Boolean] If true, add this path at the top of the
    #     priority list. Defaults to false, indicating the new path should be
    #     at the bottom of the priority list.
    # @param update [Boolean] If the commit is not a SHA, pulls any updates
    #     from the remote. Defaults to false, which uses a local cache and does
    #     not update if the commit has been fetched previously.
    # @param context_directory [String,nil] The context directory for tools
    #     loaded from this source. You can pass a directory path as a string,
    #     or `nil` to denote no context. Defaults to `nil`.
    # @return [self]
    #
    def add_git(git_remote, git_path, git_commit,
                high_priority: false,
                update: false,
                context_directory: nil)
      @mutex.synchronize do
        raise "Cannot add a git source after tool loading has started" if @loading_started
        priority = high_priority ? (@max_priority += 1) : (@min_priority -= 1)
        path = git_cache.get(git_remote, path: git_path, commit: git_commit, update: update)
        source = SourceInfo.create_git_root(git_remote, git_path, git_commit, path, priority,
                                            context_directory: context_directory,
                                            data_dir_name: @data_dir_name,
                                            lib_dir_name: @lib_dir_name)
        @roots_by_priority[priority] = source
        @worklist << [source, [], priority]
      end
      self
    end

    ##
    # Given a list of command line arguments, find the appropriate tool to
    # handle the command, loading it from the configuration if necessary.
    # This always returns a tool. If the specific tool path is not defined and
    # cannot be found in any configuration, it finds the nearest namespace that
    # *would* contain that tool, up to the root tool.
    #
    # Returns a tuple of the found tool, and the array of remaining arguments
    # that are not part of the tool name and should be passed as tool args.
    #
    # @param args [Array<String>] Command line arguments
    # @return [Array(Toys::ToolDefinition,Array<String>)]
    #
    def lookup(args)
      orig_prefix, args = @delimiter_handler.find_orig_prefix(args)
      prefix = orig_prefix
      loop do
        tool = lookup_specific(prefix)
        return [tool, args.slice(prefix.length..-1)] if tool
        prefix = prefix.slice(0..-2)
      end
    end

    ##
    # Given a tool name, looks up the specific tool, loading it from the
    # configuration if necessary.
    #
    # If there is an active tool, returns it; otherwise, returns the highest
    # priority tool that has been defined. If no tool has been defined with
    # the given name, returns `nil`.
    #
    # @param words [Array<String>] The tool name
    # @return [Toys::ToolDefinition] if the tool was found
    # @return [nil] if no such tool exists
    #
    def lookup_specific(words)
      words = @delimiter_handler.split_path(words.first) if words.size == 1
      load_for_prefix(words)
      tool = get_tool_data(words, false)&.cur_definition
      finish_definitions_in_tree(words) if tool
      tool
    end

    ##
    # Returns a list of subtools for the given path, loading from the
    # configuration if necessary.
    #
    # @param words [Array<String>] The name of the parent tool
    # @param recursive [Boolean] If true, return all subtools recursively
    #     rather than just the immediate children (the default)
    # @param include_hidden [Boolean] If true, include hidden subtools,
    #     e.g. names beginning with underscores.
    # @return [Array<Toys::ToolDefinition>] An array of subtools.
    #
    def list_subtools(words, recursive: false, include_hidden: false)
      load_for_prefix(words)
      found_tools = []
      len = words.length
      all_cur_definitions.each do |tool|
        name = tool.full_name
        next if name.empty?
        if recursive
          next if name.length <= len || name.slice(0, len) != words
        else
          next unless name.slice(0..-2) == words
        end
        found_tools << tool
      end
      sort_tools_by_name(found_tools)
      include_hidden ? found_tools : filter_hidden_subtools(found_tools)
    end

    ##
    # Returns true if the given path has at least one subtool. Loads from the
    # configuration if necessary.
    #
    # @param words [Array<String>] The name of the parent tool
    # @return [Boolean]
    #
    def has_subtools?(words) # rubocop:disable Naming/PredicateName
      load_for_prefix(words)
      len = words.length
      all_cur_definitions.each do |tool|
        name = tool.full_name
        if !name.empty? && name.length > len && name.slice(0, len) == words
          return true
        end
      end
      false
    end

    ##
    # Splits the given path using the delimiters configured in this Loader.
    # You may pass in either an array of strings, or a single string possibly
    # delimited by path separators. Always returns an array of strings.
    #
    # @param str [String,Symbol,Array<String,Symbol>] The path to split.
    # @return [Array<String>]
    #
    def split_path(str)
      return str.map(&:to_s) if str.is_a?(::Array)
      @delimiter_handler.split_path(str.to_s)
    end

    ##
    # Get or create the tool definition for the given name and priority.
    #
    # @private
    #
    def get_tool(words, priority, tool_class = nil)
      get_tool_data(words, true).get_tool(priority, self, tool_class)
    end

    ##
    # Returns the active tool specified by the given words, with the given
    # priority, without doing any loading. If the given priority matches the
    # currently active tool, returns it. If the given priority is lower than
    # the active priority, returns `nil`. If the given priority is higher than
    # the active priority, returns and activates a new tool.
    #
    # @private
    #
    def activate_tool(words, priority)
      get_tool_data(words, true).activate_tool(priority, self)
    end

    ##
    # Returns true if the given tool name currently exists in the loader.
    # Does not load the tool if not found.
    #
    # @private
    #
    def tool_defined?(words)
      @tool_data.key?(words)
    end

    ##
    # Build a new tool.
    # Called only from ToolData.
    #
    # @private
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
    # @private
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
    # @private
    #
    def load_for_prefix(prefix)
      @mutex.synchronize do
        @loading_started = true
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
    # @private
    #
    def resolve_standard_mixin(name)
      @mixin_lookup.lookup(name)
    end

    ##
    # Attempt to get a well-known template class for the given symbolic name.
    #
    # @private
    #
    def resolve_standard_template(name)
      @template_lookup.lookup(name)
    end

    ##
    # Load configuration from the given path. This is called from the `load`
    # directive in the DSL.
    #
    # @private
    #
    def load_path(parent_source, path, words, remaining_words, priority)
      if parent_source.git_remote
        raise LoaderError,
              "Git source #{parent_source.source_name} tried to load from the local file system"
      end
      source = parent_source.absolute_child(path)
      @mutex.synchronize do
        load_validated_path(source, words, remaining_words, priority)
      end
    end

    ##
    # Load configuration from the given git remote. This is called from the
    # `load_git` directive in the DSL.
    #
    # @private
    #
    def load_git(parent_source, git_remote, git_path, git_commit, words, remaining_words, priority,
                 update: false)
      path = git_cache.get(git_remote, path: git_path, commit: git_commit, update: update)
      source = parent_source.git_child(git_remote, git_path, git_commit, path)
      @mutex.synchronize do
        load_validated_path(source, words, remaining_words, priority)
      end
    end

    ##
    # Load a subtool block. Called from the `tool` directive in the DSL.
    #
    # @private
    #
    def load_block(parent_source, block, words, remaining_words, priority)
      source = parent_source.proc_child(block)
      @mutex.synchronize do
        load_proc(source, words, remaining_words, priority)
      end
    end

    ##
    # Get a GitCache.
    #
    # @private
    #
    def git_cache
      @git_cache ||= begin
        require "toys/utils/git_cache"
        Utils::GitCache.new
      end
    end

    ##
    # Determine the next setting for remaining_words, given a word.
    #
    # @private
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
    # Tool data
    #
    # @private
    #
    class ToolData
      ##
      # @private
      #
      def initialize(words)
        @words = validate_words(words)
        @definitions = {}
        @top_priority = @active_priority = nil
        @mutex = ::Monitor.new
      end

      ##
      # @private
      #
      def cur_definition
        @mutex.synchronize { active_definition || top_definition }
      end

      ##
      # @private
      #
      def empty?
        @definitions.empty?
      end

      ##
      # @private
      #
      def get_tool(priority, loader, tool_class = nil)
        @mutex.synchronize do
          if @top_priority.nil? || @top_priority < priority
            @top_priority = priority
          end
          if tool_class && @definitions.include?(priority)
            raise ToolDefinitionError, "Tool already defined for #{@words.inspect}"
          end
          @definitions[priority] ||= loader.build_tool(@words, priority, tool_class)
        end
      end

      ##
      # @private
      #
      def activate_tool(priority, loader)
        @mutex.synchronize do
          return active_definition if @active_priority == priority
          return nil if @active_priority && @active_priority > priority
          @active_priority = priority
          get_tool(priority, loader)
        end
      end

      private

      def validate_words(words)
        words.each do |word|
          if /[[:cntrl:] #"$&'()*;<>\[\\\]\^`{|}]/.match(word)
            raise ToolDefinitionError, "Illegal characters in name #{word.inspect}"
          end
        end
      end

      def top_definition
        @top_priority ? @definitions[@top_priority] : nil
      end

      def active_definition
        @active_priority ? @definitions[@active_priority] : nil
      end
    end

    ##
    # An object that handles name delimiting.
    #
    # @private
    #
    class DelimiterHandler
      ##
      # @private
      #
      def initialize(extra_delimiters)
        unless %r{^[[:space:]./:]*$}.match?(extra_delimiters)
          raise ::ArgumentError, "Illegal delimiters in #{extra_delimiters.inspect}"
        end
        chars = ::Regexp.escape(extra_delimiters.chars.uniq.join)
        @delimiters = ::Regexp.new("[[:space:]#{chars}]")
      end

      ##
      # @private
      #
      def split_path(str)
        str.split(@delimiters)
      end

      ##
      # @private
      #
      def find_orig_prefix(args)
        first_split = (args.first || "").split(@delimiters)
        if first_split.size > 1
          args = first_split + args.slice(1..-1)
          return [first_split, args]
        end
        orig_prefix = args.take_while { |arg| !arg.start_with?("-") }
        [orig_prefix, args]
      end
    end

    private

    def all_cur_definitions
      result = []
      @mutex.synchronize do
        @tool_data.map do |_name, td|
          tool = td.cur_definition
          result << tool unless tool.nil?
        end
      end
      result
    end

    def get_tool_data(words, create)
      @mutex.synchronize do
        create ? (@tool_data[words] ||= ToolData.new(words)) : @tool_data[words]
      end
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

    def load_proc(source, words, remaining_words, priority)
      if remaining_words
        update_min_loaded_priority(priority)
        tool_class = get_tool(words, priority).tool_class
        DSL::Internal.prepare(tool_class, words, priority, remaining_words, source, self) do
          ContextualError.capture("Error while loading Toys config!") do
            tool_class.class_eval(&source.source_proc)
          end
        end
      else
        @worklist << [source, words, priority]
      end
    end

    def load_validated_path(source, words, remaining_words, priority)
      if remaining_words
        load_relevant_path(source, words, remaining_words, priority)
      else
        @worklist << [source, words, priority]
      end
    end

    def load_relevant_path(source, words, remaining_words, priority)
      if source.source_type == :file
        update_min_loaded_priority(priority)
        tool_class = get_tool(words, priority).tool_class
        InputFile.evaluate(tool_class, words, priority, remaining_words, source, self)
      else
        do_preload(source.source_path)
        load_index_in(source, words, remaining_words, priority)
        ::Dir.entries(source.source_path).each do |child|
          load_child_in(source, child, words, remaining_words, priority)
        end
      end
    end

    def load_index_in(source, words, remaining_words, priority)
      return unless @index_file_name
      index_source = source.relative_child(@index_file_name)
      load_relevant_path(index_source, words, remaining_words, priority) if index_source
    end

    def load_child_in(source, child, words, remaining_words, priority)
      return if child.start_with?(".") || child == @index_file_name ||
                child == @preload_file_name || child == @preload_dir_name ||
                child == @data_dir_name || child == @lib_dir_name
      child_source = source.relative_child(child)
      return unless child_source
      child_word = ::File.basename(child, ".rb")
      next_words = words + [child_word]
      next_remaining = Loader.next_remaining_words(remaining_words, child_word)
      load_validated_path(child_source, next_words, next_remaining, priority)
    end

    def update_min_loaded_priority(priority)
      @min_loaded_priority = priority if @min_loaded_priority > priority
    end

    def do_preload(path)
      if @preload_file_name
        preload_file = ::File.join(path, @preload_file_name)
        if ::File.file?(preload_file) && ::File.readable?(preload_file)
          require preload_file
        end
      end
      if @preload_dir_name
        preload_dir = ::File.join(path, @preload_dir_name)
        if ::File.directory?(preload_dir) && ::File.readable?(preload_dir)
          preload_dir_contents(preload_dir)
        end
      end
    end

    def preload_dir_contents(preload_dir)
      ::Dir.entries(preload_dir).each do |child|
        next unless ::File.extname(child) == ".rb"
        preload_file = ::File.join(preload_dir, child)
        next if !::File.file?(preload_file) || !::File.readable?(preload_file)
        require preload_file
      end
    end

    def sort_tools_by_name(tools)
      tools.sort! do |a, b|
        a = a.full_name
        b = b.full_name
        while !a.empty? && !b.empty? && a.first == b.first
          a = a.slice(1..-1)
          b = b.slice(1..-1)
        end
        a.first.to_s <=> b.first.to_s
      end
    end

    def filter_hidden_subtools(tools)
      result = []
      tools.each_with_index do |tool, index|
        result << tool unless tool_hidden?(tool, tools[index + 1])
      end
      result
    end

    def tool_hidden?(tool, next_tool)
      return true if tool.full_name.any? { |n| n.start_with?("_") }
      !tool.runnable? && next_tool && next_tool.full_name.slice(0..-2) == tool.full_name
    end

    def calc_remaining_words(words1, words2)
      index = 0
      lengths = [words1.length, words2.length]
      loop do
        return words1.slice(index..-1) if lengths.include?(index)
        return nil if words1[index] != words2[index]
        index += 1
      end
    end
  end
end
