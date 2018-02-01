module Toys
  module Util
    TOYS_BINARY = "toys"

    class << self
      def canonicalize_name(name)
        name.to_s.downcase.gsub("_", "-").gsub(/[^a-z0-9-]/, "")
      end

      def canonicalize_key(key)
        key.to_s.downcase.gsub("-", "_").gsub(/\W/, "").to_sym
      end
    end
  end
end
