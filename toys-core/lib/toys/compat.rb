# frozen_string_literal: true

require "rbconfig"

module Toys
  ##
  # Compatibility wrappers for certain Ruby implementations and versions, and
  # other environment differences.
  #
  # @private
  #
  module Compat
    parts = ::RUBY_VERSION.split(".")
    ruby_version = (parts[0].to_i * 10000) + (parts[1].to_i * 100) + parts[2].to_i

    ##
    # @private
    # An integer representation of the Ruby version, guaranteed to have the
    # correct ordering. Currently, this is `major*10000 + minor*100 + patch`.
    #
    # @return [Integer]
    #
    RUBY_VERSION_CODE = ruby_version

    ##
    # @private
    # Whether the current Ruby implementation is JRuby
    #
    # @return [boolean]
    #
    def self.jruby?
      ::RUBY_ENGINE == "jruby"
    end

    ##
    # @private
    # Whether the current Ruby implementation is TruffleRuby
    #
    # @return [boolean]
    #
    def self.truffleruby?
      ::RUBY_ENGINE == "truffleruby"
    end

    ##
    # @private
    # Whether we are running on Windows
    #
    # @return [boolean]
    #
    def self.windows?
      ::RbConfig::CONFIG["host_os"] =~ /mswin|msys|mingw|cygwin|bccwin|wince|emc/
    end

    ##
    # @private
    # Whether we are running on Mac OS
    #
    # @return [boolean]
    #
    def self.macos?
      ::RbConfig::CONFIG["host_os"] =~ /darwin/
    end

    ##
    # @private
    # Whether fork is supported on the current Ruby and OS
    #
    # @return [boolean]
    #
    def self.allow_fork?
      !jruby? && !truffleruby? && !windows?
    end

    ##
    # @private
    # Whether it is possible to get suggestions from DidYouMean. If this
    # returns false, {Compat.suggestions} will always return the empty array.
    #
    # @return [boolean]
    #
    def self.supports_suggestions?
      unless defined?(@supports_suggestions)
        begin
          require "did_you_mean"
        rescue ::LoadError
          require "rubygems"
          begin
            require "did_you_mean"
          rescue ::LoadError
            # Oh well, it's not available
          end
        end
        @supports_suggestions = defined?(::DidYouMean::SpellChecker)
      end
      @supports_suggestions
    end

    ##
    # @private
    # A list of suggestions from DidYouMean.
    #
    # @param word [String] A value that seems wrong
    # @param list [Array<String>] A list of valid values
    #
    # @return [Array<String>] A possibly empty array of suggestions from the
    #     valid list that could match the given word.
    #
    def self.suggestions(word, list)
      if supports_suggestions?
        ::DidYouMean::SpellChecker.new(dictionary: list).correct(word)
      else
        []
      end
    end

    ##
    # @private
    # A list of gems that should generally not be included in a bundle, usually
    # because the Ruby implementation handles the library specially and cannot
    # install the real gem. Currently, this includes the `pathname` gem for
    # TruffleRuby, since TruffleRuby includes a special version of it.
    #
    # @return [Array<String>]
    #
    def self.gems_to_omit_from_bundles
      if truffleruby?
        ["pathname"]
      else
        []
      end
    end
  end
end
