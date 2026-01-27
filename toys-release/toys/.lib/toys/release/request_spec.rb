# frozen_string_literal: true

require "toys/release/semver"

module Toys
  module Release
    ##
    # Represents a release request specification.
    #
    class RequestSpec
      ##
      # Details about the resolved request for a particular component
      #
      # @!attribute [r] component_name
      #   @return [String]
      #
      # @!attribute [r] change_set
      #   @return [Toys::Release::ChangeSet]
      #
      # @!attribute [r] last_version
      #   @return [::Gem::Version, nil]
      #
      # @!attribute [r] version
      #   @return [::Gem::Version]
      #
      ResolvedComponent = ::Struct.new(:component_name, :change_set, :last_version, :version)

      ##
      # Create an empty request.
      #
      # @param utils [Toys::Release::EnvironmentUtils]
      #
      def initialize(utils)
        @utils = utils
        @resolved_components = nil
        @requested_components = {}
        @release_sha = nil
      end

      ##
      # @return [boolean] Whether the request has been resolved.
      #
      def resolved?
        !@resolved_components.nil?
      end

      ##
      # @return [boolean,nil] Whether the request is empty, i.e. has no changed
      #     components. Returns nil if the request spec is not yet resolved.
      #
      def empty?
        return nil unless resolved?
        resolved_components.empty?
      end

      ##
      # @return [boolean,nil] Whether the request is for a single component.
      #     Returns nil if the request spec is not yet resolved.
      #
      def single_component?
        return nil unless resolved?
        resolved_components.size == 1
      end

      ##
      # @return [Hash{String=>(String,nil)}]
      #     The component releases requested (including indirectly via
      #     coordination group). This hash will always be consistent according
      #     to the coordination groups.
      #
      def serializable_requested_components
        @requested_components.to_h { |component, version| [component.name, version&.to_s] }
      end

      ##
      # @return [Array<ResolvedComponent>] Info about the components to release.
      #     Valid only after resolution.
      #
      attr_reader :resolved_components

      ##
      # @return [String] The git SHA at which the release will be cut.
      #     Valid only after resolution.
      #
      attr_reader :release_sha

      ##
      # Add a component and version constraint.
      #
      # @param component [Toys::Release::Component] The component to release
      # @param version [::Gem::Version,Toys::Release::Semver,String,Symbol,nil]
      #     The version to release, or the kind of version bump to use. If `nil`
      #     (the default), infers a version bump from the changeset, and omits
      #     the component if no release is needed.
      #
      def add(component, version: nil)
        raise "Release request already resolved" if resolved?
        version = normalize_version(version)
        existing_version = @requested_components[component]
        if existing_version && existing_version != version
          @utils.error("Requested release of #{component.name} #{version} but #{existing_version} already requested")
          return
        end
        component.coordination_group.each do |comp|
          @requested_components[comp] ||= version
        end
        self
      end

      ##
      # Resolve which components and versions to release.
      #
      # @param release_sha [String] Git ref at which the release should be cut
      #
      def resolve_versions(release_sha)
        raise "Release request already resolved" if resolved?
        @utils.log("Resolving a request spec.")
        @utils.accumulate_errors("Conflicts detected in the components and versions requested.") do
          @release_sha = release_sha
          grouped_requests = {}
          @requested_components.each do |component, version|
            grouped_requests[component.coordination_group] ||= version
          end
          @resolved_components = []
          grouped_requests.each do |group, version|
            resolved_group, version = resolve_one_group(group, version)
            if version
              resolved_group.each do |resolved_component|
                resolved_component.version = version
                resolved_component.change_set.force_release!
              end
              @resolved_components.concat(resolved_group)
            end
          end
        end
        self
      end

      private

      def normalize_version(version)
        if !version.nil? && !version.is_a?(::Gem::Version) && !version.is_a?(Semver)
          version_str = version.to_s
          version = if version_str =~ /^\d/
                      ::Gem::Version.new(version_str)
                    else
                      Semver.for_name(version_str)
                    end
          @utils.error("Malformed version or semver name: #{version_str}") unless version
        end
        @utils.error("Cannot release with no version change") if version == Semver::NONE
        version
      end

      ##
      # Resolves one candidate group. Returns an array of resolved components
      # along with the version to release for the group.
      #
      def resolve_one_group(group, version)
        suggested_next_version = nil
        resolved_group = group.map do |component|
          @utils.log("Resolving component #{component.name}")
          last_version = component.latest_tag_version(ref: @release_sha)
          if last_version && version.is_a?(::Gem::Version) && last_version >= version
            @utils.error("Requested #{component.name} #{version} but #{last_version} is the latest.")
          end
          latest_tag = component.version_tag(last_version)
          @utils.log("Creating changeset from #{latest_tag} to #{@release_sha}")
          changeset = component.make_change_set(from: latest_tag, to: @release_sha)
          unless version.is_a?(::Gem::Version)
            cur_suggested = version ? version.bump(last_version) : changeset.suggested_version(last_version)
            if suggested_next_version.nil? || (cur_suggested && cur_suggested > suggested_next_version)
              suggested_next_version = cur_suggested
            end
          end
          ResolvedComponent.new(component.name, changeset, last_version, nil)
        end
        [resolved_group, suggested_next_version || version]
      end
    end
  end
end
