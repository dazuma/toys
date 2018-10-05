# frozen_string_literal: true

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

module Toys
  module Templates
    ##
    # A template that generates tools matching a rakefile.
    #
    class Rake
      include Template

      ##
      # Default version requirements for the rdoc gem.
      # @return [Array<String>]
      #
      DEFAULT_GEM_VERSION_REQUIREMENTS = ">= 12.0.0"

      ##
      # Default path to the Rakefile.
      # @return [String]
      #
      DEFAULT_RAKEFILE_PATH = "Rakefile"

      ##
      # Create the template settings for the rake template.
      #
      # @param [Array<String>] prefix Name prefix for tools to create. Defaults
      #     to `[]`.
      # @param [String,Array<String>] gem_version Version requirements for
      #     the rake gem. Defaults to {DEFAULT_GEM_VERSION_REQUIREMENTS}.
      # @param [String] rakefile_path Path to the Rakefile. Defaults to
      #     {DEFAULT_RAKEFILE_PATH}.
      # @param [Boolean] use_flags Generated tools use flags instead of
      #     positional arguments to pass arguments to rake tasks. Default is
      #     false.
      #
      def initialize(prefix: [],
                     gem_version: nil,
                     rakefile_path: nil,
                     use_flags: false)
        @prefix = prefix
        @gem_version = gem_version || DEFAULT_GEM_VERSION_REQUIREMENTS
        @rakefile_path = rakefile_path || DEFAULT_RAKEFILE_PATH
        @use_flags = use_flags
      end

      attr_accessor :prefix
      attr_accessor :gem_version
      attr_accessor :rakefile_path
      attr_accessor :use_flags

      to_expand do |template|
        gem "rake", *Array(template.gem_version)
        require "rake"
        ::Rake::TaskManager.record_task_metadata = true
        rake = ::Rake::Application.new
        ::Rake.application = rake
        ::Rake.load_rakefile(template.rakefile_path)
        rake.tasks.each do |task|
          tool(template.prefix + task.name.split(":"), if_defined: :ignore) do
            comments = task.full_comment.to_s.split("\n")
            unless comments.empty?
              desc(comments.first)
              long_desc(*comments)
            end
            if template.use_flags
              task.arg_names.each do |arg|
                spec = Templates::Rake.flag_spec(arg)
                flag(arg, spec) if spec
              end
              to_run do
                args = task.arg_names.map { |arg| self[arg] }
                task.invoke(*args)
              end
            else
              task.arg_names.each do |arg|
                optional_arg(arg)
              end
              to_run do
                task.invoke(*args)
              end
            end
          end
        end
      end

      ## @private
      def self.flag_spec(arg)
        name = arg.to_s.gsub(/\W/, "").tr("_", "-").downcase
        return nil if name.empty?
        "--#{name}=VALUE"
      end
    end
  end
end
