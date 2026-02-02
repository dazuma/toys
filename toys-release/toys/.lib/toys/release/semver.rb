# frozen_string_literal: true

module Toys
  module Release
    ##
    # A semver level
    #
    class Semver
      class << self
        ##
        # Return the semver level for the given name.
        #
        # @param name [String,Symbol] The name
        # @return [Semver] The semver level
        # @return [nil] If the name is not recognized
        #
        def for_name(name)
          @name_mapping[name.to_s.downcase]
        end

        ##
        # Return the semver level of the change between the given versions.
        # If the change is less significant than PATCH2, PATCH2 is returned.
        # If the versions are identical, NONE is returned.
        #
        # @param version1 [Gem::Version,String] The before version
        # @param version2 [Gem::Version,String] The after version
        # @return [Semver] The semver level
        #
        def for_diff(version1, version2)
          segments1 = Gem::Version.create(version1).segments
          segments2 = Gem::Version.create(version2).segments
          size = segments1.size
          size = segments2.size if size < segments2.size
          (0...size).each do |index|
            return @segment_mapping[index] || PATCH2 unless segments1[index].to_i == segments2[index].to_i
          end
          NONE
        end
      end

      include ::Comparable

      ##
      # @return [Symbol] The name of this semver level
      #
      attr_reader :name

      ##
      # @return [Integer,nil] Which version segment to bump (0 is major), or
      #     nil for the "none" level.
      #
      attr_reader :segment

      ##
      # @return [boolean] Whether this semver implies any change
      #
      def significant?
        !segment.nil?
      end

      ##
      # @return [String] The name of this semver level as a string
      #
      def to_s
        name.to_s
      end

      ##
      # Bump the given version.
      #
      # @param version [::Gem::Version] The original version
      # @return [::Gem::Version] The new version
      #
      def bump(version)
        return version if segment.nil?
        bump_seg = segment
        version_segs = version&.segments || [0, 0, 0]
        max_seg = bump_seg
        max_seg = 2 if max_seg < 2
        version_segs = version_segs[0..max_seg]
        bump_seg = 1 if bump_seg.zero? && version_segs[0].zero?
        version_segs[bump_seg] += 1
        ::Gem::Version.new(version_segs.fill(0, bump_seg + 1).join("."))
      end

      ##
      # Returns the max of this semver or the argument
      #
      # @param other [Semver] Another semver to compare with this
      # @return [Semver] The more significant semver
      #
      def max(other)
        other.segment_for_comparison < segment_for_comparison ? other : self
      end

      # @private
      def initialize(name, segment)
        @name = name
        @segment = segment
      end

      # @private
      def <=>(other)
        other.segment_for_comparison <=> segment_for_comparison
      end

      # @private
      def segment_for_comparison
        segment || 99
      end

      ##
      # Major version bump
      #
      MAJOR = new(:major, 0)

      ##
      # Minor version bump
      #
      MINOR = new(:minor, 1)

      ##
      # Patch version bump
      #
      PATCH = new(:patch, 2)

      ##
      # Patch2 version bump
      #
      PATCH2 = new(:patch2, 3)

      ##
      # No version bump
      #
      NONE = new(:none, nil)

      @name_mapping = {
        "major" => MAJOR,
        "minor" => MINOR,
        "patch" => PATCH,
        "patch2" => PATCH2,
        "none" => NONE,
      }
      @segment_mapping = [
        MAJOR,
        MINOR,
        PATCH,
        PATCH2,
      ]
    end
  end
end
