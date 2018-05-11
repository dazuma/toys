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
  ##
  # An exception indicating an error in a tool definition
  #
  class ToolDefinitionError < ::StandardError
  end

  ##
  # An exception indicating a problem during tool lookup
  #
  class LoaderError < ::StandardError
  end

  ##
  # A wrapper exception used to provide user-oriented context for an exception
  #
  class ContextualError < ::StandardError
    ## @private
    def initialize(cause, banner,
                   config_path: nil, config_line: nil,
                   tool_name: nil, tool_args: nil, full_args: nil)
      super("#{banner} : #{cause.message} (#{cause.class})")
      @cause = cause
      @banner = banner
      @config_path = config_path
      @config_line = config_line
      @tool_name = tool_name
      @tool_args = tool_args
      @full_args = full_args
    end

    attr_reader :cause
    attr_reader :banner

    attr_accessor :config_path
    attr_accessor :config_line
    attr_accessor :tool_name
    attr_accessor :tool_args
    attr_accessor :full_args

    class << self
      ## @private
      def capture_path(banner, path, opts = {})
        yield
      rescue ContextualError => e
        add_fields_if_missing(e, opts)
        add_config_path_if_missing(e, path)
        raise e
      rescue ::SyntaxError => e
        if e.message =~ /#{::Regexp.escape(path)}:(\d+)/
          opts = opts.merge(config_path: path, config_line: $1.to_i)
          e = ContextualError.new(e, banner, opts)
        end
        raise e
      rescue ::StandardError => e
        e = ContextualError.new(e, banner)
        add_fields_if_missing(e, opts)
        add_config_path_if_missing(e, path)
        raise e
      end

      ## @private
      def capture(banner, opts = {})
        yield
      rescue ContextualError => e
        add_fields_if_missing(e, opts)
        raise e
      rescue ::StandardError => e
        raise ContextualError.new(e, banner, opts)
      end

      private

      def add_fields_if_missing(error, opts)
        opts.each do |k, v|
          error.send(:"#{k}=", v) if error.send(k).nil?
        end
      end

      def add_config_path_if_missing(error, path)
        if error.config_path.nil? && error.config_line.nil?
          l = error.cause.backtrace_locations.find { |b| b.absolute_path == path }
          if l
            error.config_path = path
            error.config_line = l.lineno
          end
        end
      end
    end
  end
end
