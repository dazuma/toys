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

    # @private
    RUBY_VERSION_CODE = ruby_version

    # @private
    def self.jruby?
      ::RUBY_ENGINE == "jruby"
    end

    # @private
    def self.truffleruby?
      ::RUBY_ENGINE == "truffleruby"
    end

    # @private
    def self.windows?
      ::RbConfig::CONFIG["host_os"] =~ /mswin|msys|mingw|cygwin|bccwin|wince|emc/
    end

    # @private
    def self.macos?
      ::RbConfig::CONFIG["host_os"] =~ /darwin/
    end

    # @private
    def self.allow_fork?
      !jruby? && !truffleruby? && !windows?
    end

    # @private
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

    # @private
    def self.suggestions(word, list)
      if supports_suggestions?
        ::DidYouMean::SpellChecker.new(dictionary: list).correct(word)
      else
        []
      end
    end
  end
end
