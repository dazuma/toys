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
      # Default path to the Rakefile.
      # @return [String]
      #
      DEFAULT_RAKEFILE_PATH = "Rakefile"

      ##
      # Create the template settings for the rake template.
      #
      # @param [String,Array<String>,nil] gem_version Version requirements for
      #     the rake gem. Defaults to nil, indicating no version requirement.
      # @param [String] rakefile_path Path to the Rakefile. Defaults to
      #     {DEFAULT_RAKEFILE_PATH}.
      # @param [Boolean] only_described If true, tools are generated only for
      #     rake tasks with descriptions. Default is false.
      # @param [Boolean] use_flags Generated tools use flags instead of
      #     positional arguments to pass arguments to rake tasks. Default is
      #     false.
      #
      def initialize(gem_version: nil,
                     rakefile_path: nil,
                     only_described: false,
                     use_flags: false)
        @gem_version = gem_version
        @rakefile_path = rakefile_path || DEFAULT_RAKEFILE_PATH
        @only_described = only_described
        @use_flags = use_flags
      end

      attr_accessor :gem_version
      attr_accessor :rakefile_path
      attr_accessor :only_described
      attr_accessor :use_flags

      to_expand do |template|
        gem "rake", *Array(template.gem_version)
        require "rake"
        path = Templates::Rake.find_rakefile(template.rakefile_path, context_directory)
        raise "Cannot find #{template.rakefile_path}" unless path
        rake = Templates::Rake.prepare_rake(path)
        rake.tasks.each do |task|
          comments = task.full_comment.to_s.split("\n")
          next if comments.empty? && template.only_described
          tool(task.name.split(":"), if_defined: :ignore) do
            unless comments.empty?
              desc(comments.first)
              comments << "" << "Defined as a Rake task in #{path}"
              long_desc(*comments)
            end
            if template.use_flags
              task.arg_names.each do |arg|
                specs = Templates::Rake.flag_specs(arg)
                flag(arg, *specs) unless specs.empty?
              end
              to_run do
                args = task.arg_names.map { |arg| self[arg] }
                Dir.chdir(context_directory || Dir.getwd) do
                  task.invoke(*args)
                end
              end
            else
              task.arg_names.each do |arg|
                optional_arg(arg)
              end
              to_run do
                Dir.chdir(context_directory || Dir.getwd) do
                  task.invoke(*args)
                end
              end
            end
          end
        end
      end

      ## @private
      def self.flag_specs(arg)
        name = arg.to_s.gsub(/\W/, "").downcase
        specs = []
        unless name.empty?
          specs << "--#{name}=VALUE"
          name2 = name.tr("_", "-")
          specs << "--#{name2}=VALUE" unless name2 == name
        end
        specs
      end

      ## @private
      def self.find_rakefile(path, context_dir)
        if path == ::File.absolute_path(path)
          return ::File.file?(path) && ::File.readable?(path) ? path : nil
        end
        dir = ::Dir.getwd
        50.times do
          rakefile_path = ::File.expand_path(path, dir)
          return rakefile_path if ::File.file?(rakefile_path) && ::File.readable?(rakefile_path)
          break if dir == context_dir
          next_dir = ::File.dirname(dir)
          break if dir == next_dir
          dir = next_dir
        end
        nil
      end

      ## @private
      def self.prepare_rake(rakefile_path)
        ::Rake::TaskManager.record_task_metadata = true
        rake = ::Rake::Application.new
        ::Rake.application = rake
        ::Rake.load_rakefile(rakefile_path)
        rake
      end
    end
  end
end
