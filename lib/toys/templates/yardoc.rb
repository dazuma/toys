module Toys
  module Templates
    Yardoc = Struct.new(:name, :files, :options, :stats_options) do
      include Toys::Template

      def initialize(opts = {})
        super(opts[:name] || "yardoc",
              opts[:files] || [],
              opts[:options] || [],
              opts[:stats_options] || [])
      end

      to_expand do |template|
        name(template.name) do
          short_desc "Run yardoc"

          use :exec

          execute do
            require "yard"
            files = []
            patterns = Array(template.files)
            patterns = ["lib/**/*.rb"] if patterns.empty?
            patterns.each do |pattern|
              files.concat(Dir.glob(pattern))
            end
            files.uniq!

            unless template.stats_options.empty?
              template.options << "--no-stats"
              template.stats_options << "--use-cache"
            end

            yardoc = YARD::CLI::Yardoc.new
            yardoc.run(*(template.options + files))
            unless template.stats_options.empty?
              YARD::CLI::Stats.run(*template.stats_options)
            end
          end
        end
      end
    end
  end
end
