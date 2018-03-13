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

module Toys
  module Templates
    Minitest = Struct.new(:name, :libs, :files, :warnings) do
      include Toys::Template

      def initialize(opts = {})
        super(opts[:name] || "test",
              opts[:libs] || ["lib"],
              opts[:files] || ["test/test*.rb"],
              opts.include?(:warnings) ? opts[:warnings] : true)
      end

      to_expand do |template|
        name(template.name) do
          short_desc "Run minitest"

          use :exec

          switch(
            :warnings, "-w", "--[no-]warnings",
            default: template.warnings,
            doc: "Turn on Ruby warnings (defaults to #{template.warnings})"
          )
          remaining_args(:tests, doc: "Paths to the tests to run (defaults to all tests)")

          execute do
            ruby_args = []
            unless template.libs.empty?
              lib_path = template.libs.join(File::PATH_SEPARATOR)
              ruby_args << "-I#{lib_path}"
            end
            ruby_args << "-w" if self[:warnings]

            tests = self[:tests]
            if tests.empty?
              Array(template.files).each do |pattern|
                tests.concat(Dir.glob(pattern))
              end
              tests.uniq!
            end

            ruby(ruby_args, in_from: :controller, exit_on_nonzero_status: true) do |controller|
              tests.each do |file|
                controller.in.puts("load '#{file}'")
              end
            end
          end
        end
      end
    end
  end
end
