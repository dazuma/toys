# frozen_string_literal: true

# Copyright 2019 Daniel Azuma
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.
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
                   tool_name: nil, tool_args: nil)
      super("#{banner} : #{cause.message} (#{cause.class})")
      @cause = cause
      @banner = banner
      @config_path = config_path
      @config_line = config_line
      @tool_name = tool_name
      @tool_args = tool_args
    end

    attr_reader :cause
    attr_reader :banner

    attr_accessor :config_path
    attr_accessor :config_line
    attr_accessor :tool_name
    attr_accessor :tool_args

    class << self
      ## @private
      def capture_path(banner, path, opts = {})
        yield
      rescue ContextualError => e
        add_fields_if_missing(e, opts)
        add_config_path_if_missing(e, path)
        raise e
      rescue ::SyntaxError => e
        if (match = /#{::Regexp.escape(path)}:(\d+)/.match(e.message))
          opts = opts.merge(config_path: path, config_line: match[1].to_i)
          e = ContextualError.new(e, banner, opts)
        end
        raise e
      rescue ::ScriptError, ::StandardError => e
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
      rescue ::ScriptError, ::StandardError => e
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
          l = (error.cause.backtrace_locations || []).find { |b| b.absolute_path == path }
          if l
            error.config_path = path
            error.config_line = l.lineno
          end
        end
      end
    end
  end
end
