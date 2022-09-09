# frozen_string_literal: true

module Toys
  module StandardMixins
    ##
    # A mixin that provides a pager.
    #
    # This mixin provides an instance of {Toys::Utils::Pager}, which invokes
    # an external pager for output.
    #
    # @example
    #
    #   include :pager
    #
    #   def run
    #     pager do |io|
    #       io.puts "A long string\n"
    #     end
    #   end
    #
    module Pager
      include Mixin

      ##
      # Context key for the Pager object.
      # @return [Object]
      #
      KEY = ::Object.new.freeze

      ##
      # Access the Pager.
      #
      # If *no* block is given, returns the pager object.
      #
      # If a block is given, the pager is executed with the given block, and
      # the exit code of the pager process is returned.
      #
      # @return [Toys::Utils::Pager] if no block is given.
      # @return [Integer] if a block is given.
      #
      def pager(&block)
        pager = self[KEY]
        return pager unless block
        self[KEY].start(&block)
      end

      on_initialize do
        require "toys/utils/pager"
        exec_service =
          if defined?(::Toys::StandardMixins::Exec)
            self[::Toys::StandardMixins::Exec::KEY]
          end
        self[KEY] = Utils::Pager.new(exec_service: exec_service)
      end
    end
  end
end
