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
  module StandardMiddleware
    ##
    # A middleware that provides flags for editing the verbosity.
    #
    # This middleware adds `-v`, `--verbose`, `-q`, and `--quiet` flags, if
    # not already defined by the tool. These flags affect the setting of
    # {Toys::Context::Key::VERBOSITY}, and, thus, the logger level.
    #
    class AddVerbosityFlags
      include Middleware

      ##
      # Default verbose flags
      # @return [Array<String>]
      #
      DEFAULT_VERBOSE_FLAGS = ["-v", "--verbose"].freeze

      ##
      # Default quiet flags
      # @return [Array<String>]
      #
      DEFAULT_QUIET_FLAGS = ["-q", "--quiet"].freeze

      ##
      # Create a AddVerbosityFlags middleware.
      #
      # @param [Boolean,Array<String>,Proc] verbose_flags Specify flags
      #     to increase verbosity. The value may be any of the following:
      #
      #     *  An array of flags that increase verbosity.
      #     *  The `true` value to use {DEFAULT_VERBOSE_FLAGS}. (Default)
      #     *  The `false` value to disable verbose flags.
      #     *  A proc that takes a tool and returns any of the above.
      #
      # @param [Boolean,Array<String>,Proc] quiet_flags Specify flags
      #     to decrease verbosity. The value may be any of the following:
      #
      #     *  An array of flags that decrease verbosity.
      #     *  The `true` value to use {DEFAULT_QUIET_FLAGS}. (Default)
      #     *  The `false` value to disable quiet flags.
      #     *  A proc that takes a tool and returns any of the above.
      #
      def initialize(verbose_flags: true, quiet_flags: true)
        @verbose_flags = verbose_flags
        @quiet_flags = quiet_flags
      end

      ##
      # Configure the tool flags.
      #
      def config(tool, _loader)
        unless tool.argument_parsing_disabled?
          StandardMiddleware.append_common_flag_group(tool)
          add_verbose_flags(tool)
          add_quiet_flags(tool)
        end
        yield
      end

      private

      INCREMENT_HANDLER = ->(_val, cur) { cur.to_i + 1 }
      DECREMENT_HANDLER = ->(_val, cur) { cur.to_i - 1 }

      def add_verbose_flags(tool)
        verbose_flags = resolve_flags_spec(@verbose_flags, tool, DEFAULT_VERBOSE_FLAGS)
        unless verbose_flags.empty?
          tool.add_flag(
            Context::Key::VERBOSITY, verbose_flags,
            report_collisions: false,
            handler: INCREMENT_HANDLER,
            desc: "Increase verbosity",
            long_desc: "Increase verbosity, causing additional logging levels to display.",
            group: StandardMiddleware::COMMON_FLAG_GROUP
          )
        end
      end

      def add_quiet_flags(tool)
        quiet_flags = resolve_flags_spec(@quiet_flags, tool, DEFAULT_QUIET_FLAGS)
        unless quiet_flags.empty?
          tool.add_flag(
            Context::Key::VERBOSITY, quiet_flags,
            report_collisions: false,
            handler: DECREMENT_HANDLER,
            desc: "Decrease verbosity",
            long_desc: "Decrease verbosity, causing fewer logging levels to display.",
            group: StandardMiddleware::COMMON_FLAG_GROUP
          )
        end
      end

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
