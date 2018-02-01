require "optparse"

module Toys
  class CategoryTool
    DEFAULT_DESCRIPTION = "(No description available for this category)"

    def initialize(name, tools, short_desc: DEFAULT_DESCRIPTION, long_desc: "")
      @name = name
      @tools = tools
      @long_desc = long_desc
      @short_desc = short_desc
    end

    attr_reader :name

    attr_accessor :short_desc
    attr_accessor :long_desc

    def execute(args)
      option_data = {recursive: false}
      optparse = OptionParser.new
      optparse.banner = ([Util::TOYS_BINARY] + @name + ["<command>", "[<options...>]"]).join(" ")
      unless long_desc.empty?
        optparse.separator("")
        optparse.separator(long_desc)
      end
      optparse.separator("")
      optparse.separator("Options:")
      optparse.on("-?", "--help", "Show help message")
      optparse.on("-r", "--[no-]recursive", "Show all subcommands recursively") do |val|
        option_data[:recursive] = val
      end
      remaining = optparse.parse(args)
      unless remaining.empty?
        not_found = (@name + [remaining.first]).join(" ")
        puts("Tool not found for #{not_found}\n\n")
      else
        puts(optparse.to_s)
        puts("")
        puts("Commands:")
        find_subtools(option_data[:recursive]).each do |words, desc|
          puts("    #{words.join(' ').ljust(31)}  #{desc}")
        end
      end
    end

    private

    def find_subtools(recursive)
      found_tools = []
      len = @name.length
      @tools.each do |n, t|
        if n.length > 0
          if !recursive && n.slice(0..-2) == @name ||
              recursive && n.length > len && n.slice(0, len) == @name
            found_tools << [n.slice(len..-1), t.short_desc]
          end
        end
      end
      found_tools.sort do |a, b|
        a = a.first
        b = b.first
        while !a.empty? && !b.empty? && a.first == b.first
          a = a.slice(1..-1)
          b = b.slice(1..-1)
        end
        a.first.to_s <=> b.first.to_s
      end
    end
  end
end
