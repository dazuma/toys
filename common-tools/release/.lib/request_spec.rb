# frozen_string_literal: true

require_relative "semver"

module ToysReleaser
  ##
  # Represents a release request specification.
  #
  class RequestSpec
    ##
    # Details about the resolved request for a particular unit
    #
    # @!attribute [r] unit_name
    #   @return [String]
    #
    # @!attribute [r] change_set
    #   @return [ToysReleaser::ChangeSet]
    #
    # @!attribute [r] last_version
    #   @return [::Gem::Version, nil]
    #
    # @!attribute [r] version
    #   @return [::Gem::Version]
    #
    ResolvedUnit = ::Struct.new :unit_name, :change_set, :last_version, :version

    ##
    # Create an empty request.
    #
    # @param environment_utils [ToysReleaser::EnvironmentUtils]
    #
    def initialize(environment_utils)
      @utils = environment_utils
      @resolved_units = nil
      @requested_units = {}
      @release_sha = nil
    end

    ##
    # @return [boolean] Whether the request has been resolved.
    #
    def resolved?
      !@resolved_units.nil?
    end

    ##
    # @return [boolean] Whether the request is empty, i.e. has no changed units
    #
    def empty?
      resolved_units.empty?
    end

    def single_unit?
      resolved_units.size == 1
    end

    ##
    # @return [Array<ResolvedUnit>] Info about the units to release.
    #     Valid only after resolution.
    #
    attr_reader :resolved_units

    ##
    # @return [String] The git SHA at which the release will be cut.
    #     Valid only after resolution.
    #
    attr_reader :release_sha

    ##
    # Add a unit and version constraint.
    #
    # @param unit_name [String,:all] The name of the unit to release.
    # @param version [::Gem::Version,ToysReleaser::Semver,String,Symbol,nil]
    #     The version to release, or the kind of version bump to use. If `nil`
    #     (the default), infers a version bump from the changeset, and omits
    #     the unit if no release is needed.
    #
    def add(unit_name, version: nil)
      raise "Release request already resolved" if resolved?
      if !version.nil? && !version.is_a?(::Gem::Version) && !version.is_a?(Semver)
        name = version.to_s
        version = if name =~ /^\d/
                    ::Gem::Version.new(name)
                  else
                    Semver.for_name(name)
                  end
        @utils.error("Malformed version or semver name: #{name}") unless version
      end
      @utils.error("Cannot release with no version change") if version == Semver::NONE
      if @requested_units[unit_name] && @requested_units[unit_name] != version
        @utils.error("Requested release of #{unit_name.inspect} twice with different versions")
      else
        @requested_units[unit_name] = version
      end
      self
    end

    # rubocop:disable Metrics/AbcSize
    # rubocop:disable Metrics/MethodLength

    ##
    # Resolve which units and versions to release.
    #
    # @param repository [ToysReleaser::Repository]
    # @param release_ref [String,nil] Git ref at which the release should be
    #     cut. If nil, uses the current HEAD.
    #
    def resolve_versions(repository, release_ref: nil)
      raise "Release request already resolved" if resolved?
      @utils.accumulate_errors("Conflicts detected in the units and versions requested.") do
        @release_sha = repository.current_sha(release_ref)
        candidate_groups = determine_candidate_groups(repository)
        @resolved_units = []
        candidate_groups.each do |group, version|
          suggested_next_version = nil
          resolved_group = group.map do |unit|
            last_version = unit.latest_tag_version(ref: @release_sha)
            if last_version && version.is_a?(::Gem::Version) && last_version >= version
              @utils.error("Requested #{unit.name} #{version} but #{last_version} is the latest.")
            end
            latest_tag = unit.version_tag(last_version)
            changeset = unit.make_change_set(from: latest_tag, to: @release_sha)
            unless version.is_a?(::Gem::Version)
              cur_suggested = version ? version.bump(last_version) : changeset.suggested_version(last_version)
              if suggested_next_version.nil? || cur_suggested && cur_suggested > suggested_next_version
                suggested_next_version = cur_suggested
              end
            end
            ResolvedUnit.new(unit.name, changeset, last_version, nil)
          end
          version = suggested_next_version if suggested_next_version
          if version
            resolved_group.each do |resolved_unit|
              resolved_unit.version = version
              resolved_unit.change_set.force_release!
            end
            @resolved_units.concat(resolved_group)
          end
        end
      end
      self
    end

    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/MethodLength

    private

    ##
    # Determines candidate groups, groups that could be released based on the
    # release request alone (but we haven't yet checked commits.) Thus, the
    # actual released groups will be a subset of this.
    #
    def determine_candidate_groups(repository)
      candidate_groups = {}
      if @requested_units.empty?
        repository.coordination_groups.each { |group| candidate_groups[group] = nil }
      else
        @requested_units.each do |unit_name, version|
          unit = repository.releasable_unit(unit_name)
          unless unit
            @utils.error("Unknown releasable unit name #{unit_name.inspect}")
            next
          end
          group = unit.coordination_group
          group.each do |elem|
            elem_name = elem.name
            elem_version = @requested_units[elem_name]
            if elem != unit && version && elem_version && elem_version != version
              @utils.error("#{unit_name} #{version} implies #{elem_name} #{version} but " \
                           "#{elem_name} #{elem_version} was already requested.")
            end
            candidate_groups[group] ||= version
          end
        end
      end
      candidate_groups
    end
  end
end
