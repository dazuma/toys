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
    def self.check_minimum_version(version)
      CURRENT_VERSION >= ::Gem::Version.new(version)
    end

    ## @private
    def self.jruby?
      ::RUBY_PLATFORM == "java"
    end

    ## @private
    def self.allow_fork?
      !jruby? && RbConfig::CONFIG["host_os"] !~ /mswin/
    end

    ## @private
    def self.supports_suggestions?
      defined?(::DidYouMean::SpellChecker)
    end

    # Check for DidYouMean::SpellChecker
    if supports_suggestions?
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

    # In Ruby < 2.4, some objects such as nil cannot be cloned.
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

    # The :base argument to Dir.glob requires Ruby 2.5 or later.
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

    # Due to a bug in Ruby < 2.7, passing an empty **kwargs splat to
    # initialize will fail if there are no formal keyword args.
    if check_minimum_version("2.7.0")
      ## @private
      def self.instantiate(klass, args, kwargs, block)
        klass.new(*args, **kwargs, &block)
      end
    else
      ## @private
      def self.instantiate(klass, args, kwargs, block)
        formals = klass.instance_method(:initialize).parameters
        if kwargs.empty? && formals.all? { |arg| arg.first != :key && arg.first != :keyrest }
          klass.new(*args, &block)
        else
          klass.new(*args, **kwargs, &block)
        end
      end
    end
  end
end
