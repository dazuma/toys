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

      on_include do
        require "fileutils"
        if respond_to?(:include_module)
          include_module(::FileUtils)
        else
          include(::FileUtils)
        end
      end
    end
  end
end
