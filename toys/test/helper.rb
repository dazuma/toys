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
    TOYS_EXECUTABLE = ::File.join(::File.dirname(__dir__), "bin", "toys")

    ##
    # Execute toys and capture the result
    #
    def self.capture_toys(*args, stream: :out)
      executor = Toys::Utils::Exec.new
      executable = ::File.join(::File.dirname(__dir__), "bin", "toys")
      cmd = [::RbConfig.ruby, "--disable=gems", executable] + args
      env = { "TOYS_DEV" => "true" }
      result = executor.exec(cmd, out: :capture, err: :capture, env: env)
      str = stream == :err ? result.captured_err : result.captured_out
      str.to_s
    end

    ##
    # Execute completion and capture the result
    #
    def self.capture_completion(line)
      executor = Toys::Utils::Exec.new
      executable = ::File.join(::File.dirname(__dir__), "bin", "toys")
      cmd = [::RbConfig.ruby, "--disable=gems", executable, "system", "bash-completion", "eval"]
      env = { "COMP_LINE" => line, "COMP_POINT" => "-1", "TOYS_DEV" => "true" }
      str = executor.capture(cmd, env: env)
      str.split("\n")
    end
  end
end
