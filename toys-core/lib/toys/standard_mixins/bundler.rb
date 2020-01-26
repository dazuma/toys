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
    # Ensures that a bundle is installed and set up when this tool is run.
    #
    # The following parameters can be passed when including this mixin:
    #
    #  *  `:groups` (Array<String>) The groups to include in setup
    #
    #  *  `:search_dirs` (Array<String,Symbol>) Directories to search for a
    #     Gemfile.
    #
    #     You can either pass a full directory path, or one of the following:
    #      *  `:context` - the current context directory (default)
    #      *  `:current` - the current working directory
    #
    #  *  `:on_missing` (Symbol) What to do if a needed gem is not installed.
    #
    #     Supported values:
    #      *  `:confirm` - prompt the user on whether to install (default)
    #      *  `:error` - raise an exception
    #      *  `:install` - just install the gem
    #
    #  *  `:on_conflict` (Symbol) What to do if bundler has already been run
    #     with a different Gemfile.
    #
    #     Supported values:
    #      *  `:error` - raise an exception (default)
    #      *  `:ignore` - just silently proceed without bundling again
    #      *  `:warn` - print a warning and proceed without bundling again
    #
    #  *  `:terminal` (Toys::Utils::Terminal) Terminal to use (optional)
    #  *  `:input` (IO) Input IO (optional, defaults to STDIN)
    #  *  `:output` (IO) Output IO (optional, defaults to STDOUT)
    #
    module Bundler
      include Mixin

      on_initialize do
        |groups: nil,
         search_dirs: nil,
         on_missing: nil,
         on_conflict: nil,
         terminal: nil,
         input: nil,
         output: nil|
        require "toys/utils/gems"
        search_dirs = ::Toys::StandardMixins::Bundler.resolve_search_dirs(search_dirs, self)
        gems = ::Toys::Utils::Gems.new(on_missing: on_missing, on_conflict: on_conflict,
                                       terminal: terminal, input: input, output: output)
        gems.bundle(groups: groups, search_dirs: search_dirs)
      end

      ## @private
      def self.resolve_search_dirs(search_dirs, context)
        Array(search_dirs || :context).map do |dir|
          case dir
          when :context
            context[::Toys::Context::Key::CONTEXT_DIRECTORY]
          when :current
            ::Dir.getwd
          when ::String
            dir
          else
            raise ::ArgumentError, "Unrecognized search_dir: #{dir.inspect}"
          end
        end
      end
    end
  end
end
