module Toys
  class Cli
    BUILTINS_PATH = File.join(__dir__, "builtins")
    DEFAULT_DIR_NAME = ".toys"
    DEFAULT_FILE_NAME = ".toys.rb"
    DEFAULT_BINARY_NAME = "toys"
    ETC_PATH = "/etc"

    def initialize(
      binary_name: nil,
      logger: nil,
      config_dir_name: nil,
      config_file_name: nil,
      index_file_name: nil
    )
      @lookup = Toys::Lookup.new(
        config_dir_name: config_dir_name,
        config_file_name: config_file_name,
        index_file_name: index_file_name)
      @context = Context.new(
        @lookup,
        logger: logger || self.class.default_logger,
        binary_name: binary_name)
    end

    def add_paths(paths)
      @lookup.add_paths(paths)
      self
    end

    def add_config_paths(paths)
      @lookup.add_config_paths(paths)
      self
    end

    def add_config_path_hierarchy(path=nil, base="/")
      path ||= Dir.pwd
      paths = []
      loop do
        paths << path
        break if !base || path == base
        next_path = File.dirname(path)
        break if next_path == path
        path = next_path
      end
      @lookup.add_config_paths(paths)
      self
    end

    def run(*args)
      @context.run(*args)
    end

    class << self
      def create_standard
        cli = new(
          binary_name: DEFAULT_BINARY_NAME,
          config_dir_name: DEFAULT_DIR_NAME,
          config_file_name: DEFAULT_FILE_NAME,
          index_file_name: DEFAULT_FILE_NAME
        )
        cli.add_config_path_hierarchy
        if !File.directory?(ETC_PATH) || !File.readable?(ETC_PATH)
          cli.add_config_paths(ETC_PATH)
        end
        cli.add_paths(BUILTINS_PATH)
        cli
      end

      def default_logger
        logger = Logger.new(STDERR)
        logger.formatter = ->(severity, time, progname, msg) {
          msg_str =
            case msg
            when String
              msg
            when Exception
              "#{msg.message} (#{msg.class})\n" << (msg.backtrace || []).join("\n")
            else
              msg.inspect
            end
          timestr = time.strftime("%Y-%m-%d %H:%M:%S")
          "[%s %5s]  %s\n" % [timestr, severity, msg_str]
        }
        logger.level = Logger::WARN
        logger
      end
    end
  end
end
