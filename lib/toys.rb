##
# Toys is a Ruby library and command line tool that lets you build your own
# command line suite of tools (with commands and subcommands) using a Ruby DSL.
# You can define commands globally or configure special commands scoped to
# individual directories.
#
module Toys
end

require "toys/builder"
require "toys/cli"
require "toys/context"
require "toys/errors"
require "toys/lookup"
require "toys/template"
require "toys/tool"
require "toys/version"
