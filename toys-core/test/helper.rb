# frozen_string_literal: true

require "minitest/autorun"
require "minitest/focus"
require "minitest/mock"
require "minitest/rg"
require "toys-core"
require "toys/utils/exec"

module Toys
  module TestHelper
    def isolate_ruby
      lib_path = ::File.join(::File.dirname(__dir__), "lib")
      executor = Toys::Utils::Exec.new
      executor.exec_ruby([], in: :controller) do |controller|
        controller.in.puts "$LOAD_PATH.unshift(#{lib_path.inspect})"
        yield controller.in
      end
    end

    ##
    # Assert that the given actual value is the expansion of the given absolute
    # path. On Unix-like systems, expanding an absolute path leaves it alone,
    # but on Windows it also prepends the drive letter of the current working
    # directory, so "/my/dir" may expand to something like "D:/my/dir". This
    # assertion accepts either form, with any drive letter.
    #
    def assert_expanded_path(expected, actual, message = nil)
      expected = expected.to_s
      pattern = /\A(?:[a-zA-Z]:)?#{::Regexp.escape(expected)}\z/
      message ||= "Expected #{actual.inspect} to be an expansion of #{expected.inspect}"
      assert_match(pattern, actual, message)
    end
  end
end

::Minitest::Test.include(::Toys::TestHelper)
