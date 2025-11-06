# frozen_string_literal: true

require_relative "semver"

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
      ResolvedComponent = ::Struct.new :component_name, :change_set, :last_version, :version

      ##
      # Create an empty request.
      #
      # @param environment_utils [Toys::Release::EnvironmentUtils]
      #
      def initialize(environment_utils)
        @utils = environment_utils
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
      # @return [boolean] Whether the request is empty, i.e. has no changed
      #     components
      #
      def empty?
        resolved_components.empty?
      end

      ##
      # @return [boolean] Whether the request is for a single component
      #
      def single_component?
        resolved_components.size == 1
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
      # @param component_name [String,:all] The name of the component to release
      # @param version [::Gem::Version,Toys::Release::Semver,String,Symbol,nil]
      #     The version to release, or the kind of version bump to use. If `nil`
      #     (the default), infers a version bump from the changeset, and omits
      #     the component if no release is needed.
      #
      def add(component_name, version: nil)
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
        if @requested_components[component_name] && @requested_components[component_name] != version
          @utils.error("Requested release of #{component_name.inspect} twice with different versions")
        else
          @requested_components[component_name] = version
        end
        self
      end

      ##
      # Resolve which components and versions to release.
      #
      # @param repository [Toys::Release::Repository]
      # @param release_ref [String,nil] Git ref at which the release should be
      #     cut. If nil, uses the current HEAD.
      #
      def resolve_versions(repository, release_ref: nil)
        raise "Release request already resolved" if resolved?
        @utils.accumulate_errors("Conflicts detected in the components and versions requested.") do
          @release_sha = repository.current_sha(release_ref)
          candidate_groups = determine_candidate_groups(repository)
          @resolved_components = []
          candidate_groups.each do |group, version|
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

      ##
      # Determines candidate groups, groups that could be released based on the
      # release request alone (but we haven't yet checked commits.) Thus, the
      # actual released groups will be a subset of this.
      #
      def determine_candidate_groups(repository)
        candidate_groups = {}
        if @requested_components.empty?
          repository.coordination_groups.each { |group| candidate_groups[group] = nil }
        else
          @requested_components.each do |component_name, version|
            component = repository.component_named(component_name)
            unless component
              @utils.error("Unknown component name #{component_name.inspect}")
              next
            end
            group = component.coordination_group
            group.each do |elem|
              elem_name = elem.name
              elem_version = @requested_components[elem_name]
              if elem != component && version && elem_version && elem_version != version
                @utils.error("#{component_name} #{version} implies #{elem_name} #{version} but " \
                            "#{elem_name} #{elem_version} was already requested.")
              end
              candidate_groups[group] ||= version
            end
          end
        end
        candidate_groups
      end

      ##
      # Resolves one candidate group. Returns an array of resolved components
      # along with the version to release for the group.
      #
      def resolve_one_group(group, version)
        suggested_next_version = nil
        resolved_group = group.map do |component|
          last_version = component.latest_tag_version(ref: @release_sha)
          if last_version && version.is_a?(::Gem::Version) && last_version >= version
            @utils.error("Requested #{component.name} #{version} but #{last_version} is the latest.")
          end
          latest_tag = component.version_tag(last_version)
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
