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

describe Toys::Definition::Arg do
  let(:arg) {
    Toys::Definition::Arg.new(
      "hello-there!", :required, Integer, -1, "description", ["long", "description"]
    )
  }

  it "passes through attributes" do
    assert_equal("hello-there!", arg.key)
    assert_equal(:required, arg.type)
    assert_equal(Integer, arg.accept)
    assert_equal(-1, arg.default)
  end

  it "computes descriptions" do
    assert_equal(Toys::WrappableString.new("description"), arg.desc)
    assert_equal([Toys::WrappableString.new("long"),
                  Toys::WrappableString.new("description")], arg.long_desc)
  end

  it "computes display name" do
    assert_equal("HELLO_THERE", arg.display_name)
  end

  it "processes the value through the acceptor" do
    assert_equal(32, arg.process_value("32"))
    assert_raises(::OptionParser::InvalidArgument) do
      arg.process_value("blah")
    end
  end
end
