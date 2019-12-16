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
  # The Loader service loads tools from configuration files, and finds the
  # appropriate tool given a set of command line arguments.
  #
  # This class is not thread-safe.
  #
  class Loader
    ## @private
    ToolData = ::Struct.new(:definitions, :top_priority, :active_priority) do
      ## @private
      def top_definition
        top_priority ? definitions[top_priority] : nil
      end

      ## @private
      def active_definition
        active_priority ? definitions[active_priority] : nil
      end
    end

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
    # @param middleware_stack [Array] An array of middleware that will be used
    #     by default for all tools loaded by this loader.
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
    def initialize(index_file_name: nil, preload_dir_name: nil, preload_file_name: nil,
                   data_dir_name: nil, middleware_stack: [], extra_delimiters: "",
                   mixin_lookup: nil, middleware_lookup: nil, template_lookup: nil)
      if index_file_name && ::File.extname(index_file_name) != ".rb"
        raise ::ArgumentError, "Illegal index file name #{index_file_name.inspect}"
      end
      @mixin_lookup = mixin_lookup || ModuleLookup.new
      @middleware_lookup = middleware_lookup || ModuleLookup.new
      @template_lookup = template_lookup || ModuleLookup.new
      @index_file_name = index_file_name
      @preload_file_name = preload_file_name
      @preload_dir_name = preload_dir_name
      @data_dir_name = data_dir_name
      @middleware_stack = middleware_stack
      @worklist = []
      @tool_data = {}
      @max_priority = @min_priority = 0
      @extra_delimiters = process_extra_delimiters(extra_delimiters)
      get_tool([], -999_999)
    end

    ##
    # Add a configuration file/directory to the loader.
    #
    # @param paths [String,Array<String>] One or more paths to add.
    # @param high_priority [Boolean] If true, add this path at the top of the
    #     priority list. Defaults to false, indicating the new path should be
    #     at the bottom of the priority list.
    # @return [self]
    #
    def add_path(paths, high_priority: false)
      paths = Array(paths)
      priority = high_priority ? (@max_priority += 1) : (@min_priority -= 1)
      paths.each do |path|
        source = SourceInfo.create_path_root(path)
        @worklist << [source, [], priority]
      end
      self
    end

    ##
    # Add a configuration block to the loader.
    #
    # @param high_priority [Boolean] If true, add this block at the top of the
    #     priority list. Defaults to false, indicating the block should be at
    #     the bottom of the priority list.
    # @param name [String] The source name that will be shown in documentation
    #     for tools defined in this block. If omitted, a default unique string
    #     will be generated.
    # @param block [Proc] The block of configuration, executed in the context
    #     of the tool DSL {Toys::DSL::Tool}.
    # @return [self]
    #
    def add_block(high_priority: false, name: nil, &block)
      name ||= "(Code block #{block.object_id})"
      priority = high_priority ? (@max_priority += 1) : (@min_priority -= 1)
      source = SourceInfo.create_proc_root(block, name)
      @worklist << [source, [], priority]
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
    # @return [Array(Toys::Tool,Array<String>)]
    #
    def lookup(args)
      orig_prefix, args = find_orig_prefix(args)
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
    # @return [Toys::Tool] if the tool was found
    # @return [nil] if no such tool exists
    #
    def lookup_specific(words)
      words = split_path(words.first) if words.size == 1
      load_for_prefix(words)
      tool_data = get_tool_data(words)
      tool = tool_data.active_definition || tool_data.top_definition
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
    # @return [Array<Toys::Tool>] An array of subtools.
    #
    def list_subtools(words, recursive: false, include_hidden: false)
      load_for_prefix(words)
      found_tools = []
      len = words.length
      @tool_data.each do |n, td|
        next if n.empty?
        if recursive
          next if n.length <= len || n.slice(0, len) != words
        else
          next unless n.slice(0..-2) == words
        end
        tool = td.active_definition || td.top_definition
        found_tools << tool unless tool.nil?
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
      @tool_data.each do |n, td|
        if !n.empty? && n.length > len && n.slice(0, len) == words && !td.definitions.empty?
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
      str = str.to_s
      @extra_delimiters ? str.split(@extra_delimiters) : [str]
    end

    ##
    # Returns the active tool specified by the given words, with the given
    # priority, without doing any loading. If the given priority matches the
    # currently active tool, returns it. If the given priority is lower than
    # the active priority, returns `nil`. If the given priority is higher than
    # the active priority, returns and activates a new tool.
    #
    # @param words [Array<String>] The name of the tool.
    # @param priority [Integer] The priority of the request.
    #
    # @return [Toys::Tool] The tool found.
    # @return [nil] if the given priority is insufficient.
    #
    # @private
    #
    def activate_tool(words, priority)
      tool_data = get_tool_data(words)
      return tool_data.active_definition if tool_data.active_priority == priority
      return nil if tool_data.active_priority && tool_data.active_priority > priority
      tool_data.active_priority = priority
      get_tool(words, priority)
    end

    ##
    # Returns true if the given tool name currently exists in the loader.
    # Does not load the tool if not found.
    #
    # @param words [Array<String>] The name of the tool.
    # @return [Boolean]
    #
    # @private
    #
    def tool_defined?(words)
      @tool_data.key?(words)
    end

    ##
    # Loads the subtree under the given prefix.
    #
    # @param prefix [Array<String>] The name prefix.
    # @return [self]
    #
    # @private
    #
    def load_for_prefix(prefix)
      cur_worklist = @worklist
      @worklist = []
      cur_worklist.each do |source, words, priority|
        remaining_words = calc_remaining_words(prefix, words)
        if source.source_proc
          load_proc(source, words, remaining_words, priority)
        elsif source.source_path
          load_validated_path(source, words, remaining_words, priority)
        end
      end
      self
    end

    ##
    # Get or create the tool definition for the given name and priority.
    #
    # @return [Toys::Tool]
    #
    # @private
    #
    def get_tool(words, priority)
      parent = words.empty? ? nil : get_tool(words.slice(0..-2), priority)
      tool_data = get_tool_data(words)
      if tool_data.top_priority.nil? || tool_data.top_priority < priority
        tool_data.top_priority = priority
      end
      tool_data.definitions[priority] ||= begin
        middlewares = @middleware_stack.map { |m| resolve_middleware(m) }
        Tool.new(self, parent, words, priority, middlewares)
      end
    end

    ##
    # Attempt to get a well-known mixin module for the given symbolic name.
    #
    # @param name [Symbol] Mixin name
    # @return [Module] The mixin
    # @return [nil] if not found.
    #
    # @private
    #
    def resolve_standard_mixin(name)
      @mixin_lookup.lookup(name)
    end

    ##
    # Attempt to get a well-known template class for the given symbolic name.
    #
    # @param name [Symbol] Template name
    # @return [Class] The template.
    # @return [nil] if not found.
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
      source = parent_source.absolute_child(path)
      load_validated_path(source, words, remaining_words, priority)
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

    private

    ALLOWED_DELIMITERS = %r{^[\./:]*$}.freeze
    private_constant :ALLOWED_DELIMITERS

    def process_extra_delimiters(input)
      unless ALLOWED_DELIMITERS =~ input
        raise ::ArgumentError, "Illegal delimiters in #{input.inspect}"
      end
      chars = ::Regexp.escape(input.chars.uniq.join)
      chars.empty? ? nil : ::Regexp.new("[#{chars}]")
    end

    def find_orig_prefix(args)
      if @extra_delimiters
        first_split = (args.first || "").split(@extra_delimiters)
        if first_split.size > 1
          args = first_split + args.slice(1..-1)
          return [first_split, args]
        end
      end
      orig_prefix = args.take_while { |arg| !arg.start_with?("-") }
      [orig_prefix, args]
    end

    def get_tool_data(words)
      @tool_data[words] ||= ToolData.new({}, nil, nil)
    end

    def resolve_middleware(input)
      input = Array(input).dup
      middleware = input.shift
      if middleware.is_a?(::String) || middleware.is_a?(::Symbol)
        middleware = @middleware_lookup.lookup(middleware)
        if middleware.nil?
          raise ::ArgumentError, "Unknown middleware name #{input.first.inspect}"
        end
      end
      if middleware.is_a?(::Class)
        middleware = build_middleware(middleware, input)
      end
      unless input.empty?
        raise ::ArgumentError, "Unrecognized middleware arguments: #{input.inspect}"
      end
      middleware
    end

    def build_middleware(middleware_class, input)
      args = input.first
      if args.is_a?(::Array)
        input.shift
      else
        args = []
      end
      kwargs = input.first
      if kwargs.is_a?(::Hash)
        input.shift
      else
        kwargs = {}
      end
      # Due to a bug in Ruby < 2.7, passing an empty **kwargs splat to
      # initialize will fail if there are no formal keyword args.
      formals = middleware_class.instance_method(:initialize).parameters
      if kwargs.empty? && formals.all? { |(type, _name)| type != :key && type != :keyrest }
        middleware_class.new(*args)
      else
        middleware_class.new(*args, **kwargs)
      end
    end

    ##
    # Finishes all tool definitions under the given path. This generally means
    # installing middleware.
    #
    def finish_definitions_in_tree(words)
      load_for_prefix(words)
      len = words.length
      @tool_data.each do |n, td|
        next if n.length < len || n.slice(0, len) != words
        tool = td.active_definition || td.top_definition
        tool.finish_definition(self) if tool.is_a?(Tool)
      end
    end

    def load_proc(source, words, remaining_words, priority)
      if remaining_words
        tool_class = get_tool(words, priority).tool_class
        DSL::Tool.prepare(tool_class, remaining_words, source) do
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
        tool_class = get_tool(words, priority).tool_class
        InputFile.evaluate(tool_class, remaining_words, source)
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
      index_source = source.relative_child(@index_file_name, @data_dir_name)
      load_relevant_path(index_source, words, remaining_words, priority) if index_source
    end

    def load_child_in(source, child, words, remaining_words, priority)
      return if child.start_with?(".") || child == @index_file_name ||
                child == @preload_file_name || child == @preload_dir_name ||
                child == @data_dir_name
      child_source = source.relative_child(child, @data_dir_name)
      child_word = ::File.basename(child, ".rb")
      next_words = words + [child_word]
      next_remaining = Loader.next_remaining_words(remaining_words, child_word)
      load_validated_path(child_source, next_words, next_remaining, priority)
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
          ::Dir.entries(preload_dir).each do |child|
            next unless ::File.extname(child) == ".rb"
            preload_file = ::File.join(preload_dir, child)
            next if !::File.file?(preload_file) || !::File.readable?(preload_file)
            require preload_file
          end
        end
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
