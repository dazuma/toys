# frozen_string_literal: true

desc "A set of system commands for Toys"

long_desc "Contains tools that inspect, configure, and update Toys itself."

tool "version" do
  desc "Print the current Toys version"

  def run
    puts ::Toys::VERSION
  end
end

mixin "output-tools" do
  on_include do
    flag :output_format, "--format=FORMAT" do
      accept ["json", "json-compact", "yaml"]
      desc 'The output format. Recognized values are "yaml" (the default), "json", and ' \
           '"json-compact".'
    end
  end

  def generate_output(object)
    case output_format
    when "json"
      require "json"
      ::JSON.pretty_generate(object)
    when "json-compact"
      require "json"
      ::JSON.generate(object)
    when nil, "yaml"
      require "psych"
      ::Psych.dump(object)
    else
      logger.error("Unknown output format: #{format}")
      exit(1)
    end
  end
end
