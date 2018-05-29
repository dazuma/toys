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

##
# Toys is a Ruby library and command line tool that lets you build your own
# command line suite of tools (with commands and subcommands) using a Ruby DSL.
# You can define commands globally or configure special commands scoped to
# individual directories.
#
module Toys
  ##
  # Namespace for common utility classes.
  #
  module Utils; end

  ##
  # Namespace for object definition classes.
  #
  module Definition; end

  ##
  # Namespace for DSL classes.
  #
  module DSL; end
end

require "toys/cli"
require "toys/core_version"
require "toys/definition/acceptor"
require "toys/definition/alias"
require "toys/definition/arg"
require "toys/definition/flag"
require "toys/definition/tool"
require "toys/dsl/arg"
require "toys/dsl/flag"
require "toys/dsl/tool"
require "toys/errors"
require "toys/helpers"
require "toys/input_file"
require "toys/loader"
require "toys/middleware"
require "toys/runner"
require "toys/template"
require "toys/templates"
require "toys/tool"
