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
