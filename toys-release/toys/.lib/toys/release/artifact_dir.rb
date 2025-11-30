# frozen_string_literal: true

require "fileutils"
require "tmpdir"

module Toys
  module Release
    ##
    # Object that manages an artifact directory
    #
    class ArtifactDir
      ##
      # Create an ArtifactDir
      #
      # @param base_dir [String] Optional base directory, within which all the
      #     artifact directories will be created. If not provided, a temporary
      #     directory will be used.
      # @param auto_cleanup [boolean] Whether to cleanup automatically at_exit.
      #
      def initialize(base_dir = nil, auto_cleanup: false)
        @base_dir = base_dir
        @needs_cleanup = false
        @initialized = {}
        at_exit { cleanup } if auto_cleanup
      end

      ##
      # Get the path to a directory with a given name. All calls to get with
      # the same name will return the same directory path.
      #
      # @param name [String] Optional name. If not provided, a global default
      #     name is used.
      #
      def get(name = nil)
        dir_name = name ? "#{random_id}-#{name}" : random_id
        path = ::File.join(base_dir, dir_name)
        unless @initialized[path]
          @initialized[path] = true
          ::FileUtils.remove_entry(path, true)
          ::FileUtils.mkdir_p(path)
        end
        path
      end

      ##
      # Get the path to the output directory for the given step name.
      #
      # @param name [String] Step name
      #
      def output(name)
        get("out-#{name}")
      end

      ##
      # Get the path to the temp directory for the given step name.
      #
      # @param name [String] Step name
      #
      def temp(name)
        get("temp-#{name}")
      end

      ##
      # Perform cleanup, removing the directories if they were created under a
      # temporary directory.
      #
      def cleanup
        if @needs_cleanup
          ::FileUtils.remove_entry(@base_dir, true)
          @needs_cleanup = false
          @base_dir = nil
        end
      end

      private

      def base_dir
        unless @base_dir
          @base_dir = ::Dir.mktmpdir
          @needs_cleanup = true
        end
        @base_dir
      end

      def random_id
        @random_id ||= "#{rand(36**6).to_s(36)}#{::Time.now.to_i.to_s(36)}"
      end
    end
  end
end
