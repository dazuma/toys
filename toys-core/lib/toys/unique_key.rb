# frozen_string_literal: true

module Toys
  ##
  # A named unique key, useful for {Toys::Context} keys or sentinels.
  #
  # Each individual instance of this class is unique and not equal to any other
  # instance, even if they have the same user-visible name.
  #
  class UniqueKey
    ##
    # Create a new UniqueKey.
    #
    # @param name [String,nil] Optional name. If not passed, a default is
    #     constructed using the object ID.
    #
    def initialize(name = nil)
      # Interpolated literals are frozen on Ruby 2.7 but not on 3.0+, so this
      # freeze is required despite what RuboCop's 2.7 target thinks.
      @name = name ? -name : "(unnamed unique key #{object_id})".freeze # rubocop:disable Style/RedundantFreeze
      freeze
    end

    ##
    # @return [String] a user-visible name of this key
    #
    def to_s
      @name
    end

    ##
    # @return [String] a user-visible name of this key
    #
    def inspect
      @name
    end
  end
end
