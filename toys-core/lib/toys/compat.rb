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
  ##
  # Compatibility wrappers for older Ruby versions.
  # @private
  #
  module Compat
    ## @private
    CURRENT_VERSION = ::Gem::Version.new(::RUBY_VERSION)

    ## @private
    IS_JRUBY = ::RUBY_PLATFORM == "java"

    ## @private
    def self.check_minimum_version(version)
      CURRENT_VERSION >= ::Gem::Version.new(version)
    end

    if check_minimum_version("2.4.0")
      ## @private
      def self.suggestions(word, list)
        ::DidYouMean::SpellChecker.new(dictionary: list).correct(word)
      end
    else
      ## @private
      def self.suggestions(_word, _list)
        []
      end
    end

    if check_minimum_version("2.4.0")
      ## @private
      def self.merge_clones(hash, orig)
        orig.each { |k, v| hash[k] = v.clone }
        hash
      end
    else
      ## @private
      def self.merge_clones(hash, orig)
        orig.each do |k, v|
          hash[k] =
            begin
              v.clone
            rescue ::TypeError
              v
            end
        end
        hash
      end
    end

    if check_minimum_version("2.5.0")
      ## @private
      def self.glob_in_dir(glob, dir)
        ::Dir.glob(glob, base: dir)
      end
    else
      ## @private
      def self.glob_in_dir(glob, dir)
        ::Dir.chdir(dir) { ::Dir.glob(glob) }
      end
    end
  end
end
