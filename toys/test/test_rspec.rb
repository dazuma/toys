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
require "toys/utils/exec"

describe "rspec template" do
  let(:logger) {
    Logger.new(StringIO.new).tap do |lgr|
      lgr.level = Logger::WARN
    end
  }
  let(:binary_name) { "toys" }
  let(:cli) {
    Toys::CLI.new(
      binary_name: binary_name,
      logger: logger,
      middleware_stack: [],
      template_lookup: Toys::ModuleLookup.new.add_path("toys/templates")
    )
  }
  let(:loader) { cli.loader }
  let(:executor) { Toys::Utils::Exec.new(out: :capture, err: :capture) }

  it "executes a successful spec" do
    loader.add_block do
      expand :rspec, libs: File.join(__dir__, "rspec-cases", "lib1"),
                     pattern: File.join(__dir__, "rspec-cases", "spec", "*_spec.rb")
    end
    result = executor.exec_proc(proc { exit cli.run("spec") })
    assert(result.success?)
    assert_match(/1 example, 0 failures/, result.captured_out)
  end

  it "executes an unsuccessful spec" do
    loader.add_block do
      expand :rspec, libs: File.join(__dir__, "rspec-cases", "lib2"),
                     pattern: File.join(__dir__, "rspec-cases", "spec", "*_spec.rb")
    end
    result = executor.exec_proc(proc { exit cli.run("spec") })
    assert(result.error?)
    assert_match(/1 example, 1 failure/, result.captured_out)
  end
end
