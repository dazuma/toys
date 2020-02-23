# frozen_string_literal: true

require "minitest/autorun"
require "minitest/focus"
require "minitest/rg"
require "toys"
require "shellwords"
require "toys/utils/exec"

module Toys
  ##
  # Helpers for tests
  #
  module TestHelper
    ## Name of the local dev executable
    TOYS_EXECUTABLE = ::File.join(::File.dirname(::File.dirname(__dir__)), "toys-dev")

    ##
    # Execute toys and capture the result
    #
    def self.capture_toys(*args, stream: :out)
      executor = Toys::Utils::Exec.new
      result = executor.exec([TOYS_EXECUTABLE] + args, out: :capture, err: :capture)
      str = stream == :err ? result.captured_err : result.captured_out
      str.to_s
    end

    ##
    # Execute completion and capture the result
    #
    def self.capture_completion(line)
      executor = Toys::Utils::Exec.new
      str = executor.capture([TOYS_EXECUTABLE, "system", "bash-completion", "eval"],
                             env: {"COMP_LINE" => line, "COMP_POINT" => "-1"})
      str.split("\n")
    end
  end
end
