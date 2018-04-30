# Copyright 2018 Daniel Azuma
#
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice,
#   this list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# * Neither the name of the copyright holder, nor the names of any other
#   contributors to this software, may be used to endorse or promote products
#   derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
;

require "rubygems/package"

module Toys
  module Templates
    ##
    # A template for tools that build and release gems
    #
    class GemBuild
      include Template

      def initialize(opts = {})
        @name = opts[:name] || "build"
        @gem_name = opts[:gem_name]
        @push_gem = opts[:push_gem]
        @tag = opts[:tag]
        @push_tag = opts[:push_tag]
      end

      attr_accessor :name
      attr_accessor :gem_name
      attr_accessor :push_gem
      attr_accessor :tag
      attr_accessor :push_tag

      to_expand do |template|
        unless template.gem_name
          candidates = ::Dir.glob("*.gemspec")
          if candidates.empty?
            raise ToolDefinitionError, "Could not find a gemspec"
          end
          template.gem_name = candidates.first.sub(/\.gemspec$/, "")
        end
        task_type = template.push_gem ? "Release" : "Build"

        name(template.name) do
          desc "#{task_type} the gem: #{template.gem_name}"

          use :file_utils
          use :exec

          execute do
            configure_exec(exit_on_nonzero_status: true)
            gemspec = ::Gem::Specification.load "#{template.gem_name}.gemspec"
            version = gemspec.version
            gemfile = "#{template.gem_name}-#{version}.gem"
            ::Gem::Package.build gemspec
            mkdir_p "pkg"
            mv gemfile, "pkg"
            if template.push_gem
              if ::File.directory?(".git") && capture("git status -s").strip != ""
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
