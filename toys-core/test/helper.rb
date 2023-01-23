# frozen_string_literal: true

require "minitest/autorun"
require "minitest/focus"
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
  end
end
