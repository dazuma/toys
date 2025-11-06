# frozen_string_literal: true

module Toys
  module Release
    ##
    # Represents a version.rb file
    #
    class VersionRbFile
      ##
      # Create a version file object given a file path
      #
      # @param path [String] File path
      # @param environmentUtils [Toys::Release::EnvironmentUtils]
      # @param constant_name [Array<String>] Fully qualified name of the version
      #     constant
      #
      def initialize(path, environment_utils, constant_name)
        @path = path
        @utils = environment_utils
        @constant_name = constant_name
      end

      ##
      # @return [String] Path to the version file
      #
      attr_reader :path

      ##
      # @return [Array<String>] Fully qualified name of the version constant
      #
      attr_reader :constant_name

      ##
      # @return [boolean] Whether the file exists
      #
      def exists?
        ::File.file?(path)
      end

      ##
      # @return [String] Current contents of the file
      #
      def content
        ::File.read(@path)
      end

      ##
      # @return [::Gem::Version,nil] Current latest version from the file
      #
      def current_version
        VersionRbFile.current_version_from_content(content)
      end

      ##
      # Attempt to evaluate the current version by evaluating Ruby.
      #
      # @return [::Gem::Version,nil] Current version, or nil if failed
      #
      def eval_version
        joined_constant = constant_name.join("::")
        script = "load #{path.inspect}; puts #{joined_constant}"
        output = @utils.capture_ruby(script, err: :null).strip
        output.empty? ? nil : ::Gem::Version.new(output)
      end

      ##
      # Update the file to reflect a new version.
      #
      # @param version [String,::Gem::Version] The release version.
      #
      def update_version(version)
        new_content = content.sub(/VERSION\s*=\s*"(\d+(?:\.[a-zA-Z0-9]+)+)"/,
                                  "VERSION = \"#{version}\"")
        ::File.write(path, new_content)
        self
      end

      ##
      # Returns the current version from the given file content
      #
      # @param content [String] File contents
      # @return [::Gem::Version] Latest version in the changelog
      # @return [nil] if no version was found
      #
      def self.current_version_from_content(content)
        match = /VERSION\s*=\s*"(\d+(?:\.[a-zA-Z0-9]+)+)"/.match(content)
        match ? ::Gem::Version.new(match[1]) : nil
      end
    end
  end
end
