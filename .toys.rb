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


name "install" do
  desc "Build and install the current code as a gem"
  use :exec
  execute do
    configure_exec exit_on_nonzero_status: true
    root_path = ::File.dirname(tool.definition_path)
    version = ::Dir.chdir(root_path) do
      capture("bin/toys system version").strip
    end
    ::Dir.chdir(::File.join(root_path, "toys-core")) do
      sh "bin/toys build"
      sh "gem install pkg/toys-core-#{version}.gem"
    end
    ::Dir.chdir(::File.join(root_path, "toys")) do
      sh "bin/toys build"
      sh "gem install pkg/toys-#{version}.gem"
    end
  end
end

name "ci" do
  desc "CI target that runs tests and rubocop"
  use :exec
  execute do
    configure_exec exit_on_nonzero_status: true
    root_path = ::File.dirname(tool.definition_path)
    ::Dir.chdir(::File.join(root_path, "toys-core")) do
      sh "bin/toys do test , rubocop"
    end
    ::Dir.chdir(::File.join(root_path, "toys")) do
      sh "bin/toys do test , rubocop"
    end
  end
end
