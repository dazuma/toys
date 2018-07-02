# frozen_string_literal: true

# Copyright 2018 Daniel Azuma
#
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice,
#   this list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# * Neither the name of the copyright holder, nor the names of any other
#   contributors to this software, may be used to endorse or promote products
#   derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
;

require "helper"

describe "toys" do
  it "prints general help" do
    output = Toys::TestHelper.capture_toys.split("\n")
    assert_equal("NAME", output[0])
    assert_equal("    toys - Your personal command line tool", output[1])
  end

  it "prints toys version when passed --version flag" do
    output = Toys::TestHelper.capture_toys("--version")
    assert_equal(Toys::VERSION, output.strip)
  end
end

describe "toys system" do
  it "prints help" do
    output = Toys::TestHelper.capture_toys("system").split("\n")
    assert_equal("NAME", output[0])
    assert_equal("    toys system - A set of system commands for Toys", output[1])
  end
end

describe "toys system version" do
  it "prints the system version" do
    output = Toys::TestHelper.capture_toys("system", "version")
    assert_equal(Toys::VERSION, output.strip)
  end

  it "prints help when passed --help flag" do
    output = Toys::TestHelper.capture_toys("system", "version", "--help").split("\n")
    assert_equal("NAME", output[0])
    assert_equal("    toys system version - Print the current Toys version", output[1])
  end
end

describe "toys do" do
  it "prints help when passed --help flag" do
    output = Toys::TestHelper.capture_toys("do", "--help").split("\n")
    assert_equal("NAME", output[0])
    assert_equal("    toys do - Run multiple tools in order", output[1])
  end

  it "does nothing when passed no arguments" do
    output = Toys::TestHelper.capture_toys("do")
    assert_equal("", output)
  end

  it "executes multiple tools" do
    output = Toys::TestHelper.capture_toys("do", "system", "version", ",", "system").split("\n")
    assert_equal(Toys::VERSION, output[0])
    assert_equal("NAME", output[1])
    assert_equal("    toys system - A set of system commands for Toys", output[2])
  end
end
