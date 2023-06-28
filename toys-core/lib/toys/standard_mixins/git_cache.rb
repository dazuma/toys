# frozen_string_literal: true

module Toys
  module StandardMixins
    ##
    # A mixin that provides a git cache.
    #
    # This mixin provides an instance of {Toys::Utils::GitCache}, providing
    # cached access to files from a remote git repo.
    #
    # @example
    #
    #   include :git_cache
    #
    #   def run
    #     # Pull and cache the HEAD commit from the Toys repo.
    #     dir = git_cache.get("https://github.com/dazuma/toys.git")
    #     # Display the contents of the readme file.
    #     puts File.read(File.join(dir, "README.md"))
    #   end
    #
    module GitCache
      include Mixin

      ##
      # Context key for the GitCache object.
      # @return [Object]
      #
      KEY = ::Object.new.freeze

      ##
      # Access the builtin GitCache.
      #
      # @return [Toys::Utils::GitCache]
      #
      def git_cache
        self[KEY]
      end

      on_initialize do
        require "toys/utils/git_cache"
        self[KEY] = Utils::GitCache.new
      end
    end
  end
end
