module Toys
  module Templates
    Rubocop = Struct.new(:name, :fail_on_error, :options) do
      include Toys::Template

      def initialize(opts = {})
        super(opts[:name] || "rubocop",
              opts.include?(:fail_on_error) ? opts[:fail_on_error] : true,
              opts[:options] || [])
      end

      to_expand do |template|
        name(template.name) do
          short_desc "Run RuboCop"

          use :exec

          execute do
            require "rubocop"
            cli = RuboCop::CLI.new
            logger.info "Running RuboCop..."
            result = cli.run(template.options)
            if result.nonzero?
              logger.error "RuboCop failed!"
              exit(1) if template.fail_on_error
            end
          end
        end
      end
    end
  end
end
