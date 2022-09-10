# frozen_string_literal: true

require "helper"
require "timeout"
require "fileutils"
require "English"
require "toys/utils/exec"

describe Toys::Utils::Exec do
  let(:logger_stringio) { ::StringIO.new }
  let(:logger) { ::Logger.new(logger_stringio) }
  let(:exec) { Toys::Utils::Exec.new(logger: logger) }
  let(:tmp_dir) { ::File.join(::File.dirname(::File.dirname(__dir__)), "tmp") }
  let(:input_path) { ::File.join(::File.dirname(__dir__), "data", "input.txt") }
  let(:output_path) { ::File.join(tmp_dir, "output.txt") }
  let(:output2_path) { ::File.join(tmp_dir, "output2.txt") }
  let(:simple_exec_timeout) { 5 }
  let(:ruby_exec_timeout) {
    Toys::Compat.jruby? || Toys::Compat.truffleruby? ? 10 : simple_exec_timeout
  }

  describe "result object" do
    it "detects zero exit codes" do
      ::Timeout.timeout(simple_exec_timeout) do
        result = exec.exec(["true"])
        assert_nil(result.exception)
        assert_instance_of(::Process::Status, result.status)
        assert_equal(0, result.exit_code)
        assert_nil(result.signal_code)
        assert_equal(true, result.success?)
        assert_equal(false, result.error?)
        assert_equal(false, result.signaled?)
        assert_equal(false, result.failed?)
      end
    end

    it "detects nonzero exit codes" do
      skip("https://github.com/oracle/truffleruby/issues/2568") if Toys::Compat.truffleruby?
      ::Timeout.timeout(simple_exec_timeout) do
        result = exec.exec("exit 3")
        assert_nil(result.exception)
        assert_instance_of(::Process::Status, result.status)
        assert_equal(3, result.exit_code)
        assert_nil(result.signal_code)
        assert_equal(false, result.success?)
        assert_equal(true, result.error?)
        assert_equal(false, result.signaled?)
        assert_equal(false, result.failed?)
      end
    end

    it "detects ENOENT" do
      ::Timeout.timeout(simple_exec_timeout) do
        result = exec.exec(["hohohohohohoho"])
        assert_instance_of(::Errno::ENOENT, result.exception)
        assert_nil(result.exit_code)
        assert_nil(result.exit_code)
        assert_nil(result.signal_code)
        assert_equal(false, result.success?)
        assert_equal(false, result.error?)
        assert_equal(false, result.signaled?)
        assert_equal(true, result.failed?)
      end
    end

    it "detects termination due to signal" do
      skip if Toys::Compat.windows?
      ::Timeout.timeout(simple_exec_timeout) do
        result = exec.exec("sleep 5") do |controller|
          sleep(0.5)
          controller.kill("TERM")
        end
        assert_nil(result.exception)
        assert_instance_of(::Process::Status, result.status)
        assert_nil(result.exit_code)
        assert_equal(15, result.signal_code)
        assert_equal(false, result.success?)
        assert_equal(false, result.error?)
        assert_equal(true, result.signaled?)
        assert_equal(false, result.failed?)
      end
    end

    it "gets the name" do
      ::Timeout.timeout(simple_exec_timeout) do
        result = exec.exec(["echo", "hi"], out: :capture, name: "my-echo")
        assert_equal("my-echo", result.name)
      end
    end
  end

  describe "result callback" do
    it "is called on zero exit codes" do
      ::Timeout.timeout(simple_exec_timeout) do
        was_called = false
        callback = proc do |result|
          assert(result.success?)
          was_called = true
        end
        exec.exec(["echo", "hi"], out: :capture, result_callback: callback)
        assert_equal(true, was_called)
      end
    end

    it "is called on nonzero exit codes" do
      ::Timeout.timeout(simple_exec_timeout) do
        was_called = false
        callback = proc do |result|
          assert(result.error?)
          was_called = true
        end
        exec.exec(["false"], result_callback: callback)
        assert_equal(true, was_called)
      end
    end

    it "is called on spawn failures" do
      ::Timeout.timeout(simple_exec_timeout) do
        was_called = false
        callback = proc do |result|
          assert(result.failed?)
          was_called = true
        end
        exec.exec(["blahblahblah"], result_callback: callback)
        assert_equal(true, was_called)
      end
    end

    it "is called on signals" do
      skip if Toys::Compat.windows?
      ::Timeout.timeout(simple_exec_timeout) do
        was_called = false
        callback = proc do |result|
          assert(result.signaled?)
          was_called = true
        end
        exec.exec("sleep 5", result_callback: callback) do |controller|
          sleep(0.5)
          controller.kill("TERM")
        end
        assert_equal(true, was_called)
      end
    end
  end

  describe "command form" do
    it "recognizes arrays" do
      ::Timeout.timeout(simple_exec_timeout) do
        result = exec.exec(["echo", "hi"], out: :capture)
        assert_equal("hi\n", result.captured_out)
        assert_match(/exec: \["echo", "hi"\]\n/, logger_stringio.string)
      end
    end

    it "converts non-strings to strings" do
      ::Timeout.timeout(simple_exec_timeout) do
        result = exec.exec(["echo", 1, 2], out: :capture)
        assert_equal("1 2\n", result.captured_out)
        assert_match(/exec: \["echo", "1", "2"\]\n/, logger_stringio.string)
      end
    end

    it "handles a single element array" do
      ::Timeout.timeout(simple_exec_timeout) do
        list = Toys::Compat.windows? ? "dir" : "ls"
        result = exec.exec([list], out: :capture)
        assert_match(/README\.md/, result.captured_out)
        assert_match(/exec: \[#{list.inspect}\]\n/, logger_stringio.string)
      end
    end

    it "handles a single element array with a single element array as the element" do
      ::Timeout.timeout(simple_exec_timeout) do
        list = Toys::Compat.windows? ? "dir" : "ls"
        result = exec.exec([[list]], out: :capture)
        assert_match(/README\.md/, result.captured_out)
        assert_match(/exec: \[#{list.inspect}\]\n/, logger_stringio.string)
      end
    end

    it "recongizes strings as shell commands" do
      ::Timeout.timeout(simple_exec_timeout) do
        if Toys::Compat.windows?
          result = exec.exec("dir *.md", out: :capture)
          assert_match(/README\.md/, result.captured_out)
          assert_match(/exec sh: "dir \*\.md"\n/, logger_stringio.string)
        else
          result = exec.exec("BLAHXYZBLAH=hi env | grep BLAHXYZBLAH", out: :capture)
          assert_equal("BLAHXYZBLAH=hi\n", result.captured_out)
          assert_match(/exec sh: "BLAHXYZBLAH=hi env \| grep BLAHXYZBLAH"/, logger_stringio.string)
        end
      end
    end

    it "recongizes an array with array binary" do
      skip if Toys::Compat.jruby? || Toys::Compat.windows?
      ::Timeout.timeout(simple_exec_timeout) do
        result = exec.exec([["sh", "meow"], "-c", "echo $0"], out: :capture)
        assert_equal("meow\n", result.captured_out)
        assert_match(/exec: \["sh", "-c", "echo \$0"\]\n/, logger_stringio.string)
      end
    end

    it "recongizes argv0 as an option" do
      skip if Toys::Compat.jruby? || Toys::Compat.windows?
      ::Timeout.timeout(simple_exec_timeout) do
        result = exec.exec(["sh", "-c", "echo $0"], out: :capture, argv0: "meow")
        assert_equal("meow\n", result.captured_out)
        assert_match(/exec: \["sh", "-c", "echo \$0"\]\n/, logger_stringio.string)
      end
    end

    it "forks procs" do
      skip unless Toys::Compat.allow_fork?
      ::Timeout.timeout(simple_exec_timeout) do
        func = proc do
          puts "pid: #{::Process.pid}"
        end
        result = exec.exec_proc(func, out: :capture)
        match = /pid: (\d+)/.match(result.captured_out)
        refute_nil(match)
        refute_equal(match[1].to_i, ::Process.pid)
        assert_match(/exec proc:/, logger_stringio.string)
      end
    end

    it "runs a ruby subprocess" do
      ::Timeout.timeout(ruby_exec_timeout) do
        result = exec.exec_ruby(["-e", "puts 'hello, ' + 'world'"], out: :capture)
        assert_equal("hello, world\n", result.captured_out)
        assert_match(/exec ruby: \["-e", "puts 'hello, ' \+ 'world'"\]/, logger_stringio.string)
      end
    end
  end

  describe "logging" do
    describe "with log_level" do
      it "is disabled when log_level is set to false" do
        ::Timeout.timeout(simple_exec_timeout) do
          exec.exec(["echo", "hi"], out: :null, log_level: false)
          assert_empty(logger_stringio.string)
        end
      end

      it "honors log_level setting" do
        ::Timeout.timeout(simple_exec_timeout) do
          exec.exec(["echo", "hi"], out: :null, log_level: ::Logger::DEBUG)
          assert_match(/DEBUG/, logger_stringio.string)
        end
      end

      it "defaults to INFO level" do
        ::Timeout.timeout(simple_exec_timeout) do
          exec.exec(["echo", "hi"], out: :null)
          assert_match(/INFO/, logger_stringio.string)
        end
      end
    end
  end

  describe "stream handling for spawn" do
    it "inherits parent streams" do
      skip unless Toys::Compat.allow_fork?
      ::Timeout.timeout(ruby_exec_timeout) do
        func = proc do
          script = <<-SCRIPT
            if gets == "hello"
              puts "abc"
              warn "def"
              exit(2)
            else
              exit(1)
            end
          SCRIPT
          r = exec.ruby(["-e", script], out: :inherit, in: :inherit, err: :inherit)
          exit(r.exit_code)
        end
        result = exec.exec_proc(func, out: :capture, err: :capture, in: [:string, "hello"])
        assert_equal(2, result.exit_code)
        assert_equal("abc\n", result.captured_out)
        assert_equal("def\n", result.captured_err)
      end
    end

    it "captures stdout and stderr" do
      ::Timeout.timeout(ruby_exec_timeout) do
        result = exec.ruby(["-e", 'STDOUT.puts "hello"; STDERR.puts "world"'],
                           out: :capture, err: :capture)
        assert_equal("hello\n", result.captured_out)
        assert_equal("world\n", result.captured_err)
      end
    end

    it "writes a string to stdin" do
      ::Timeout.timeout(ruby_exec_timeout) do
        result = exec.ruby(["-e", 'exit gets == "hello" ? 0 : 1'], in: [:string, "hello"])
        assert_equal(0, result.exit_code)
      end
    end

    it "combines err into out" do
      ::Timeout.timeout(ruby_exec_timeout) do
        result = exec.ruby(["-e", 'STDOUT.puts "hello"; STDERR.puts "world"'],
                           out: :capture, err: [:child, :out])
        assert_match(/hello/, result.captured_out)
        assert_match(/world/, result.captured_out)
      end
    end

    it "handles StringIO" do
      ::Timeout.timeout(ruby_exec_timeout) do
        input = ::StringIO.new("hello\n")
        output = ::StringIO.new
        exec.ruby(["-e", 'puts(gets + "world\n")'], in: input, out: output)
        assert_match(/hello\r?\nworld\r?\n/, output.string)
      end
    end

    it "handles file redirects" do
      ::FileUtils.mkdir_p(tmp_dir)
      ::FileUtils.rm_rf(output_path)
      ::Timeout.timeout(ruby_exec_timeout) do
        exec.ruby(["-e", 'puts(gets + "world\n")'],
                  in: [:file, input_path], out: [:file, output_path])
        assert_equal("hello\nworld\n", ::File.read(output_path))
      end
      ::FileUtils.rm_rf(tmp_dir)
    end

    it "interprets bare strings as file names" do
      ::FileUtils.mkdir_p(tmp_dir)
      ::FileUtils.rm_rf(output_path)
      ::Timeout.timeout(ruby_exec_timeout) do
        exec.ruby(["-e", 'puts(gets + "world\n")'],
                  in: input_path, out: output_path)
        assert_equal("hello\nworld\n", ::File.read(output_path))
      end
      ::FileUtils.rm_rf(tmp_dir)
    end

    it "handles pipes from stdout" do
      ::Timeout.timeout(ruby_exec_timeout * 2) do
        pipe = ::IO.pipe
        exec.ruby(["-e", '$stdout.write "hello"'], out: pipe, background: true)
        output = exec.capture_ruby(["-e", 'puts($stdin.read + " world")'], in: pipe)
        assert_equal("hello world\n", output)
      end
    end

    it "handles pipes from stderr" do
      ::Timeout.timeout(ruby_exec_timeout * 2) do
        pipe = ::IO.pipe
        exec.ruby(["-e", '$stderr.write "hello"'], err: pipe, background: true)
        output = exec.capture_ruby(["-e", 'puts($stdin.read + " world")'], in: pipe)
        assert_equal("hello world\n", output)
      end
    end

    it "handles tees" do
      ::FileUtils.mkdir_p(tmp_dir)
      ::FileUtils.rm_rf(output_path)
      ::FileUtils.rm_rf(output2_path)
      ::Timeout.timeout(ruby_exec_timeout * 2) do
        pipe = ::IO.pipe
        file1 = ::File.open(output_path, "w")
        stringio = ::StringIO.new
        result1 = result2 = controller1_data = nil
        out, _err = capture_subprocess_io do
          controller1 = exec.ruby(
            ["-e", '5.times { |i| $stdout.write("abcd "*5); $stdout.flush; sleep(0.2) }'],
            out: [
              :tee, :inherit, :capture, :controller, file1, output2_path, stringio, pipe,
              {buffer_size: 10}
            ],
            background: true
          )
          controller2 = exec.ruby(["-e", "puts $stdin.read.length"],
                                  in: pipe, out: :capture, background: true)
          controller1_data = controller1.out.read
          result1 = controller1.result
          result2 = controller2.result
        end
        assert(pipe.last.closed?)
        refute(file1.closed?)
        file1.close
        expected = "abcd " * 25
        assert_equal(expected, out)
        assert_equal(expected, result1.captured_out)
        assert_equal(expected, controller1_data)
        assert_equal(expected, ::File.read(output_path))
        assert_equal(expected, ::File.read(output2_path))
        assert_equal(expected, stringio.string)
        assert_equal("#{expected.length}\n", result2.captured_out)
      end
      ::FileUtils.rm_rf(tmp_dir)
    end

    it "inherits parent streams by default when running in the foreground" do
      skip unless Toys::Compat.allow_fork?
      ::Timeout.timeout(ruby_exec_timeout) do
        func = proc do
          script = <<-SCRIPT
            if gets == "hello"
              puts "abc"
              warn "def"
              exit(2)
            else
              exit(1)
            end
          SCRIPT
          r = exec.ruby(["-e", script])
          exit(r.exit_code)
        end
        result = exec.exec_proc(func, out: :capture, err: :capture, in: [:string, "hello"])
        assert_equal(2, result.exit_code)
        assert_equal("abc\n", result.captured_out)
        assert_equal("def\n", result.captured_err)
      end
    end

    it "redirects to null by default when running in the background" do
      skip unless Toys::Compat.allow_fork?
      ::Timeout.timeout(ruby_exec_timeout) do
        func = proc do
          script = <<-SCRIPT
            puts "abc"
            warn "def"
          SCRIPT
          exec.ruby(["-e", script], background: true).result(timeout: 0.5)
        end
        result = exec.exec_proc(func, out: :capture, err: :capture, in: [:string, "hello"])
        assert_equal("", result.captured_out)
        assert_equal("", result.captured_err)
      end
    end
  end

  describe "stream handling for fork" do
    before do
      skip unless Toys::Compat.allow_fork?
    end

    it "inherits parent streams" do
      ::Timeout.timeout(simple_exec_timeout) do
        func = proc do
          f = proc do
            if gets == "hello"
              puts "abc"
              warn "def"
              exit(2)
            else
              exit(1)
            end
          end
          r = exec.exec_proc(f, out: :inherit, in: :inherit, err: :inherit)
          exit(r.exit_code)
        end
        result = exec.exec_proc(func, out: :capture, err: :capture, in: [:string, "hello"])
        assert_equal(2, result.exit_code)
        assert_equal("abc\n", result.captured_out)
        assert_equal("def\n", result.captured_err)
      end
    end

    it "captures stdout and stderr" do
      ::Timeout.timeout(simple_exec_timeout) do
        func = proc do
          puts "hello"
          warn "world"
        end
        result = exec.exec_proc(func, out: :capture, err: :capture)
        assert_equal("hello\n", result.captured_out)
        assert_equal("world\n", result.captured_err)
      end
    end

    it "writes a string to stdin" do
      ::Timeout.timeout(simple_exec_timeout) do
        func = proc do
          exit gets == "hello" ? 0 : 1
        end
        result = exec.exec_proc(func, in: [:string, "hello"])
        assert_equal(0, result.exit_code)
      end
    end

    it "combines err into out" do
      ::Timeout.timeout(simple_exec_timeout) do
        func = proc do
          puts "hello"
          warn "world"
        end
        result = exec.exec_proc(func, out: :capture, err: [:child, :out])
        assert_match(/hello/, result.captured_out)
        assert_match(/world/, result.captured_out)
      end
    end

    it "handles StringIO" do
      ::Timeout.timeout(simple_exec_timeout) do
        input = ::StringIO.new("hello\n")
        output = ::StringIO.new
        func = proc do
          puts("#{gets}world\n")
        end
        exec.exec_proc(func, in: input, out: output)
        assert_equal("hello\nworld\n", output.string)
      end
    end

    it "handles file redirects" do
      ::FileUtils.mkdir_p(tmp_dir)
      ::FileUtils.rm_rf(output_path)
      ::Timeout.timeout(simple_exec_timeout) do
        func = proc do
          puts("#{gets}world\n")
        end
        exec.exec_proc(func, in: [:file, input_path], out: [:file, output_path])
        assert_equal("hello\nworld\n", ::File.read(output_path))
      end
      ::FileUtils.rm_rf(tmp_dir)
    end

    it "closes stdin" do
      ::Timeout.timeout(simple_exec_timeout) do
        func = proc do
          begin
            puts gets.inspect
          rescue ::IOError
            exit 1
          end
        end
        result = exec.exec_proc(func, in: :close)
        assert_equal(1, result.exit_code)
      end
    end

    it "closes stdout" do
      ::Timeout.timeout(simple_exec_timeout) do
        func = proc do
          begin
            puts "hi"
          rescue ::IOError
            exit 1
          end
        end
        result = exec.exec_proc(func, out: :close)
        assert_equal(1, result.exit_code)
      end
    end

    it "closes stderr" do
      ::Timeout.timeout(simple_exec_timeout) do
        func = proc do
          begin
            # Need to use stderr.puts instead of warn here because warn doesn't
            # crash if the stream is closed.
            $stderr.puts "hi" # rubocop:disable Style/StderrPuts
          rescue ::IOError
            exit 1
          end
        end
        result = exec.exec_proc(func, err: :close)
        assert_equal(1, result.exit_code)
      end
    end

    it "redirects stdin from null" do
      ::Timeout.timeout(simple_exec_timeout) do
        func = proc do
          exit gets.nil? ? 0 : 1
        end
        result = exec.exec_proc(func, in: :null)
        assert_equal(0, result.exit_code)
      end
    end

    it "redirects stdout to null" do
      ::Timeout.timeout(simple_exec_timeout) do
        func = proc do
          puts "THIS SHOULD NOT BE DISPLAYED."
        end
        result = exec.exec_proc(func, out: :null)
        assert_equal(0, result.exit_code)
      end
    end

    it "redirects stderr to null" do
      ::Timeout.timeout(simple_exec_timeout) do
        func = proc do
          warn "THIS SHOULD NOT BE DISPLAYED."
        end
        result = exec.exec_proc(func, err: :null)
        assert_equal(0, result.exit_code)
      end
    end

    it "handles pipes from stdout" do
      ::Timeout.timeout(simple_exec_timeout) do
        pipe = ::IO.pipe
        producer = proc do
          $stdout.write "hello"
        end
        exec.exec_proc(producer, out: pipe, background: true)
        consumer = proc do
          puts("#{$stdin.read} world")
        end
        output = exec.capture_proc(consumer, in: pipe)
        assert_equal("hello world\n", output)
      end
    end

    it "handles pipes from stderr" do
      ::Timeout.timeout(simple_exec_timeout) do
        pipe = ::IO.pipe
        producer = proc do
          $stderr.write "hello"
        end
        exec.exec_proc(producer, err: pipe, background: true)
        consumer = proc do
          puts("#{$stdin.read} world")
        end
        output = exec.capture_proc(consumer, in: pipe)
        assert_equal("hello world\n", output)
      end
    end

    it "inherits parent streams by default when running in the foreground" do
      ::Timeout.timeout(simple_exec_timeout) do
        func = proc do
          f = proc do
            if gets == "hello"
              puts "abc"
              warn "def"
              exit(2)
            else
              exit(1)
            end
          end
          r = exec.exec_proc(f)
          exit(r.exit_code)
        end
        result = exec.exec_proc(func, out: :capture, err: :capture, in: [:string, "hello"])
        assert_equal(2, result.exit_code)
        assert_equal("abc\n", result.captured_out)
        assert_equal("def\n", result.captured_err)
      end
    end

    it "redirects to null by default when running in the background" do
      ::Timeout.timeout(simple_exec_timeout) do
        func = proc do
          f = proc do
            if gets.nil?
              puts "abc"
              warn "def"
              exit(2)
            else
              exit(1)
            end
          end
          r = exec.exec_proc(f, background: true).result(timeout: 0.5)
          exit(r.exit_code)
        end
        result = exec.exec_proc(func, out: :capture, err: :capture, in: [:string, "hello"])
        assert_equal(2, result.exit_code)
        assert_equal("", result.captured_out)
        assert_equal("", result.captured_err)
      end
    end
  end

  describe "controller" do
    it "gets the name" do
      ::Timeout.timeout(simple_exec_timeout) do
        result = exec.exec(["echo", "hi"], out: :capture, name: "my-echo") do |c|
          assert_equal("my-echo", c.name)
        end
        assert_equal("my-echo", result.name)
      end
    end

    it "reads and writes streams" do
      ::Timeout.timeout(ruby_exec_timeout) do
        result = exec.ruby(["-e", 'STDOUT.puts "1"; STDOUT.flush;' \
                                  ' exit(1) unless STDIN.gets == "2\n";' \
                                  ' STDERR.puts "3"; STDERR.flush ' \
                                  ' exit(1) unless STDIN.gets == "4\n"'],
                           out: :controller, err: :controller, in: :controller) do |c|
          assert_equal("1\n", c.out.gets)
          c.in.puts("2")
          c.in.flush
          assert_equal("3\n", c.err.gets)
          c.in.puts("4")
          c.in.flush
        end
        assert_equal(0, result.exit_code)
        assert_nil(result.captured_out)
        assert_nil(result.captured_err)
      end
    end

    it "closes input stream at the end of the block" do
      ::Timeout.timeout(ruby_exec_timeout) do
        result = exec.ruby(["-e", "i=0; while gets; i+=1; end; sleep(0.1); exit(i)"],
                           in: :controller) do |c|
          assert_nil(c.out)
          assert_nil(c.err)
          c.in.puts("A")
          c.in.puts("B")
          c.in.puts("C")
        end
        assert_equal(3, result.exit_code)
      end
    end

    it "captures streams" do
      ::Timeout.timeout(ruby_exec_timeout) do
        result = exec.ruby(["-e", 'STDOUT.puts "hello"; STDERR.puts "world"'],
                           out: :controller, err: :controller) do |controller|
          controller.capture_out
          controller.capture_err
        end
        assert_equal("hello\n", result.captured_out)
        assert_equal("world\n", result.captured_err)
      end
    end

    it "handles file redirects" do
      ::FileUtils.mkdir_p(tmp_dir)
      ::FileUtils.rm_rf(output_path)
      ::Timeout.timeout(ruby_exec_timeout) do
        exec.ruby(["-e", 'puts(gets + "world\n")'],
                  in: :controller, out: :controller) do |controller|
          controller.redirect_in(input_path)
          controller.redirect_out(output_path)
        end
        assert_equal("hello\nworld\n", ::File.read(output_path))
      end
      ::FileUtils.rm_rf(tmp_dir)
    end

    it "detects if the command fails" do
      ::Timeout.timeout(ruby_exec_timeout) do
        exec.exec(["blah"]) do |controller|
          assert_nil(controller.pid)
          refute_nil(controller.exception)
        end
      end
    end
  end

  describe "backgrounding" do
    it "determines whether processes are executing" do
      ::Timeout.timeout(ruby_exec_timeout * 2) do
        controller1 = exec.exec("sleep 1.5", background: true)
        controller2 = exec.exec("sleep 0.5", background: true)
        sleep(0.1)
        assert_equal(true, controller1.executing?)
        assert_equal(true, controller2.executing?)
        sleep(0.9)
        assert_equal(true, controller1.executing?)
        assert_equal(false, controller2.executing?)
        sleep(1.0)
        assert_equal(false, controller1.executing?)
        assert_equal(false, controller2.executing?)
      end
    end

    it "waits for results and captures output" do
      ::Timeout.timeout(ruby_exec_timeout * 2) do
        controller1 = exec.ruby(["-e", 'sleep 1.5; puts "hi1"; exit 1'],
                                background: true, out: :capture)
        controller2 = exec.ruby(["-e", 'sleep 0.2; puts "hi2"; exit 2'],
                                background: true, out: :capture)
        result2 = controller2.result
        assert_equal(2, result2.exit_code)
        assert_equal("hi2\n", result2.captured_out)
        assert_equal(true, controller1.executing?)
        assert_equal(false, controller2.executing?)
        result1 = controller1.result
        assert_equal(1, result1.exit_code)
        assert_equal("hi1\n", result1.captured_out)
        assert_equal(false, controller1.executing?)
      end
    end

    it "times out waiting for results" do
      ::Timeout.timeout(ruby_exec_timeout) do
        controller = exec.ruby(["-e", 'sleep 0.2; puts "hi"; exit 1'],
                               background: true, out: :capture)
        assert_nil(controller.result(timeout: 0.1))
        assert_equal(true, controller.executing?)
        result = controller.result
        assert_equal(1, result.exit_code)
        assert_equal("hi\n", result.captured_out)
        assert_equal(false, controller.executing?)
      end
    end
  end

  describe "environment setting" do
    it "is passed into the subprocess" do
      ::Timeout.timeout(ruby_exec_timeout) do
        result = exec.ruby(["-e", 'puts ENV["FOOBAR"]'], out: :capture, env: {"FOOBAR" => "hello"})
        assert_equal("hello\n", result.captured_out)
      end
    end
  end

  describe "default options" do
    it "is reflected in spawned processes" do
      ::Timeout.timeout(simple_exec_timeout) do
        exec.configure_defaults(out: :capture)
        result = exec.exec("echo hello")
        assert_equal("hello\n", result.captured_out)
      end
    end

    it "can be overridden in spawned processes" do
      ::Timeout.timeout(simple_exec_timeout) do
        exec.configure_defaults(out: :capture)
        result = exec.exec("echo hello", out: :controller) do |c|
          assert_equal("hello\n", c.out.gets)
        end
        assert_nil(result.captured_out)
      end
    end
  end
end
