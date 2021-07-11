# frozen_string_literal: true

require "fileutils"

module Toys
  module StandardMixins
    ##
    # A mixin that provides tools for working with the XDG Base Directory
    # Specification.
    #
    # This mixin provides an instance of {Toys::Utils::XDG}, which includes
    # utility methods that locate base directories and search paths for
    # application state, configuration, caches, and other data, according to
    # the [XDG Base Directory Spec version
    # 0.8](https://specifications.freedesktop.org/basedir-spec/0.8/).
    #
    # Example usage:
    #
    #     include :xdg
    #
    #     def run
    #       # Get config file paths, in order from most to least inportant
    #       config_files = xdg.lookup_config("my-config.toml")
    #       config_files.each { |path| read_my_config(path) }
    #     end
    #
    module XDG
      include Mixin

      ##
      # Context key for the XDG object.
      # @return [Object]
      #
      KEY = ::Object.new.freeze

      on_initialize do
        require "toys/utils/xdg"
        self[KEY] = Utils::XDG.new
      end

      ##
      # Access XDG utility methods.
      #
      # @return [Toys::Utils::XDG]
      #
      def xdg
        self[KEY]
      end
    end
  end
end
