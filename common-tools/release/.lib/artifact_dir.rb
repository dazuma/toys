# frozen_string_literal: true

require "fileutils"
require "tmpdir"

module ToysReleaser
  ##
  # Object that manages an artifact directory
  #
  class ArtifactDir
    def initialize(base_dir = nil)
      @base_dir = base_dir
      @needs_cleanup = false
      @initialized = {}
    end

    def get(name = nil)
      dir_name = name ? "#{name}-#{random_id}" : random_id
      path = ::File.join(base_dir, dir_name)
      unless @initialized[path]
        @initialized[path] = true
        ::FileUtils.remove_entry(path, true)
        ::FileUtils.mkdir_p(path)
      end
      path
    end

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
