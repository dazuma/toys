module Toys
  module Helpers
    module Exec
      def configure_exec(opts={})
        @exec_config ||= {}
        @exec_config.merge!(opts)
      end

      def exec(cmd, opts={}, &block)
        exec_opts = ExecOpts.new(self)
        exec_opts.add(@exec_config) if defined? @exec_config
        exec_opts.add(opts)
        executor = Executor.new(exec_opts, cmd)
        executor.execute(&block)
      end

      def ruby(args, opts={}, &block)
        if args.is_a?(Array)
          cmd = [[Exec.ruby_binary, "ruby"]] + args
        else
          cmd = "#{Exec.ruby_binary} #{args}"
        end
        exec(cmd, opts, &block)
      end

      def sh(cmd, opts={})
        exec(cmd, opts).exit_code
      end

      def capture(cmd, opts={})
        exec(cmd, opts.merge(out_to: :capture)).captured_out
      end

      def self.ruby_binary
        File.join(RbConfig::CONFIG["bindir"], RbConfig::CONFIG["ruby_install_name"])
      end

      class ExecOpts
        CONFIG_KEYS = [
          :exit_on_nonzero_status,
          :env,
          :log_level,
          :in_from,
          :out_to,
          :err_to,
          :out_err_to
        ]

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
        def initialize(executor)
          @executor = executor
        end

        def in
          @executor.controller_streams[:in]
        end

        def out
          @executor.controller_streams[:out]
        end

        def err
          @executor.controller_streams[:err]
        end

        def out_err
          @executor.controller_streams[:out_err]
        end

        def pid
          @executor.wait_thread.pid
        end

        def kill(signal)
          Process.kill(signal, pid)
        end
      end

      class Result
        def initialize(executor)
          @executor = executor
        end

        def captured_out
          @executor.captures[:out]
        end

        def captured_err
          @executor.captures[:err]
        end

        def captured_out_err
          @executor.captures[:out_err]
        end

        def status
          @executor.status
        end

        def exit_code
          @executor.status.exitstatus
        end
      end

      class Executor
        def initialize(exec_opts, cmd)
          @cmd = Array(cmd)
          @config = exec_opts.config
          @context = exec_opts.context
          @spawn_opts = exec_opts.spawn_opts.dup
          @wait_thread = nil
          @captures = {}
          @controller_streams = {}
          @join_threads = []
          @child_streams = []
          @status = nil
        end

        attr_reader :controller_streams
        attr_reader :wait_thread
        attr_reader :captures
        attr_reader :status

        def execute
          setup_in_stream
          setup_out_stream(:out, :out_to, :out)
          setup_out_stream(:err, :err_to, :err)
          setup_out_stream(:out_err, :out_err_to, [:out, :err])
          unless @config[:log_level] == false
            cmd_str = @cmd.size == 1 ? @cmd.first : @cmd.inspect
            @context.logger.add(@config[:log_level] || Logger::INFO, cmd_str)
          end
          args = []
          args << @config[:env] if @config[:env]
          args.concat(@cmd)
          pid = Process.spawn(*args, @spawn_opts)
          @wait_thread = Process.detach(pid)
          @child_streams.each(&:close)
          begin
            yield(Controller.new(self)) if block_given?
          ensure
            @controller_streams.each_value(&:close)
          end
          @join_threads.each(&:join)
          @status = @wait_thread.value
          if @config[:exit_on_nonzero_status]
            exit_status = @status.exitstatus
            @context.exit(exit_status) if exit_status != 0
          end
          Result.new(self)
        end

        private

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
              Thread.new do
                begin
                  w.write setting
                ensure
                  w.close
                end
              end
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
              @join_threads << Thread.new do
                begin
                  @captures[stream_name] = r.read
                ensure
                  r.close
                end
              end
            else
              raise "Unknown type for #{config_key}"
            end
          end
        end
      end
    end
  end
end
