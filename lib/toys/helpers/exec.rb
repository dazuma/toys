module Toys
  module Helpers
    module Exec
      def exec_str(cmd)
        logger.info "EXECUTING: #{cmd}"
        system cmd
      end
    end
  end
end
