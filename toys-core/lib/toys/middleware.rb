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

require "toys/utils/module_lookup"

module Toys
  ##
  # Middleware lets you define common behavior across many tools.
  #
  module Middleware
    ##
    # Return a middleware class by name.
    #
    # Currently recognized middleware names are:
    #
    # *  `:add_verbosity_switches` : Adds switches for affecting log verbosity.
    # *  `:handle_usage_errors` : Displays the usage error if one occurs.
    # *  `:set_default_descriptions` : Sets default descriptions for tools that
    #    do not have them set explicitly.
    # *  `:show_usage` : Provides ways to cause a tool to print its own usage
    #    documentation.
    # *  `:show_version` : Provides ways to cause a tool to print its version.
    #
    # @param [String,Symbol] name Name of the middleware class to return
    # @return [Class,nil] The class, or `nil` if not found
    #
    def self.lookup(name)
      Utils::ModuleLookup.lookup(:middleware, name)
    end

    ##
    # Resolves a single middleware. You may pass an instance already
    # constructed, a middleware class, a name to look up to get the middleware
    # class, or an array where the first element is the lookup name or class,
    # and subsequent elements are arguments to be passed to the constructor.
    #
    # @param [String,Symbol,Array,Object] input The middleware spec
    # @return [Object] Constructed middleware
    #
    def self.resolve(input)
      input = Array(input)
      raise "No middleware found" if input.empty?
      cls = input.first
      args = input[1..-1]
      if cls.is_a?(::String) || cls.is_a?(::Symbol)
        cls = lookup(cls)
      end
      if cls.is_a?(::Class)
        cls.new(*args)
      else
        raise "Unrecognized middleware class #{cls.class}" unless args.empty?
        cls
      end
    end

    ##
    # Resolves an array of middleware specs. See {Toys::Middleware.resolve}.
    #
    # @param [Array] input An array of middleware specs
    # @return [Array] An array of constructed middleware
    #
    def self.resolve_stack(input)
      input.map { |e| resolve(e) }
    end
  end
end
