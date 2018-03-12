module Toys
  module Helpers
    module Exec
      def configure_exec(opts = {})
        @exec_config ||= {}
        @exec_config.merge!(opts)
      end

      def exec(cmd, opts = {}, &block)
        exec_opts = ExecOpts.new(self)
        exec_opts.add(@exec_config) if defined? @exec_config
        exec_opts.add(opts)
        executor = Executor.new(exec_opts, cmd)
        executor.execute(&block)
      end

      def ruby(args, opts = {}, &block)
        cmd =
          if args.is_a?(Array)
            [[Exec.ruby_binary, "ruby"]] + args
          else
            "#{Exec.ruby_binary} #{args}"
          end
        exec(cmd, opts, &block)
      end

      def sh(cmd, opts = {})
        exec(cmd, opts).exit_code
      end

      def capture(cmd, opts = {})
        exec(cmd, opts.merge(out_to: :capture)).captured_out
      end

      def self.ruby_binary
        File.join(RbConfig::CONFIG["bindir"], RbConfig::CONFIG["ruby_install_name"])
      end

      class ExecOpts
        CONFIG_KEYS = %i[
          exit_on_nonzero_status
          env
          log_level
          in_from
          out_to
          err_to
          out_err_to
        ].freeze

        def initialize(context)
          @context = context
          @config = {}
          @spawn_opts = {}
        end

        def add(config)
          config.each do |k, v|
            if CONFIG_KEYS.include?(k)
              @config[k] = v
            else
              @spawn_opts[k] = v
            end
          end
        end

        attr_reader :config
        attr_reader :spawn_opts
        attr_reader :context
      end

      class Controller
        def initialize(ins, out, err, out_err, pid)
          @in = ins
          @out = out
          @err = err
          @out_err = out_err
          @pid = pid
        end

        attr_reader :in
        attr_reader :out
        attr_reader :err
        attr_reader :out_err
        attr_reader :pid

        def kill(signal)
          Process.kill(signal, pid)
        end
      end

      class Result
        def initialize(out, err, out_err, status)
          @captured_out = out
          @captured_err = err
          @captured_out_err = out_err
          @status = status
        end

        attr_reader :captured_out
        attr_reader :captured_err
        attr_reader :captured_out_err
        attr_reader :status

        def exit_code
          status.exitstatus
        end
      end

      class Executor
        def initialize(exec_opts, cmd)
          @cmd = Array(cmd)
          @config = exec_opts.config
          @context = exec_opts.context
          @spawn_opts = exec_opts.spawn_opts.dup
          @captures = {}
          @controller_streams = {}
          @join_threads = []
          @child_streams = []
        end

        def execute(&block)
          setup_in_stream
          setup_out_stream(:out, :out_to, :out)
          setup_out_stream(:err, :err_to, :err)
          setup_out_stream(:out_err, :out_err_to, [:out, :err])
          log_command
          wait_thread = start_process
          status = control_process(wait_thread, &block)
          create_result(status)
        end

        private

        def log_command
          unless @config[:log_level] == false
            cmd_str = @cmd.size == 1 ? @cmd.first : @cmd.inspect
            @context.logger.add(@config[:log_level] || Logger::INFO, cmd_str)
          end
        end

        def start_process
          args = []
          args << @config[:env] if @config[:env]
          args.concat(@cmd)
          pid = Process.spawn(*args, @spawn_opts)
          @child_streams.each(&:close)
          Process.detach(pid)
        end

        def control_process(wait_thread)
          begin
            if block_given?
              controller = Controller.new(
                @controller_streams[:in], @controller_streams[:out], @controller_streams[:err],
                @controller_streams[:out_err], wait_thread.pid
              )
              yield controller
            end
          ensure
            @controller_streams.each_value(&:close)
          end
          @join_threads.each(&:join)
          wait_thread.value
        end

        def create_result(status)
          if @config[:exit_on_nonzero_status]
            exit_status = status.exitstatus
            @context.exit(exit_status) if exit_status != 0
          end
          Result.new(@captures[:out], @captures[:err], @captures[:out_err], status)
        end

        def setup_in_stream
          setting = @config[:in_from]
          if setting
            r, w = IO.pipe
            @spawn_opts[:in] = r
            w.sync = true
            @child_streams << r
            case setting
            when :controller
              @controller_streams[:in] = w
            when String
              write_string_thread(w, setting)
            else
              raise "Unknown type for in_from"
            end
          end
        end

        def setup_out_stream(stream_name, config_key, spawn_key)
          setting = @config[config_key]
          if setting
            r, w = IO.pipe
            @spawn_opts[spawn_key] = w
            @child_streams << w
            case setting
            when :controller
              @controller_streams[stream_name] = r
            when :capture
              @join_threads << capture_stream_thread(r, stream_name)
            else
              raise "Unknown type for #{config_key}"
            end
          end
        end

        def write_string_thread(stream, string)
          Thread.new do
            begin
              stream.write string
            ensure
              stream.close
            end
          end
        end

        def capture_stream_thread(stream, name)
          Thread.new do
            begin
              @captures[name] = stream.read
            ensure
              stream.close
            end
          end
        end
      end
    end
  end
end
