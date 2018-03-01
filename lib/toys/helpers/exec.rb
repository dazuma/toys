module Toys
  module Helpers
    module Exec
      def config_exec(opts={})
        @exec_config ||= {}
        @exec_config.merge!(opts)
      end

      def sh(cmd, opts={})
        utils = Utils.new(self, opts, @exec_config)
        utils.log(cmd)
        system(cmd)
        utils.handle_status($?.exitstatus)
      end

      def capture(cmd, opts={})
        utils = Utils.new(self, opts, @exec_config)
        utils.log(cmd)
        result = ""
        begin
          result = `#{cmd}`
          utils.handle_status($?.exitstatus)
        rescue StandardError
          utils.handle_status(-1)
        end
        result
      end

      class Utils
        def initialize(context, opts, config)
          @context = context
          @config = config ? config.merge(opts) : opts
        end

        def log(cmd)
          unless @config[:log_level] == false
            @context.logger.add(@config[:log_level] || Logger::INFO, cmd)
          end
        end

        def handle_status(status)
          if status != 0 && @config[:report_subprocess_errors]
            @context.exit(status)
          end
          status
        end
      end
    end
  end
end
