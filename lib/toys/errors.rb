module Toys
  ##
  # An exception indicating an error in a tool definition
  #
  class ToolDefinitionError < StandardError
  end

  ##
  # An exception indicating a problem during tool lookup
  #
  class LookupError < StandardError
  end
end
