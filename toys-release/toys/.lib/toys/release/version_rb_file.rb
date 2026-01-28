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
      # @param environment_utils [Toys::Release::EnvironmentUtils]
      #
      def initialize(path, environment_utils)
        @path = path
        @utils = environment_utils
      end

      ##
      # @return [String] Path to the version file
      #
      attr_reader :path

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
      # Update the file to reflect a new version.
      #
      # @param version [String,::Gem::Version] The release version.
      #
      def update_version(version)
        @utils.log("Updating #{path} to set VERSION=#{version}")
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
