module Toys
  class Lookup
    def initialize(config_dir_name: nil, config_file_name: nil,
                   index_file_name: nil, preload_file_name: nil)
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
      @preload_file_name = preload_file_name
      if @preload_file_name && File.extname(@preload_file_name) != ".rb"
        raise LookupError, "Illegal preload file name #{@preload_file_name.inspect}"
      end
      @load_worklist = []
      @tools = {[] => [Tool.new(nil, nil), nil]}
      @max_priority = @min_priority = 0
    end

    def add_paths(paths, high_priority: false)
      paths = Array(paths)
      paths = paths.reverse if high_priority
      paths.each do |path|
        path = check_path(path)
        priority = high_priority ? (@max_priority += 1) : (@min_priority -= 1)
        @load_worklist << [path, [], priority]
      end
      self
    end

    def add_config_paths(paths, high_priority: false)
      paths = Array(paths)
      paths = paths.reverse if high_priority
      paths.each do |path|
        path = check_path(path, type: :dir)
        priority = high_priority ? (@max_priority += 1) : (@min_priority -= 1)
        if @config_file_name
          p = File.join(path, @config_file_name)
          if !File.directory?(p) && File.readable?(p)
            @load_worklist << [p, [], priority]
          end
        end
        if @config_dir_name
          p = File.join(path, @config_dir_name)
          if File.directory?(p) && File.readable?(p)
            @load_worklist << [p, [], priority]
          end
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
          return @tools[p].first if @tools.key?(p)
          p.pop
        end
        raise "Bug: No tools found" unless cur_prefix.pop
      end
    end

    def get_tool(words, priority)
      if @tools.key?(words)
        tool, tool_priority = @tools[words]
        return tool if tool_priority.nil? || tool_priority == priority
        return nil if tool_priority > priority
      end
      parent = get_tool(words[0..-2], priority)
      return nil if parent.nil?
      tool = Tool.new(parent, words.last)
      @tools[words] = [tool, priority]
      tool
    end

    def tool_defined?(words)
      @tools.key?(words)
    end

    def list_subtools(words, recursive)
      found_tools = []
      len = words.length
      @tools.each do |n, tp|
        if n.length > 0
          if !recursive && n.slice(0..-2) == words ||
              recursive && n.length > len && n.slice(0, len) == words
            found_tools << tp.first
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

    def include_path(path, words, remaining_words, priority)
      handle_path(check_path(path), words, remaining_words, priority)
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
      if File.extname(path) == ".rb"
        tool = get_tool(words, priority)
        if tool
          Parser.parse(path, tool, remaining_words, priority, self, IO.read(path))
        end
      else
        if @preload_file_name
          preload_path = File.join(path, @preload_file_name)
          if File.exist?(preload_path)
            preload_path = check_path(preload_path, type: :file)
            require preload_path
          end
        end
        if @index_file_name
          index_path = File.join(path, @index_file_name)
          if File.exist?(index_path)
            index_path = check_path(index_path, type: :file)
            load_path(index_path, words, remaining_words, priority)
          end
        end
        Dir.entries(path).each do |child|
          if !child.start_with?(".") && child != @preload_file_name && child != @index_file_name
            child_path = check_path(File.join(path, child))
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
            handle_path(child_path, next_words, next_remaining_words, priority)
          end
        end
      end
    end

    def check_path(path, lenient: false, type: nil)
      path = File.expand_path(path)
      type ||= File.extname(path) == ".rb" ? :file : :dir
      case type
      when :file
        if File.directory?(path) || !File.readable?(path)
          return nil if lenient
          raise LookupError, "Cannot read file #{path}"
        end
      when :dir
        if !File.directory?(path) || !File.readable?(path)
          return nil if lenient
          raise LookupError, "Cannot read directory #{path}"
        end
      else
        raise ArgumentError, "Illegal type #{type}"
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
