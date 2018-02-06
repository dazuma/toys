module Toys
  module Helpers
    module Exec
      def sh(cmd)
        logger.info(cmd)
        system(cmd)
        $?.exitstatus
      end

      def capture(cmd)
        logger.info(cmd)
        `#{cmd}`
      end
    end
  end
end
