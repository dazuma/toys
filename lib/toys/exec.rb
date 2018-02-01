module Toys
  class Exec
    def initialize(
      current_path: nil,
      current_path_base: nil,
      special_paths: nil,
      include_builtin: false
    )
      special_paths ||= []
      if include_builtin
        special_paths << File.join(File.dirname(File.dirname(__dir__)), "builtin")
      end
      @lookup = Lookup.new(current_path: current_path,
        current_path_base: current_path_base, special_paths: special_paths)
    end

    def run(args)
      tool = @lookup.lookup(args)
      prefix_len = tool.name.length
      args = args.slice(prefix_len..-1)
      tool.execute(args)
    end
  end
end
