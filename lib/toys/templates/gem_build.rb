require "rubygems/package"

module Toys
  module Templates
    GemBuild = Toys::Template.new

    GemBuild.to_init_opts do |opts|
      {
        name: "build",
        gem_name: nil,
        push_gem: false,
        tag: false,
        push_tag: false
      }.merge(opts)
    end

    GemBuild.to_expand do |opts|
      toy_name = opts[:name] || "build"
      gem_name = opts[:gem_name]
      unless gem_name
        candidates = ::Dir.glob("*.gemspec")
        if candidates.size > 0
          gem_name = candidates.first.sub(/\.gemspec$/, "")
        else
          raise Toys::ToysDefinitionError, "Could not find a gemspec"
        end
      end
      push_gem = opts[:push_gem]
      tag = opts[:tag]
      push_tag = opts[:push_tag]

      name toy_name do
        short_desc "#{push_gem ? 'Release' : 'Build'} the gem: #{gem_name}"

        helper_module :file_utils
        helper_module :exec

        execute do
          gemspec = Gem::Specification.load "#{gem_name}.gemspec"
          version = gemspec.version
          gemfile = "#{gem_name}-#{version}.gem"
          Gem::Package.build gemspec
          mkdir_p "pkg"
          mv gemfile, "pkg"
          if push_gem
            if File.directory?(".git") && capture("git status -s").strip != ""
              logger.error "Cannot push the gem when there are uncommited changes"
              exit(1)
            end
            sh "gem push pkg/#{gemfile}", report_subprocess_errors: true
            if tag
              sh "git tag v#{version}", report_subprocess_errors: true
              if push_tag
                push_tag = "origin" if push_tag == true
                sh "git push #{push_tag} v#{version}", report_subprocess_errors: true
              end
            end
          end
        end
      end
    end
  end
end
