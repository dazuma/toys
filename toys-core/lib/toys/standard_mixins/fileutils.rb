# frozen_string_literal: true

module Toys
  module StandardMixins
    ##
    # A module that provides all methods in the "fileutils" standard library.
    #
    # You may make the methods in the `FileUtils` standard library module
    # available to your tool by including the following directive in your tool
    # configuration:
    #
    #     include :fileutils
    #
    module Fileutils
      include Mixin

      ##
      # @private
      #
      def self.included(mod)
        require "fileutils"
        mod.include(::FileUtils)
      end
    end
  end
end
