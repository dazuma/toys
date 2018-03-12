module Toys
  module Templates
    class Clean < Struct.new(:name, :paths)
      include Toys::Template

      def initialize(opts={})
        super(opts[:name] || "clean",
              opts[:paths] || [])
      end

      to_expand do |template|
        name(template.name) do
          short_desc "Clean built files and directories"

          use :file_utils

          execute do
            files = []
            patterns = Array(template.paths)
            patterns = ["lib/**/*.rb"] if patterns.empty?
            patterns.each do |pattern|
              files.concat(Dir.glob(pattern))
            end
            files.uniq!

            files.each do |file|
              rm_rf file
            end
          end
        end
      end
    end
  end
end
