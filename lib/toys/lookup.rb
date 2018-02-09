module Toys
  class Lookup
    def initialize(config_dir_name: nil, config_file_name: nil, index_file_name: nil)
      @config_dir_name = config_dir_name
      if @config_dir_name && File.extname(@config_dir_name) == ".rb"
        raise LookupError, "Illegal config dir name #{@config_dir_name.inspect}"
      end
      @config_file_name = config_file_name
      if @config_file_name && File.extname(@config_file_name) != ".rb"
        raise LookupError, "Illegal config file name #{@config_file_name.inspect}"
      end
      @index_file_name = index_file_name
      if @index_file_name && File.extname(@index_file_name) != ".rb"
        raise LookupError, "Illegal index file name #{@index_file_name.inspect}"
      end
      @load_worklist = []
      @tools = {[] => Tool.new(nil, nil)}
    end

    def add_paths(paths)
      @load_worklist += Array(paths).map{ |path| [check_path(path), []] }
      self
    end

    def add_config_paths(paths)
      Array(paths).each do |path|
        if !File.directory?(path) || !File.readable?(path)
          raise LookupError, "Cannot read config directory #{path}"
        end
        if @config_file_name
          p = File.join(path, @config_file_name)
          @load_worklist << [p, []] if !File.directory?(p) && File.readable?(p)
        end
        if @config_dir_name
          p = File.join(path, @config_dir_name)
          @load_worklist << [p, []] if File.directory?(p) && File.readable?(p)
        end
      end
      self
    end

    def lookup(args)
      orig_prefix = args.take_while{ |arg| !arg.start_with?("-") }
      cur_prefix = orig_prefix.dup
      loop do
        load_for_prefix(cur_prefix)
        p = orig_prefix.dup
        while p.length >= cur_prefix.length
          return @tools[p] if @tools.key?(p)
          p.pop
        end
        raise "Bug: No tools found" unless cur_prefix.pop
      end
    end

    def get_tool(words)
      @tools[words] ||= Tool.new(get_tool(words[0..-2]), words.last)
    end

    def tool_defined?(words)
      @tools.key?(words)
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

    def include_path(path, words, remaining_words)
      handle_path(check_path(path), words, remaining_words)
    end

    private

    def load_for_prefix(prefix)
      cur_worklist = @load_worklist
      @load_worklist = []
      cur_worklist.each do |path, words|
        handle_path(path, words, calc_remaining_words(prefix, words))
      end
    end

    def handle_path(path, words, remaining_words)
      if remaining_words
        load_path(path, words, remaining_words)
      else
        @load_worklist << [path, words]
      end
    end

    def load_path(path, words, remaining_words)
      if File.extname(path) == ".rb"
        Parser.parse(path, get_tool(words), remaining_words, self, IO.read(path))
      else
        children = Dir.entries(path) - [".", ".."]
        children.each do |child|
          child_path = File.join(path, child)
          if child == @index_file_name
            load_path(check_path(child_path), words, remaining_words)
          else
            next unless check_path(child_path, strict: false)
            child_word = File.basename(child, ".rb")
            next_words = words + [child_word]
            next_remaining_words =
              if remaining_words.empty?
                remaining_words
              elsif child_word == remaining_words.first
                remaining_words.slice(1..-1)
              else
                nil
              end
            handle_path(child_path, next_words, next_remaining_words)
          end
        end
      end
    end

    def check_path(path, strict: true)
      if File.extname(path) == ".rb"
        if File.directory?(path) || !File.readable?(path)
          raise LookupError, "Cannot read file #{path}"
        end
      else
        if !File.directory?(path) || !File.readable?(path)
          if strict
            raise LookupError, "Cannot read directory #{path}"
          else
            return nil
          end
        end
      end
      path
    end

    def calc_remaining_words(words1, words2)
      index = 0
      loop do
        return words1.slice(index..-1) if index == words1.length || index == words2.length
        return nil if words1[index] != words2[index]
        index += 1
      end
    end
  end
end
