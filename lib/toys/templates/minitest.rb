module Toys
  module Templates
    Minitest = Struct.new(:name, :libs, :files, :warnings) do
      include Toys::Template

      def initialize(opts = {})
        super(opts[:name] || "test",
              opts[:libs] || ["lib"],
              opts[:files] || ["test/test*.rb"],
              opts.include?(:warnings) ? opts[:warnings] : true)
      end

      to_expand do |template|
        name(template.name) do
          short_desc "Run minitest"

          use :exec

          switch(
            :warnings, "-w", "--[no-]warnings",
            default: template.warnings,
            doc: "Turn on Ruby warnings (defaults to #{template.warnings})"
          )
          remaining_args(:tests, doc: "Paths to the tests to run (defaults to all tests)")

          execute do
            ruby_args = []
            unless template.libs.empty?
              lib_path = template.libs.join(File::PATH_SEPARATOR)
              ruby_args << "-I#{lib_path}"
            end
            ruby_args << "-w" if self[:warnings]

            tests = self[:tests]
            if tests.empty?
              Array(template.files).each do |pattern|
                tests.concat(Dir.glob(pattern))
              end
              tests.uniq!
            end

            ruby(ruby_args, in_from: :controller, exit_on_nonzero_status: true) do |controller|
              tests.each do |file|
                controller.in.puts("load '#{file}'")
              end
            end
          end
        end
      end
    end
  end
end
