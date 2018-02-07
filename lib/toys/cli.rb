module Toys
  class Cli
    BUILTINS_PATH = File.join(__dir__, "builtins")
    DEFAULT_DIR_NAME = ".toys"
    DEFAULT_FILE_NAME = ".toys.rb"
    DEFAULT_BINARY_NAME = "toys"

    def initialize(
      binary_name: DEFAULT_BINARY_NAME,
      config_dir_name: DEFAULT_DIR_NAME,
      config_file_name: DEFAULT_FILE_NAME,
      index_file_name: DEFAULT_FILE_NAME,
      include_builtin: false,
      include_current_config: false
    )
      @lookup = Toys::Lookup.new(
        binary_name,
        config_dir_name: config_dir_name,
        config_file_name: config_file_name,
        index_file_name: index_file_name)
      prepend_paths(BUILTINS_PATH) if include_builtin
      prepend_config_path_hierarchy(Dir.pwd) if include_current_config
    end

    def prepend_paths(paths)
      @lookup.prepend_paths(paths)
      self
    end

    def prepend_config_paths(paths)
      @lookup.prepend_config_paths(paths)
      self
    end

    def prepend_config_path_hierarchy(path, base="/")
      paths = []
      loop do
        paths << path
        break if !base || path == base
        next_path = File.dirname(path)
        break if next_path == path
        path = next_path
      end
      @lookup.prepend_config_paths(paths)
      self
    end

    def run(args, logger: nil, verbosity: 0)
      context = Context.new(@lookup, logger: logger || default_logger, verbosity: verbosity)
      context.run(*args)
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
      logger
    end
  end
end
