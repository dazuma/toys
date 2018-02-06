module Toys
  class Lookup
    def initialize(binary_name,
                   config_dir_name: nil, config_file_name: nil, index_file_name: nil)
      @binary_name = binary_name
      @config_dir_name = config_dir_name
      @config_file_name = config_file_name
      @index_file_name = index_file_name
      @config_paths = []
      @special_paths = []
      @loaded_paths = {}
      @tools = {[] => Tool.new(nil, nil, @binary_name)}
    end

    def add_config_paths(paths)
      @config_paths += Array(paths)
      self
    end

    def add_special_paths(paths)
      @special_paths += Array(paths)
      self
    end

    def lookup(args)
      prefix = args.take_while{ |arg| !arg.start_with?("-") }
      catch(:tool) do
        loop do
          @special_paths.each do |path|
            lookup_dir(path, [], prefix)
          end
          @config_paths.each do |path|
            lookup_dir(File.join(path, @config_dir_name), [], prefix) if @config_dir_name
            lookup_file(File.join(path, @config_file_name), [], prefix, false) if @config_file_name
          end
          check_for_tool(prefix, final: true)
          raise "Unexpected: No tools found" if prefix.empty?
          prefix.pop
        end
      end
    end

    def lookup_dir(path, words, remaining_words)
      key = [path] + words
      return if @loaded_paths[key]
      if !File.directory?(path) || !File.readable?(path)
        @loaded_paths[key] = true
        return
      end
      if remaining_words.empty?
        @loaded_paths[key] = true
        children = Dir.entries(path) - [".", ".."]
        children.each do |child|
          if child == @index_file_name
            load_file(File.join(path, @index_file_name), words, [], false)
          elsif File.extname(child) == ".rb"
            load_file(File.join(path, child), words + [File.basename(child, ".rb")], [], true)
          else
            lookup_dir(File.join(path, child), words + [child], [])
          end
        end
      else
        word = remaining_words.first
        next_words = words + [word]
        next_remaining_words = remaining_words.slice(1..-1)
        lookup_file(File.join(path, "#{word}.rb"), next_words, next_remaining_words, true)
        lookup_dir(File.join(path, word), next_words, next_remaining_words)
        lookup_file(File.join(path, @index_file_name), words, remaining_words, false) if @index_file_name
      end
    end

    def get_tool(words)
      @tools[words] ||= Tool.new(get_tool(words[0..-2]), words.last, @binary_name)
    end

    def list_subtools(words, recursive)
      found_tools = []
      len = words.length
      @tools.each do |n, t|
        if n.length > 0
          if !recursive && n.slice(0..-2) == words ||
              recursive && n.length > len && n.slice(0, len) == words
            found_tools << t
          end
        end
      end
      found_tools.sort do |a, b|
        a = a.full_name
        b = b.full_name
        while !a.empty? && !b.empty? && a.first == b.first
          a = a.slice(1..-1)
          b = b.slice(1..-1)
        end
        a.first.to_s <=> b.first.to_s
      end
    end

    private

    def check_for_tool(prefix, final: false)
      found = @tools[prefix]
      found = nil if !final && found && found.executor == nil
      throw(:tool, found) if found
    end

    def lookup_file(path, words, remaining_words, allow_toplevel)
      load_file(path, words, remaining_words, allow_toplevel)
      check_for_tool(words + remaining_words)
    end

    def load_file(path, words, remaining_words, allow_toplevel)
      key = [path] + words
      return if @loaded_paths[key]
      @loaded_paths[key] = true
      return if File.directory?(path) || !File.readable?(path)
      parser = Parser.new(self, get_tool(words), remaining_words, allow_toplevel)
      eval(IO.read(path), parser._binding, path, 1)
    end
  end
end
