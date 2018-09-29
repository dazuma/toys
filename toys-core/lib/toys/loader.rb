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
  ##
  # The Loader service loads tools from configuration files, and finds the
  # appropriate tool given a set of command line arguments.
  #
  class Loader
    ## @private
    ToolData = ::Struct.new(:definitions, :top_priority, :active_priority) do
      def top_definition
        top_priority ? definitions[top_priority] : nil
      end

      def active_definition
        active_priority ? definitions[active_priority] : nil
      end
    end

    ##
    # Create a Loader
    #
    # @param [String,nil] index_file_name A file with this name that appears
    #     in any configuration directory (not just a toplevel directory) is
    #     loaded first as a standalone configuration file. If not provided,
    #     standalone configuration files are disabled.
    # @param [Array] middleware_stack An array of middleware that will be used
    #     by default for all tools loaded by this loader.
    # @param [String] extra_delimiters A string containing characters that can
    #     function as delimiters in a tool name. Defaults to empty. Allowed
    #     characters are period, colon, and slash.
    # @param [Toys::Utils::ModuleLookup] mixin_lookup A lookup for well-known
    #     mixin modules. Defaults to an empty lookup.
    # @param [Toys::Utils::ModuleLookup] middleware_lookup A lookup for
    #     well-known middleware classes. Defaults to an empty lookup.
    # @param [Toys::Utils::ModuleLookup] template_lookup A lookup for
    #     well-known template classes. Defaults to an empty lookup.
    #
    def initialize(index_file_name: nil, middleware_stack: [], extra_delimiters: "",
                   mixin_lookup: nil, middleware_lookup: nil, template_lookup: nil)
      if index_file_name && ::File.extname(index_file_name) != ".rb"
        raise ::ArgumentError, "Illegal index file name #{index_file_name.inspect}"
      end
      @mixin_lookup = mixin_lookup || Utils::ModuleLookup.new
      @middleware_lookup = middleware_lookup || Utils::ModuleLookup.new
      @template_lookup = template_lookup || Utils::ModuleLookup.new
      @index_file_name = index_file_name
      @middleware_stack = middleware_stack
      @worklist = []
      @tool_data = {}
      @max_priority = @min_priority = 0
      @extra_delimiters = process_extra_delimiters(extra_delimiters)
      get_tool_definition([], -999_999)
    end

    ##
    # Add a configuration file/directory to the loader.
    #
    # @param [String,Array<String>] path One or more paths to add.
    # @param [Boolean] high_priority If true, add this path at the top of the
    #     priority list. Defaults to false, indicating the new path should be
    #     at the bottom of the priority list.
    #
    def add_path(path, high_priority: false)
      paths = Array(path)
      priority = high_priority ? (@max_priority += 1) : (@min_priority -= 1)
      paths.each do |p|
        @worklist << [:file, check_path(p), [], priority]
      end
      self
    end

    ##
    # Add a configuration block to the loader.
    #
    # @param [Boolean] high_priority If true, add this block at the top of the
    #     priority list. Defaults to false, indicating the block should be at
    #     the bottom of the priority list.
    # @param [String] path The "path" that will be shown in documentation for
    #     tools defined in this block. If omitted, a default unique string will
    #     be generated.
    #
    def add_block(high_priority: false, path: nil, &block)
      path ||= "(Block #{block.object_id})"
      priority = high_priority ? (@max_priority += 1) : (@min_priority -= 1)
      @worklist << [block, path, [], priority]
      self
    end

    ##
    # Given a list of command line arguments, find the appropriate tool to
    # handle the command, loading it from the configuration if necessary, and
    # following aliases.
    # This always returns a tool. If the specific tool path is not defined and
    # cannot be found in any configuration, it finds the nearest namespace that
    # _would_ contain that tool, up to the root tool.
    #
    # Returns a tuple of the found tool, and the array of remaining arguments
    # that are not part of the tool name and should be passed as tool args.
    #
    # @param [Array<String>] args Command line arguments
    # @return [Array(Toys::Definition::Tool,Array<String>)]
    #
    def lookup(args)
      orig_prefix, args = find_orig_prefix(args)
      cur_prefix = orig_prefix
      loop do
        load_for_prefix(cur_prefix)
        prefix = orig_prefix
        loop do
          tool_definition = get_active_tool(prefix, [])
          if tool_definition
            finish_definitions_in_tree(tool_definition.full_name)
            return [tool_definition, args.slice(prefix.length..-1)]
          end
          break if prefix.empty? || prefix.length <= cur_prefix.length
          prefix = prefix.slice(0..-2)
        end
        raise "Unexpected error" if cur_prefix.empty?
        cur_prefix = cur_prefix.slice(0..-2)
      end
    end

    ##
    # Returns a list of subtools for the given path, loading from the
    # configuration if necessary.
    #
    # @param [Array<String>] words The name of the parent tool
    # @param [Boolean] recursive If true, return all subtools recursively
    #     rather than just the immediate children (the default)
    # @return [Array<Toys::Definition::Tool,Toys::Definition::Alias>]
    #
    def list_subtools(words, recursive: false)
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
    end

    ##
    # Returns true if the given path has at least one subtool. Loads from the
    # configuration if necessary.
    #
    # @param [Array<String>] words The name of the parent tool
    # @return [Boolean]
    #
    def has_subtools?(words)
      load_for_prefix(words)
      len = words.length
      @tool_data.each_key do |n|
        return true if !n.empty? && n.length > len && n.slice(0, len) == words
      end
      false
    end

    ##
    # Returns a tool specified by the given words, with the given priority.
    # Does not do any loading. If the tool is not present, creates it.
    #
    # @param [Array<String>] words The name of the tool.
    # @param [Integer] priority The priority of the request.
    # @return [Toys::Definition::Tool,Toys::Definition::Alias,nil] The tool or
    #     alias, or `nil` if the given priority is insufficient
    #
    # @private
    #
    def activate_tool_definition(words, priority)
      tool_data = get_tool_data(words)
      return tool_data.active_definition if tool_data.active_priority == priority
      return nil if tool_data.active_priority && tool_data.active_priority > priority
      tool_data.active_priority = priority
      get_tool_definition(words, priority)
    end

    ##
    # Sets the given name as an alias to the given target.
    #
    # @param [Array<String>] words The alias name
    # @param [Array<String>] target The alias target name
    # @param [Integer] priority The priority of the request
    #
    # @return [Toys::Definition::Alias] The alias created
    #
    # @private
    #
    def make_alias(words, target, priority)
      tool_data = get_tool_data(words)
      if tool_data.definitions.key?(priority)
        raise ToolDefinitionError,
              "Cannot make #{words.inspect} an alias because it is already defined"
      end
      alias_def = Definition::Alias.new(self, words, target, priority)
      tool_data.definitions[priority] = alias_def
      activate_tool_definition(words, priority)
      alias_def
    end

    ##
    # Returns true if the given tool name currently exists in the loader.
    # Does not load the tool if not found.
    #
    # @param [Array<String>] words The name of the tool.
    # @return [Boolean]
    #
    # @private
    #
    def tool_defined?(words)
      @tool_data.key?(words)
    end

    ##
    # Get or create the tool definition for the given name and priority.
    # May return either a tool or alias definition.
    #
    # @private
    #
    def get_tool_definition(words, priority)
      parent = words.empty? ? nil : get_tool_definition(words.slice(0..-2), priority)
      if parent.is_a?(Definition::Alias)
        raise ToolDefinitionError,
              "Cannot create children of #{parent.display_name.inspect} because it is an alias"
      end
      tool_data = get_tool_data(words)
      if tool_data.top_priority.nil? || tool_data.top_priority < priority
        tool_data.top_priority = priority
      end
      middlewares = @middleware_stack.map { |m| resolve_middleware(m) }
      tool_data.definitions[priority] ||=
        Definition::Tool.new(self, parent, words, priority, middlewares)
    end

    ##
    # Attempt to get a well-known mixin module for the given symbolic name.
    #
    # @param [Symbol] name Mixin name
    # @return [Module,nil] The mixin, or `nil` if not found.
    #
    def resolve_standard_mixin(name)
      @mixin_lookup.lookup(name)
    end

    ##
    # Attempt to get a well-known template class for the given symbolic name.
    #
    # @param [Symbol] name Template name
    # @return [Class,nil] The template, or `nil` if not found.
    #
    def resolve_standard_template(name)
      @template_lookup.lookup(name)
    end

    ##
    # Load configuration from the given path.
    #
    # @private
    #
    def load_path(path, words, remaining_words, priority)
      load_validated_path(check_path(path), words, remaining_words, priority)
    end

    ##
    # Load configuration from the given proc.
    #
    # @private
    #
    def load_proc(proc, words, remaining_words, priority, path)
      if remaining_words
        tool_class = get_tool_definition(words, priority).tool_class
        ::Toys::DSL::Tool.prepare(tool_class, remaining_words, path) do
          ::Toys::ContextualError.capture("Error while loading Toys config!") do
            tool_class.class_eval(&proc)
          end
        end
      else
        @worklist << [proc, path, words, priority]
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

    private

    ALLOWED_DELIMITERS = %r{^[\./:]*$}

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

    ##
    # Returns the current effective tool given a name. Resolves any aliases.
    #
    # If there is an active tool, returns it; otherwise, returns the highest
    # priority tool that has been defined. If no tool has been defined with
    # the given name, returns `nil`.
    #
    # @private
    #
    def get_active_tool(words, looked_up = [])
      tool_data = get_tool_data(words)
      result = tool_data.active_definition
      case result
      when Definition::Alias
        words = result.target_name
        if looked_up.include?(words)
          raise ToolDefinitionError, "Circular alias references: #{looked_up.inspect}"
        end
        looked_up << words
        get_active_tool(words, looked_up)
      when Definition::Tool
        result
      else
        tool_data.top_definition
      end
    end

    def resolve_middleware(input)
      input = Array(input)
      cls = input.first
      args = input[1..-1]
      if cls.is_a?(::String) || cls.is_a?(::Symbol)
        cls = @middleware_lookup.lookup(cls)
        if cls.nil?
          raise ::ArgumentError, "Unrecognized middleware name #{input.first.inspect}"
        end
      end
      if cls.is_a?(::Class)
        cls.new(*args)
      elsif !args.empty?
        raise ::ArgumentError, "Unrecognized middleware object of class #{cls.class}"
      else
        cls
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
        tool.finish_definition(self) if tool.is_a?(Definition::Tool)
      end
    end

    def load_for_prefix(prefix)
      cur_worklist = @worklist
      @worklist = []
      cur_worklist.each do |source, path, words, priority|
        remaining_words = calc_remaining_words(prefix, words)
        if source.respond_to?(:call)
          load_proc(source, words, remaining_words, priority, path)
        elsif source == :file
          load_validated_path(path, words, remaining_words, priority)
        end
      end
    end

    def load_validated_path(path, words, remaining_words, priority)
      if remaining_words
        load_relevant_path(path, words, remaining_words, priority)
      else
        @worklist << [:file, path, words, priority]
      end
    end

    def load_relevant_path(path, words, remaining_words, priority)
      if ::File.extname(path) == ".rb"
        tool_class = get_tool_definition(words, priority).tool_class
        Toys::InputFile.evaluate(tool_class, remaining_words, path)
      else
        load_index_in(path, words, remaining_words, priority)
        ::Dir.entries(path).each do |child|
          load_child_in(path, child, words, remaining_words, priority)
        end
      end
    end

    def load_index_in(path, words, remaining_words, priority)
      return unless @index_file_name
      index_path = ::File.join(path, @index_file_name)
      index_path = check_path(index_path, type: :file, lenient: true)
      load_relevant_path(index_path, words, remaining_words, priority) if index_path
    end

    def load_child_in(path, child, words, remaining_words, priority)
      return if child.start_with?(".")
      return if child == @index_file_name
      child_path = check_path(::File.join(path, child))
      child_word = ::File.basename(child, ".rb")
      next_words = words + [child_word]
      next_remaining = Loader.next_remaining_words(remaining_words, child_word)
      load_validated_path(child_path, next_words, next_remaining, priority)
    end

    def check_path(path, lenient: false, type: nil)
      path = ::File.expand_path(path)
      type ||= ::File.extname(path) == ".rb" ? :file : :dir
      case type
      when :file
        if ::File.directory?(path) || !::File.readable?(path)
          return nil if lenient
          raise LoaderError, "Cannot read file #{path}"
        end
      when :dir
        if !::File.directory?(path) || !::File.readable?(path)
          return nil if lenient
          raise LoaderError, "Cannot read directory #{path}"
        end
      else
        raise ::ArgumentError, "Illegal type #{type}"
      end
      path
    end

    def sort_tools_by_name(tools)
      tools.sort do |a, b|
        a = a.full_name
        b = b.full_name
        while !a.empty? && !b.empty? && a.first == b.first
          a = a.slice(1..-1)
          b = b.slice(1..-1)
        end
        a.first.to_s <=> b.first.to_s
      end
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
