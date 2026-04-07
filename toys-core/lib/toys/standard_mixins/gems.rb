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
    # ### Usage
    #
    # Make these methods available to your tool by including this mixin in your
    # tool:
    #
    #     include :gems
    #
    # You can then call the mixin method {#gem} to ensure that a gem is
    # installed and in the load path. For example:
    #
    #     tool "my_tool" do
    #       include :gems
    #       def run
    #         gem "nokogiri", "~> 1.15"
    #         # Do stuff with Nokogiri
    #       end
    #     end
    #
    # If you pass additional options to the include directive, those are used
    # to initialize settings for the gem install process. For example:
    #
    #     include :gems, on_missing: :error
    #
    # You can also pass options to the {#gem} mixin method itself:
    #
    #     tool "my_tool" do
    #       include :gems
    #       def run
    #         # If the gem is not installed, error out instead of asking to
    #         # install it.
    #         gem "nokogiri", "~> 1.15", on_missing: :error
    #         # Do stuff with Nokogiri
    #       end
    #     end
    #
    # See {Toys::Utils::Gems#initialize} for a list of supported options.
    #
    module Gems
      include Mixin

      ##
      # Context key for the tool-wide {Toys::Utils::Gems} object.
      # @return [Object]
      #
      KEY = ::Object.new.freeze

      ##
      # Returns a tool-wide instance of {Toys::Utils::Gems}.
      # @return [Toys::Utils::Gems]
      #
      def gems
        self[::Toys::StandardMixins::Gems::KEY]
      end

      ##
      # Activate the given gem. If it is not present, attempt to install it (or
      # inform the user to update the bundle).
      #
      # @param name [String] Name of the gem
      # @param requirements [String...] Version requirements
      # @param options [keywords] Additional options to pass to the
      #     {Toys::Utils::Gems} constructor
      #
      # @return [:activated] if the gem was activated
      # @return [:installed] if the gem was installed and activated
      # @return [false] if the gem had already been activated
      #
      # @raise [ActivationFailedError] if activation or install failed
      #
      def gem(name, *requirements, **options)
        gems_util = options.empty? ? gems : Utils::Gems.new(**options)
        gems_util.activate(name, *requirements)
      end

      ##
      # This module extends the tool class when you include the Gems mixin,
      # so that the `gems` and `gem` directives defined in this module are
      # available.
      #
      module ClassMethods
        ##
        # Returns a tool-wide instance of {Toys::Utils::Gems}.
        # @return [Toys::Utils::Gems]
        #
        def gems
          @__default_gems_util
        end

        ##
        # Activate the given gem. If it is not present, attempt to install it
        # (or inform the user to update the bundle).
        #
        # @param name [String] Name of the gem
        # @param requirements [String...] Version requirements
        # @param options [keywords] Additional options to pass to the
        #     {Toys::Utils::Gems} constructor
        #
        # @return [:activated] if the gem was activated
        # @return [:installed] if the gem was installed and activated
        # @return [false] if the gem had already been activated
        #
        # @raise [ActivationFailedError] if activation or install failed
        #
        def gem(name, *requirements, **options)
          gems_util = options.empty? ? gems : Utils::Gems.new(**options)
          gems_util.activate(name, *requirements)
        end
      end

      # Install the class methods and set up the needed object references
      on_include do |**opts|
        require "toys/utils/gems"
        @__default_gems_util = Utils::Gems.new(**opts)
        set(::Toys::StandardMixins::Gems::KEY, @__default_gems_util)
        extend(::Toys::StandardMixins::Gems::ClassMethods) unless is_a?(::Toys::StandardMixins::Gems::ClassMethods)
      end
    end
  end
end
