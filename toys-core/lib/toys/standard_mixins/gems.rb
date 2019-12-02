# frozen_string_literal: true

# Copyright 2019 Daniel Azuma
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.
;

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
    #     include :gems, output: $stdout, default_confirm: false
    #
    # This is a frontend for {Toys::Utils::Gems}. More information is
    # available in that class's documentation.
    #
    module Gems
      include Mixin

      on_include do |opts = {}|
        @__gems_opts = opts

        ## @private
        def self.gems
          require "toys/utils/gems"
          # rubocop:disable Naming/MemoizedInstanceVariableName
          @__gems ||= Utils::Gems.new(**@__gems_opts)
          # rubocop:enable Naming/MemoizedInstanceVariableName
        end

        ## @private
        def self.gem(name, *requirements)
          gems.activate(name, *requirements)
        end
      end

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
    end
  end
end