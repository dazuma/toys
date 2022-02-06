# frozen_string_literal: true

module Toys
  module StandardMixins
    ##
    # Provides methods for installing and activating third-party gems. When
    # this mixin is included, it provides a `gem` method that has the same
    # effect as {Toys::Utils::Gems#activate}, so you can ensure a gem is
    # present when running a tool. A `gem` directive is likewise added to the
    # tool DSL itself, so you can also ensure a gem is present when defining a
    # tool.
    #
    # You may make these methods available to your tool by including the
    # following directive in your tool configuration:
    #
    #     include :gems
    #
    # If you pass additional options to the include directive, those are used
    # to initialize settings for the gem install process. For example:
    #
    #     include :gems, on_missing: :error
    #
    # See {Toys::Utils::Gems#initialize} for a list of supported options.
    #
    module Gems
      include Mixin

      ##
      # A tool-wide instance of {Toys::Utils::Gems}.
      # @return [Toys::Utils::Gems]
      #
      def gems
        self.class.gems
      end

      ##
      # Activate the given gem.
      #
      # @param name [String] Name of the gem
      # @param requirements [String...] Version requirements
      # @return [void]
      #
      def gem(name, *requirements)
        self.class.gems.activate(name, *requirements)
      end

      on_include do |**opts|
        @__gems_opts = opts

        ##
        # @private
        #
        def self.gems
          require "toys/utils/gems"
          # rubocop:disable Naming/MemoizedInstanceVariableName
          @__gems ||= Utils::Gems.new(**@__gems_opts)
          # rubocop:enable Naming/MemoizedInstanceVariableName
        end

        ##
        # @private
        #
        def self.gem(name, *requirements)
          gems.activate(name, *requirements)
        end
      end
    end
  end
end
