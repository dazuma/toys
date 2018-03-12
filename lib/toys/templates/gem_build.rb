require "rubygems/package"

module Toys
  module Templates
    class GemBuild < Struct.new(:name, :gem_name, :push_gem, :tag, :push_tag)
      include Toys::Template

      def initialize(opts={})
        super(opts[:name] || "build",
              opts[:gem_name],
              opts[:push_gem],
              opts[:tag],
              opts[:push_tag])
      end

      to_expand do |template|
        unless template.gem_name
          candidates = ::Dir.glob("*.gemspec")
          if candidates.size > 0
            template.gem_name = candidates.first.sub(/\.gemspec$/, "")
          else
            raise Toys::ToysDefinitionError, "Could not find a gemspec"
          end
        end
        task_type = template.push_gem ? 'Release' : 'Build'

        name(template.name) do
          short_desc "#{task_type} the gem: #{template.gem_name}"

          use :file_utils
          use :exec

          execute do
            configure_exec(exit_on_nonzero_status: true)
            gemspec = Gem::Specification.load "#{template.gem_name}.gemspec"
            version = gemspec.version
            gemfile = "#{template.gem_name}-#{version}.gem"
            Gem::Package.build gemspec
            mkdir_p "pkg"
            mv gemfile, "pkg"
            if template.push_gem
              if File.directory?(".git") && capture("git status -s").strip != ""
                logger.error "Cannot push the gem when there are uncommited changes"
                exit(1)
              end
              sh "gem push pkg/#{gemfile}"
              if template.tag
                sh "git tag v#{version}"
                if template.push_tag
                  template.push_tag = "origin" if template.push_tag == true
                  sh "git push #{template.push_tag} v#{version}"
                end
              end
            end
          end
        end
      end
    end
  end
end
