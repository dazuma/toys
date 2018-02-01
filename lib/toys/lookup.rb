module Toys
  class Lookup
    DIR_NAME = ".toys"
    FILE_NAME = ".toys.rb"
    ROOT_SHORT_DESC = "Category: all root categories"

    def initialize(current_path: nil, current_path_base: nil, special_paths: nil)
      current_path ||= Dir.pwd
      current_path_base ||= "/"
      @context_paths = []
      loop do
        @context_paths << current_path
        break if current_path == current_path_base
        next_path = File.dirname(current_path)
        break if next_path == current_path
        current_path = next_path
      end
      @special_paths = special_paths || []
      @tools = {}
      @tools[[]] = CategoryTool.new([], @tools, short_desc: ROOT_SHORT_DESC)
      @loaded_paths = {}
    end

    def lookup(args)
      prefix_length = args.find_index{ |arg| arg.start_with?("-") } || args.length
      found = catch(:tool) do
        prefix_length.downto(0) do |i|
          prefix = args.slice(0, i)
          suffix = args.slice(i..-1)
          @context_paths.each do |path|
            lookup_dir(File.join(path, DIR_NAME), [], prefix)
            lookup_file(File.join(path, FILE_NAME), [], prefix, false)
          end
          @special_paths.each do |path|
            lookup_dir(path, [], prefix)
          end
          check_for_tool(prefix, final: true)
        end
        nil
      end
      return found if found
      raise UsageError, "Tool not found for #{args.inspect}"
    end

    def check_for_tool(prefix, final: false)
      found = @tools[prefix]
      found = nil if found.is_a?(CategoryTool) && !final
      throw(:tool, found) if found
    end

    def lookup_dir(path, words, remaining_words)
      return if !File.directory?(path) || !File.readable?(path)
      if remaining_words.empty?
        children = Dir.entries(path) - [".", ".."]
        children.each do |child|
          if child == FILE_NAME
            load_file(File.join(path, FILE_NAME), words, false)
          elsif File.extname(child) == ".rb"
            child_word = File.basename(child, ".rb")
            load_file(File.join(path, child), words + [child_word], true)
          else
            load_file(File.join(path, child, FILE_NAME), words + [child], false)
          end
        end
      else
        word = remaining_words.first
        next_words = words + [word]
        next_remaining_words = remaining_words.slice(1..-1)
        lookup_file(File.join(path, "#{word}.rb"), next_words, next_remaining_words, true)
        lookup_dir(File.join(path, word), next_words, next_remaining_words)
        lookup_file(File.join(path, FILE_NAME), words, remaining_words, false)
      end
    end

    def lookup_file(path, words, remaining_words, allow_toplevel)
      load_file(path, words, allow_toplevel)
      check_for_tool(words + remaining_words)
    end

    def load_file(path, words, allow_toplevel)
      return if @loaded_paths[path] || File.extname(path) != ".rb"
      return if File.directory?(path) || !File.readable?(path)
      path_adder = allow_toplevel ? nil : method(:_path_adder)
      parser = Parser.new(words, method(:_saver),
        allow_toplevel: allow_toplevel, path_adder: path_adder)
      parser._parse(path)
      @loaded_paths[path] = true
    end

    def _path_adder(path)
      @special_paths << path
    end

    def _saver(words, tool)
      unless tool.executor
        tool = CategoryTool.new(words, @tools,
          short_desc: tool.short_desc, long_desc: tool.long_desc)
      end
      if !@tools[words] || @tools[words].is_a?(CategoryTool)
        @tools[words] = tool
      end
    end
  end
end
