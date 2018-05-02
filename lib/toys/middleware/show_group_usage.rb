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

require "toys/middleware/base"
require "toys/utils/usage"

module Toys
  module Middleware
    ##
    # A middleware that provides a default implementation for groups. If a
    # tool has no executor, this middleware assumes it to be a group, and it
    # provides a default executor that displays group usage documentation.
    #
    class ShowGroupUsage < Base
      ##
      # This middleware adds a "--no-recursive" flag to groups. This flag, when
      # set, shows only immediate subcommands rather than all recursively.
      #
      def config(tool)
        if tool.includes_executor?
          yield
        else
          tool.add_switch(:_no_recursive, "--no-recursive",
                          doc: "Show immediate rather than all subcommands",
                          only_unique: true)
        end
      end

      ##
      # This middleware displays the usage documentation for groups. It has
      # no effect on tools that have their own executor.
      #
      def execute(context)
        if context[Context::TOOL].includes_executor?
          yield
        else
          puts(Utils::Usage.from_context(context).string(recursive: !context[:_no_recursive]))
        end
      end
    end
  end
end
