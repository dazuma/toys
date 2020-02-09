# frozen_string_literal: true

# Copyright 2019 Daniel Azuma
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.
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
      # @param gem_version [String,Array<String>,nil] Version requirements for
      #     the rake gem. Defaults to nil, indicating no version requirement.
      # @param rakefile_path [String] Path to the Rakefile. Defaults to
      #     {DEFAULT_RAKEFILE_PATH}.
      # @param only_described [Boolean] If true, tools are generated only for
      #     rake tasks with descriptions. Default is false.
      # @param use_flags [Boolean] Generated tools use flags instead of
      #     positional arguments to pass arguments to rake tasks. Default is
      #     false.
      # @param bundler [Boolean,Hash] If `false` (the default), bundler is not
      #     enabled for Rake tools. If `true` or a Hash of options, bundler is
      #     enabled. See the documentation for the
      #     [bundler mixin](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/StandardMixins/Bundler)
      #     for information on available options.
      #
      def initialize(gem_version: nil,
                     rakefile_path: nil,
                     only_described: false,
                     use_flags: false,
                     bundler: false)
        @gem_version = gem_version
        @rakefile_path = rakefile_path
        @only_described = only_described
        @use_flags = use_flags
        @bundler = bundler
      end

      ##
      # Version requirements for the minitest gem.
      # If set to `nil`, has no version requirement (unless one is specified in
      # the bundle.)
      #
      # @param value [String,Array<String>,nil]
      # @return [String,Array<String>,nil]
      #
      attr_writer :gem_version

      ##
      # Path to the Rakefile.
      # If set to `nil`, defaults to {DEFAULT_RAKEFILE_PATH}.
      #
      # @param value [String,nil]
      # @return [String,nil]
      #
      attr_writer :rakefile_path

      ##
      # Whether to generate tools only for rake tasks with descriptions.
      #
      # @param value [Boolean]
      # @return [Boolean]
      #
      attr_writer :only_described

      ##
      # Whether generated tools should use flags instead of positional
      # arguments to pass arguments to rake tasks.
      #
      # @param value [Boolean]
      # @return [Boolean]
      #
      attr_writer :use_flags

      ##
      # Set the bundler state and options for all Rake tools.
      #
      # Pass `false` to disable bundler. Pass `true` or a hash of options to
      # enable bundler. See the documentation for the
      # [bundler mixin](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/StandardMixins/Bundler)
      # for information on the options that can be passed.
      #
      # @param value [Boolean,Hash]
      # @return [Boolean,Hash]
      #
      attr_writer :bundler

      ##
      # Use bundler for all Rake tools.
      #
      # See the documentation for the
      # [bundler mixin](https://dazuma.github.io/toys/gems/toys-core/latest/Toys/StandardMixins/Bundler)
      # for information on the options that can be passed.
      #
      # @param opts [keywords] Options for bundler
      # @return [self]
      #
      def use_bundler(**opts)
        @bundler = opts
        self
      end

      # @private
      attr_reader :only_described
      # @private
      attr_reader :use_flags

      # @private
      def gem_version
        Array(@gem_version)
      end

      # @private
      def rakefile_path
        @rakefile_path || DEFAULT_RAKEFILE_PATH
      end

      # @private
      def bundler_settings
        if @bundler && !@bundler.is_a?(::Hash)
          {}
        else
          @bundler
        end
      end

      on_expand do |template|
        gem "rake", *template.gem_version
        require "rake"
        rakefile_path = Templates::Rake.find_rakefile(template.rakefile_path, context_directory)
        raise "Cannot find #{template.rakefile_path}" unless rakefile_path
        context_dir = ::File.dirname(rakefile_path)
        rake = Templates::Rake.prepare_rake(rakefile_path, context_dir)
        rake.tasks.each do |task|
          comments = task.full_comment.to_s.split("\n")
          next if comments.empty? && template.only_described
          tool(task.name.split(":"), if_defined: :ignore) do
            bundler_settings = template.bundler_settings
            include :bundler, **bundler_settings if bundler_settings
            unless comments.empty?
              desc(comments.first)
              comments << "" << "Defined as a Rake task in #{rakefile_path}"
              long_desc(*comments)
            end
            if template.use_flags
              task.arg_names.each do |arg|
                specs = Templates::Rake.flag_specs(arg)
                flag(arg, *specs) unless specs.empty?
              end
              to_run do
                args = task.arg_names.map { |arg| self[arg] }
                ::Dir.chdir(context_dir) do
                  task.invoke(*args)
                end
              end
            else
              task.arg_names.each do |arg|
                optional_arg(arg)
              end
              to_run do
                ::Dir.chdir(context_dir) do
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
      def self.prepare_rake(rakefile_path, context_dir)
        ::Rake::TaskManager.record_task_metadata = true
        rake = ::Rake::Application.new
        ::Rake.application = rake
        ::Dir.chdir(context_dir) do
          ::Rake.load_rakefile(rakefile_path)
        end
        rake
      end
    end
  end
end
