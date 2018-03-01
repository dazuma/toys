require "shellwords"

module Toys
  module Templates
    Minitest = Toys::Template.new

    Minitest.to_init_opts do |opts|
      {
        name: "test",
        libs: ["lib", "test"],
        test_files: [],
        warning: true
      }.merge(opts)
    end

    Minitest.to_expand do |opts|
      toy_name = opts[:name] || "build"
      libs = opts[:libs] || []
      warning = opts[:warning]
      test_files = opts[:test_files] || []
      lib_path = libs.join(File::PATH_SEPARATOR)
      cmd = []
      cmd << File.join(RbConfig::CONFIG["bindir"], RbConfig::CONFIG["ruby_install_name"])
      cmd << "-I#{lib_path}" unless libs.empty?
      cmd << "-w" if warning
      cmd << "-e" << "ARGV.each{|f| load f}"
      cmd << "--"
      cmd = Shellwords.join(cmd + test_files)

      name toy_name do
        short_desc "Run minitest"

        helper_module :exec

        execute do
          sh(cmd, report_subprocess_errors: true)
        end
      end
    end
  end
end
