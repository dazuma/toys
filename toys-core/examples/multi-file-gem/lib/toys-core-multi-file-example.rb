# frozen_string_literal: true

require "toys-core"

# Example executable.
class ToysCoreExample
  def initialize
    @cli = ::Toys::CLI.new
    @cli.add_config_path(::File.join(::File.dirname(__dir__), "tools"))
  end

  def run
    exit(@cli.run(::ARGV))
  end
end
