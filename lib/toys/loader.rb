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
    ##
    # Create a Loader
    #
    # @param [String,nil] config_dir_name A directory with this name that
    #     appears in the loader path, is treated as a configuration directory
    #     whose contents are loaded into the toys configuration. Optional.
    #     If not provided, toplevel configuration directories are disabled.
    # @param [String,nil] config_file_name A file with this name that appears
    #     in the loader path, is treated as a toplevel configuration file
    #     whose contents are loaded into the toys configuration. Optional.
    #     If not provided, toplevel configuration files are disabled.
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
    # @param [Array] middleware An array of middleware that will be used by
    #     default for all tools loaded by this CLI.
    # @param [String] root_desc The description of the root tool.
    #
    def initialize(config_dir_name: nil, config_file_name: nil,
                   index_file_name: nil, preload_file_name: nil,
                   middleware: [], root_desc: nil)
      @config_dir_name = config_dir_name
      @config_file_name = config_file_name
      @index_file_name = index_file_name
      @preload_file_name = preload_file_name
      @middleware = middleware
      check_init_options
      @load_worklist = []
      root_tool = Tool.new([])
      root_tool.middleware_stack.concat(@middleware)
      root_tool.long_desc = root_desc if root_desc
      @tools = {[] => [root_tool, nil]}
      @max_priority = @min_priority = 0
    end

    ##
    # Add one or more configuration files/directories to the loader.
    # This might point to a directory that defines a default set of tools.
    #
    # @param [String,Array<String>] paths One or more paths to add.
    # @param [Boolean] high_priority If true, add these paths at the top of
    #     the priority list. Defaults to false, indicating new paths should
    #     be at the bottom of the priority list.
    #
    def add_config_paths(paths, high_priority: false)
      paths = Array(paths)
      paths = paths.reverse if high_priority
      paths.each do |path|
        add_config_path(path, high_priority: high_priority)
      end
      self
    end

    ##
    # Add a single configuration file/directory to the loader.
    # This might point to a directory that defines a default set of tools.
    #
    # @param [String] path A path to add.
    # @param [Boolean] high_priority If true, add this path at the top of the
    #     priority list. Defaults to false, indicating the new path should be
    #     at the bottom of the priority list.
    #
    def add_config_path(path, high_priority: false)
      path = check_path(path)
      priority = high_priority ? (@max_priority += 1) : (@min_priority -= 1)
      @load_worklist << [path, [], priority]
      self
    end

    ##
    # Add one or more path directories to the loader. These directories are
    # searched for toplevel config directories and files.
    #
    # @param [String,Array<String>] paths One or more paths to add.
    # @param [Boolean] high_priority If true, add these paths at the top of
    #     the priority list. Defaults to false, indicating new paths should
    #     be at the bottom of the priority list.
    #
    def add_paths(paths, high_priority: false)
      paths = Array(paths)
      paths = paths.reverse if high_priority
      paths.each do |path|
        add_path(path, high_priority: high_priority)
      end
      self
    end

    ##
    # Add a single path directory to the loader. This directory is searched
    # for toplevel config directories and files.
    #
    # @param [String] path A path to add.
    # @param [Boolean] high_priority If true, add this path at the top of the
    #     priority list. Defaults to false, indicating the new path should be
    #     at the bottom of the priority list.
    #
    def add_path(path, high_priority: false)
      path = check_path(path, type: :dir)
      priority = high_priority ? (@max_priority += 1) : (@min_priority -= 1)
      if @config_file_name
        p = ::File.join(path, @config_file_name)
        if !::File.directory?(p) && ::File.readable?(p)
          @load_worklist << [p, [], priority]
        end
      end
      if @config_dir_name
        p = ::File.join(path, @config_dir_name)
        if ::File.directory?(p) && ::File.readable?(p)
          @load_worklist << [p, [], priority]
        end
      end
      self
    end

    ##
    # Given a list of command line arguments, find the appropriate tool to
    # handle the command, loading it from the configuration if necessary.
    # This always returns a tool. If the specific tool path is not defined and
    # cannot be found in any configuration, it returns the nearest group that
    # _would_ contain that tool, up to the root tool.
    #
    # @param [String] args Command line arguments
    # @return [Toys::Tool]
    #
    def lookup(args)
      orig_prefix = args.take_while { |arg| !arg.start_with?("-") }
      cur_prefix = orig_prefix.dup
      loop do
        load_for_prefix(cur_prefix)
        p = orig_prefix.dup
        while p.length >= cur_prefix.length
          return @tools[p].first if @tools.key?(p)
          p.pop
        end
        raise "Bug: No tools found" unless cur_prefix.pop
      end
    end

    ##
    # Returns a list of subtools for the given path, loading from the
    # configuration if necessary.
    #
    # @param [Array<String>] words The name of the parent tool
    # @param [Boolean] recursive If true, return all subtools recursively
    #     rather than just the immediate children (the default)
    # @return [Array<Toys::Tool>]
    #
    def list_subtools(words, recursive: false)
      load_for_prefix(words)
      found_tools = []
      len = words.length
      @tools.each do |n, tp|
        next if n.empty?
        if recursive
          next if n.length <= len || n.slice(0, len) != words
        else
          next unless n.slice(0..-2) == words
        end
        found_tools << tp.first
      end
      sort_tools_by_name(found_tools)
    end

    ##
    # Execute the tool given by the given arguments, in the given context.
    #
    # @param [Toys::Context::Base] context_base The context in which to
    #     execute.
    # @param [String] args Command line arguments
    # @param [Integer] verbosity Starting verbosity. Defaults to 0.
    # @return [Integer] The exit code
    #
    # @private
    #
    def execute(context_base, args, verbosity: 0)
      tool = lookup(args)
      tool.execute(context_base, args.slice(tool.full_name.length..-1), verbosity: verbosity)
    end

    ##
    # Returns a tool specified by the given words, with the given priority.
    # Does not do any loading. If the tool is not present, creates it.
    #
    # @param [Array<String>] words The name of the tool.
    # @param [Integer] priority The priority of the request.
    # @param [Boolean] assume_parent If true, does not check the parent tool's
    #     priority.
    # @return [Toys::Tool,nil] The tool, or `nil` if the given priority is
    #     insufficient.
    #
    # @private
    #
    def get_or_create_tool(words, priority, assume_parent: false)
      if tool_defined?(words)
        tool, tool_priority = @tools[words]
        return tool if priority.nil? || tool_priority.nil? || tool_priority == priority
        return nil if tool_priority > priority
      end
      unless assume_parent
        parent = get_or_create_tool(words[0..-2], priority)
        return nil if parent.nil?
      end
      prune_from(words)
      tool = Tool.new(words)
      tool.middleware_stack.concat(@middleware)
      @tools[words] = [tool, priority]
      tool
    end

    ##
    # Adds a tool directly to the loader.
    # This should be used only for testing, as it overrides normal priority
    # checking.
    #
    # @param [Toys::Tool] tool Tool to add.
    # @param [Integer,nil] priority Priority for the tool.
    #
    # @private
    #
    def put_tool!(tool, priority = nil)
      @tools[tool.full_name] = [tool, priority]
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
      @tools.key?(words)
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

    def check_init_options
      if @config_dir_name && ::File.extname(@config_dir_name) == ".rb"
        raise LookupError, "Illegal config dir name #{@config_dir_name.inspect}"
      end
      if @config_file_name && ::File.extname(@config_file_name) != ".rb"
        raise LookupError, "Illegal config file name #{@config_file_name.inspect}"
      end
      if @index_file_name && ::File.extname(@index_file_name) != ".rb"
        raise LookupError, "Illegal index file name #{@index_file_name.inspect}"
      end
      if @preload_file_name && ::File.extname(@preload_file_name) != ".rb"
        raise LookupError, "Illegal preload file name #{@preload_file_name.inspect}"
      end
    end

    def prune_from(words)
      return unless @tools.key?(words)
      @tools.delete_if { |k, _v| k[0, words.size] == words }
    end

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
        tool = get_or_create_tool(words, priority)
        if tool
          ConfigDSL.evaluate(path, tool, remaining_words, priority, self, :tool, ::IO.read(path))
        end
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
          raise LookupError, "Cannot read file #{path}"
        end
      when :dir
        if !::File.directory?(path) || !::File.readable?(path)
          return nil if lenient
          raise LookupError, "Cannot read directory #{path}"
        end
      else
        raise ArgumentError, "Illegal type #{type}"
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
