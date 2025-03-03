# frozen_string_literal: true

module ToysReleaser
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

    # @private
    def initialize(name, segment)
      @name = name
      @segment = segment
    end

    # @private
    def <=>(other)
      (other.segment || 99) <=> (segment || 99)
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
  end
end
