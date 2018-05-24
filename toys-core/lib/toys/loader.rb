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
    LOWEST_PRIORITY = -999_999_999

    ##
    # Create a Loader
    #
    # @param [String,nil] index_file_name A file with this name that appears
    #     in any configuration directory (not just a toplevel directory) is
    #     loaded first as a standalone configuration file. If not provided,
    #     standalone configuration files are disabled.
    # @param [String,nil] preload_file_name A file with this name that appears
    #     in any configuration directory (not just a toplevel directory) is
    #     loaded before any configuration files. It is not treated as a
    #     configuration file in that the configuration DSL is not honored. You
    #     may use such a file to define auxiliary Ruby modules and classes that
    #     used by the tools defined in that directory.
    # @param [Array] middleware_stack An array of middleware that will be used
    #     by default for all tools loaded by this loader.
    #
    def initialize(index_file_name: nil, preload_file_name: nil, middleware_stack: [])
      if index_file_name && ::File.extname(index_file_name) != ".rb"
        raise ::ArgumentError, "Illegal index file name #{index_file_name.inspect}"
      end
      if preload_file_name && ::File.extname(preload_file_name) != ".rb"
        raise ::ArgumentError, "Illegal preload file name #{preload_file_name.inspect}"
      end
      @index_file_name = index_file_name
      @preload_file_name = preload_file_name
      @middleware_stack = middleware_stack
      @load_worklist = []
      @tool_classes = {}
      @tool_definitions = {}
      @max_priority = @min_priority = 0
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
        @load_worklist << [check_path(p), [], priority]
      end
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
    # @param [String] args Command line arguments
    # @return [Array(Toys::Definition::Tool,Array<String>)]
    #
    def lookup(args)
      orig_prefix = args.take_while { |arg| !arg.start_with?("-") }
      cur_prefix = orig_prefix
      loop do
        load_for_prefix(cur_prefix)
        p = orig_prefix
        loop do
          tool = get_active_tool(p, [])
          if tool
            finish_definitions_in_tree(tool.full_name)
            return [tool, args.slice(p.length..-1)]
          end
          break if p.empty? || p.length <= cur_prefix.length
          p = p.slice(0..-2)
        end
        return nil if cur_prefix.empty?
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
    # @return [Array<Toys::Definition::Tool,Tool::Definition::Alias>]
    #
    def list_subtools(words, recursive: false)
      load_for_prefix(words)
      found_tools = []
      len = words.length
      @tool_definitions.each do |n, t|
        next if n.empty?
        if recursive
          next if n.length <= len || n.slice(0, len) != words
        else
          next unless n.slice(0..-2) == words
        end
        found_tools << t
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
      @tool_definitions.each_key do |n|
        return true if !n.empty? && n.length > len && n.slice(0, len) == words
      end
      false
    end

    ##
    # Finishes all tool definitions under the given path. This generally means
    # installing middleware.
    #
    # @param [Array<String>] words The path to the tool under which all
    #     definitions should be finished.
    #
    def finish_definitions_in_tree(words)
      load_for_prefix(words)
      len = words.length
      @tool_definitions.each do |n, t|
        next if n.length < len || n.slice(0, len) != words
        t.finish_definition(self) unless t.is_a?(Definition::Alias)
      end
    end

    ##
    # Returns a tool specified by the given words, with the given priority.
    # Does not do any loading. If the tool is not present, creates it.
    #
    # @param [Array<String>] words The name of the tool.
    # @param [Integer,nil] priority The priority of the request.
    # @return [Toys::Tool,Toys::Alias,nil] The tool or alias, or `nil` if the
    #     given priority is insufficient for modification
    #
    # @private
    #
    def activate_tool_definition(words, priority)
      tool = @tool_definitions[words]
      if tool
        if tool.priority == priority
          if priority && tool.is_a?(Definition::Alias)
            raise LoaderError, "Cannot modify #{@words.inspect} because it is already an alias"
          end
          return tool
        end
        return nil if tool.priority > priority
      end
      tool_class = @tool_classes[[words, priority]] || Tool
      tool_definition = Definition::Tool.new(words, priority, tool_class, @middleware_stack)
      @tool_definitions[words] = tool_definition
    end

    ##
    # Sets the given name as an alias to the given target.
    #
    # @param [Array<String>] words The alias name
    # @param [Array<String>] target The alias target name
    # @param [Integer] priority The priority of the request
    #
    # @return [Toys::Alias] The alias created
    #
    # @private
    #
    def make_alias(words, target, priority)
      existing = @tool_definitions[words]
      if existing
        if existing.priority == priority
          raise LoaderError, "Cannot make #{words.inspect} an alias because it is already defined"
        elsif existing.priority > priority
          return nil
        end
      end
      @tool_definitions[words] = Definition::Alias.new(words, target, priority)
    end

    ##
    # Adds a tool directly to the loader.
    # This should be used only for testing, as it overrides normal priority
    # checking.
    #
    # @param [Toys::Tool] tool Tool to add.
    #
    # @private
    #
    def put_tool!(tool)
      @tool_definitions[tool.full_name] = tool
      self
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
      @tool_definitions.key?(words)
    end

    ##
    # Returns a tool given a name. Resolves any aliases.
    #
    # @param [Array<String>] words Name of the tool
    # @param [Array<Array<String>>] looked_up List of names that have already
    #     been traversed during alias resolution. Used to detect circular
    #     alias references.
    # @return [Toys::Tool,nil] The tool, or `nil` if not found
    #
    # @private
    #
    def get_active_tool(words, looked_up = [])
      result = @tool_definitions[words]
      if result.is_a?(Definition::Alias)
        words = result.target_name
        if looked_up.include?(words)
          raise LoaderError, "Circular alias references: #{looked_up.inspect}"
        end
        looked_up << words
        result = get_active_tool(words, looked_up)
      end
      result
    end

    ##
    # Get the tool class for the given name and priority.
    #
    # @private
    #
    def get_tool_class(words, priority)
      @tool_definitions[words] ||=
        Definition::Tool.new(words, LOWEST_PRIORITY, ::Toys::Tool, @middleware_stack)
      tool_class = @tool_classes[[words, priority]]
      return tool_class if tool_class
      @tool_classes[[words, priority]] = tool_class = DSL::Tool.new_class(words, priority, self)
      ::ToysToolClasses.add(tool_class, words, priority, self)
      tool_class
    end

    ##
    # Load configuration from the given path.
    #
    # @private
    #
    def include_path(path, words, remaining_words, priority)
      handle_path(check_path(path), words, remaining_words, priority)
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

    def load_for_prefix(prefix)
      cur_worklist = @load_worklist
      @load_worklist = []
      cur_worklist.each do |path, words, priority|
        handle_path(path, words, calc_remaining_words(prefix, words), priority)
      end
    end

    def handle_path(path, words, remaining_words, priority)
      if remaining_words
        load_path(path, words, remaining_words, priority)
      else
        @load_worklist << [path, words, priority]
      end
    end

    def load_path(path, words, remaining_words, priority)
      if ::File.extname(path) == ".rb"
        tool_class = get_tool_class(words, priority)
        DSL::Tool.evaluate(tool_class, remaining_words, path, ::IO.read(path))
      else
        require_preload_in(path)
        load_index_in(path, words, remaining_words, priority)
        ::Dir.entries(path).each do |child|
          load_child_in(path, child, words, remaining_words, priority)
        end
      end
    end

    def require_preload_in(path)
      return unless @preload_file_name
      preload_path = ::File.join(path, @preload_file_name)
      preload_path = check_path(preload_path, type: :file, lenient: true)
      require preload_path if preload_path
    end

    def load_index_in(path, words, remaining_words, priority)
      return unless @index_file_name
      index_path = ::File.join(path, @index_file_name)
      index_path = check_path(index_path, type: :file, lenient: true)
      load_path(index_path, words, remaining_words, priority) if index_path
    end

    def load_child_in(path, child, words, remaining_words, priority)
      return if child.start_with?(".")
      return if [@preload_file_name, @index_file_name].include?(child)
      child_path = check_path(::File.join(path, child))
      child_word = ::File.basename(child, ".rb")
      next_words = words + [child_word]
      next_remaining = Loader.next_remaining_words(remaining_words, child_word)
      handle_path(child_path, next_words, next_remaining, priority)
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
