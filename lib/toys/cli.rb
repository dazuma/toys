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

require "logger"

module Toys
  ##
  # A Toys-based CLI
  #
  class CLI
    ##
    # Path to default builtins
    # @return [String]
    #
    BUILTINS_PATH = ::File.join(__dir__, "builtins").freeze

    ##
    # Default name of toys configuration directory
    # @return [String]
    #
    DEFAULT_DIR_NAME = ".toys".freeze

    ##
    # Default name of toys configuration file
    # @return [String]
    #
    DEFAULT_FILE_NAME = ".toys.rb".freeze

    ##
    # Default name of toys preload file
    # @return [String]
    #
    DEFAULT_PRELOAD_NAME = ".preload.rb".freeze

    ##
    # Default name of toys binary
    # @return [String]
    #
    DEFAULT_BINARY_NAME = "toys".freeze

    def initialize(
      binary_name: nil,
      logger: nil,
      config_dir_name: nil,
      config_file_name: nil,
      index_file_name: nil,
      preload_file_name: nil
    )
      logger ||= self.class.default_logger
      @lookup = Lookup.new(
        config_dir_name: config_dir_name,
        config_file_name: config_file_name,
        index_file_name: index_file_name,
        preload_file_name: preload_file_name
      )
      @context_base = Context::Base.new(@lookup, binary_name, logger)
    end

    def add_paths(paths)
      @lookup.add_paths(paths)
      self
    end

    def add_config_paths(paths)
      @lookup.add_config_paths(paths)
      self
    end

    def add_config_path_hierarchy(path = nil, base = "/")
      path ||= ::Dir.pwd
      paths = []
      loop do
        paths << path
        break if !base || path == base
        next_path = ::File.dirname(path)
        break if next_path == path
        path = next_path
      end
      @lookup.add_config_paths(paths)
      self
    end

    def add_standard_config_paths
      toys_path = ::ENV["TOYS_PATH"].to_s.split(::File::PATH_SEPARATOR)
      if toys_path.empty?
        toys_path << ::ENV["HOME"] if ::ENV["HOME"]
        toys_path << "/etc" if File.directory?("/etc") && ::File.readable?("/etc")
      end
      @lookup.add_config_paths(toys_path)
    end

    def run(*args)
      @context_base.run(*args)
    end

    class << self
      def create_standard
        cli = new(
          binary_name: DEFAULT_BINARY_NAME,
          config_dir_name: DEFAULT_DIR_NAME,
          config_file_name: DEFAULT_FILE_NAME,
          index_file_name: DEFAULT_FILE_NAME,
          preload_file_name: DEFAULT_PRELOAD_NAME
        )
        cli.add_config_path_hierarchy
        cli.add_standard_config_paths
        cli.add_paths(BUILTINS_PATH)
        cli
      end

      def default_logger
        logger = ::Logger.new(::STDERR)
        logger.formatter = proc do |severity, time, _progname, msg|
          msg_str =
            case msg
            when ::String
              msg
            when ::Exception
              "#{msg.message} (#{msg.class})\n" << (msg.backtrace || []).join("\n")
            else
              msg.inspect
            end
          timestr = time.strftime("%Y-%m-%d %H:%M:%S")
          format("[%s %5s]  %s\n", timestr, severity, msg_str)
        end
        logger.level = ::Logger::WARN
        logger
      end
    end
  end
end
