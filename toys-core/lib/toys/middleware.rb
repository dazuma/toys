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
    class << self
      ##
      # Return a well-known middleware class by name.
      #
      # Currently recognized middleware names are:
      #
      # *  `:add_verbosity_flags` : Adds flags for affecting verbosity.
      # *  `:handle_usage_errors` : Displays the usage error if one occurs.
      # *  `:set_default_descriptions` : Sets default descriptions for tools
      #    that do not have them set explicitly.
      # *  `:show_help` : Teaches tools to print their usage documentation.
      # *  `:show_version` : Teaches tools to print their version.
      #
      # @param [String,Symbol] name Name of the middleware class to return
      # @return [Class,nil] The class, or `nil` if not found
      #
      def lookup(name)
        Utils::ModuleLookup.lookup(:middleware, name)
      end

      ##
      # Resolves a single middleware. You may pass an instance already
      # constructed, a middleware class, the name of a well-known middleware
      # class, or an array where the first element is the lookup name or class,
      # and subsequent elements are arguments to be passed to the constructor.
      #
      # @param [String,Symbol,Array,Object] input The middleware spec
      # @return [Object] Constructed middleware
      #
      def resolve(input)
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
      def resolve_stack(input)
        input.map { |e| resolve(e) }
      end

      ##
      # Resolves a typical flags specification. Used often in middleware.
      #
      # You may provide any of the following for the `flags` parameter:
      # *  A string, which becomes the single flag
      # *  An array of strings
      # *  The value `false` or `nil` which resolves to no flags
      # *  The value `true` or `:default` which resolves to the given defaults
      # *  A proc that takes a tool as argument and returns any of the above.
      #
      # Always returns an array of flag strings, even if empty.
      #
      # @param [Boolean,String,Array<String>,Proc] flags Flag spec
      # @param [Toys::Tool] tool The tool
      # @param [Array<String>] defaults The defaults to use for `true`.
      # @return [Array<String>] An array of flags
      #
      def resolve_flags_spec(flags, tool, defaults)
        flags = flags.call(tool) if flags.respond_to?(:call)
        case flags
        when true, :default
          Array(defaults)
        when ::String
          [flags]
        when ::Array
          flags
        else
          []
        end
      end
    end
  end
end
