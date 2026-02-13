# frozen_string_literal: true

module Toys
  module Release
    ##
    # Represents a gemspec file
    #
    class GemspecFile
      ##
      # Transforms an input set of versions and pessimistic constraint level to
      # the dependency syntax for rubygems.
      #
      # @param versions [Hash{String=>Gem::Version}] Mapping from component
      #     name to version
      # @param dependency_semver_threshold [Semver] The semver significance
      #     threshold
      # @param pessimistic_constraint_level [Semver] The pessimistic constraint
      #
      # @return [Hash{String=>Array<String>}] Mapping from component name to
      #     the rubygems version constraint syntax
      #
      def self.transform_version_constraints(versions,
                                             dependency_semver_threshold,
                                             pessimistic_constraint_level)
        versions.transform_values do |version|
          if pessimistic_constraint_level == Semver::NONE
            ["= #{version}"]
          else
            segments = version.canonical_segments.dup
            segments.slice!((dependency_semver_threshold.segment + 1)..) if dependency_semver_threshold.segment
            pessimistic_segments =
              if segments.size <= pessimistic_constraint_level.segment
                segments.concat(::Array.new(pessimistic_constraint_level.segment - segments.size + 1, 0))
              else
                segments[..pessimistic_constraint_level.segment]
              end
            result = ["~> #{pessimistic_segments.join('.')}"]
            result << ">= #{segments.join('.')}" if segments.size > pessimistic_segments.size
            result
          end
        end
      end

      ##
      # Create a gemspec file object given a file path
      #
      # @param path [String] File path
      # @param environment_utils [Toys::Release::EnvironmentUtils]
      #
      def initialize(path, environment_utils)
        @path = path
        @utils = environment_utils
      end

      ##
      # @return [String] Path to the gemspec file
      #
      attr_reader :path

      ##
      # @return [boolean] Whether the file exists
      #
      def exists?
        path && ::File.file?(path)
      end

      ##
      # @return [String] Current contents of the file
      #
      def content
        @content ||= ::File.read(path)
      end

      ##
      # Get the current rubygems version constraints for all dependencies
      #
      # @return [Hash{String=>Array<String>}] Map from component name to a
      #     possibly empty array of version constraint strings.
      #
      def current_dependencies
        result = {}
        content.scan(/\.add_dependency\(?\s*["']([^"']+)["']((?:,\s*["']([^"',]+)["'])*)\s*\)?/) do |comp_name, expr|
          result[comp_name] = expr.scan(/["']([^"',]+)["']/).map(&:first)
        end
        result
      end

      ##
      # Update the rubygems version constraints
      #
      # @param constraint_updates [Hash{String=>Array<String>}] Map from
      #     component name to a possibly empty array of version constraint
      #     strings.
      # @return [self]
      #
      def update_dependencies(constraint_updates)
        constraint_updates.each do |name, exprs|
          escaped_name = Regexp.escape(name)
          regex = /\.add_dependency(\(?\s*)(["'])#{escaped_name}["'](?:,\s*["'][^"',]+["'])*(\s*\)?)/
          content.sub!(regex) do
            match = ::Regexp.last_match
            quote = match[2]
            exprs_str = exprs.map { |str| ", #{str.inspect}" }.join
            exprs_str.tr!('"', quote) unless quote == '"'
            ".add_dependency#{match[1]}#{quote}#{name}#{quote}#{exprs_str}#{match[3]}"
          end
        end
        ::File.write(path, content) if path
        self
      end

      # @private
      attr_writer :content
    end
  end
end
