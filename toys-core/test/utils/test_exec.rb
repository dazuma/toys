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

require "helper"
require "timeout"
require "fileutils"

describe Toys::Utils::Exec do
  let(:exec) { Toys::Utils::Exec.new }
  let(:tmp_dir) { ::File.join(::File.dirname(::File.dirname(__dir__)), "tmp") }
  let(:input_path) { ::File.join(::File.dirname(__dir__), "data", "input.txt") }
  let(:output_path) { ::File.join(tmp_dir, "output.txt") }

  describe "exit codes" do
    it "detects zero exit codes" do
      ::Timeout.timeout(1) do
        result = exec.ruby(["-e", "exit 0"])
        assert_equal(0, result.exit_code)
        assert_equal(true, result.success?)
        assert_equal(false, result.error?)
      end
    end

    it "detects nonzero exit codes" do
      ::Timeout.timeout(1) do
        result = exec.ruby(["-e", "exit 3"])
        assert_equal(3, result.exit_code)
        assert_equal(false, result.success?)
        assert_equal(true, result.error?)
      end
    end
  end

  describe "command form" do
    it "recongizes arrays" do
      ::Timeout.timeout(1) do
        result = exec.exec(["echo", "hi"], out: :capture)
        assert_equal("hi\n", result.captured_out)
      end
    end

    it "handles a single element array" do
      ::Timeout.timeout(1) do
        result = exec.exec(["echo"], out: :capture)
        assert_equal("\n", result.captured_out)
      end
    end

    it "recongizes strings as shell commands" do
      ::Timeout.timeout(1) do
        result = exec.exec("BLAHXYZBLAH=hi env | grep BLAHXYZBLAH", out: :capture)
        assert_equal("BLAHXYZBLAH=hi\n", result.captured_out)
      end
    end

    it "recongizes an array with argv0" do
      ::Timeout.timeout(1) do
        result = exec.exec([["sh", "meow"], "-c", "echo $0"], out: :capture)
        assert_equal("meow\n", result.captured_out)
      end
    end
  end

  describe "stream handling for spawn" do
    it "captures stdout and stderr" do
      ::Timeout.timeout(1) do
        result = exec.ruby(["-e", '$stdout.puts "hello"; $stderr.puts "world"'],
                           out: :capture, err: :capture)
        assert_equal("hello\n", result.captured_out)
        assert_equal("world\n", result.captured_err)
      end
    end

    it "writes a string to stdin" do
      ::Timeout.timeout(1) do
        result = exec.ruby(["-e", 'exit gets == "hello" ? 0 : 1'], in: [:string, "hello"])
        assert_equal(0, result.exit_code)
      end
    end

    it "combines err into out" do
      ::Timeout.timeout(1) do
        result = exec.ruby(["-e", '$stdout.puts "hello"; $stderr.puts "world"'],
                           out: :capture, err: [:child, :out])
        assert_match(/hello/, result.captured_out)
        assert_match(/world/, result.captured_out)
      end
    end

    it "handles StringIO" do
      ::Timeout.timeout(1) do
        input = ::StringIO.new("hello\n")
        output = ::StringIO.new
        exec.ruby(["-e", 'puts(gets + "world\n")'], in: input, out: output)
        assert_equal("hello\nworld\n", output.string)
      end
    end

    it "handles file redirects" do
      ::FileUtils.mkdir_p(tmp_dir)
      ::FileUtils.rm_rf(output_path)
      ::Timeout.timeout(1) do
        exec.ruby(["-e", 'puts(gets + "world\n")'],
                  in: [:file, input_path], out: [:file, output_path])
        assert_equal("hello\nworld\n", ::File.read(output_path))
      end
    end

    it "interprets bare strings as file names" do
      ::FileUtils.mkdir_p(tmp_dir)
      ::FileUtils.rm_rf(output_path)
      ::Timeout.timeout(1) do
        exec.ruby(["-e", 'puts(gets + "world\n")'],
                  in: input_path, out: output_path)
        assert_equal("hello\nworld\n", ::File.read(output_path))
      end
    end
  end

  describe "stream handling for fork" do
    it "captures stdout and stderr" do
      ::Timeout.timeout(1) do
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
      ::Timeout.timeout(1) do
        func = proc do
          exit gets == "hello" ? 0 : 1
        end
        result = exec.exec_proc(func, in: [:string, "hello"])
        assert_equal(0, result.exit_code)
      end
    end

    it "combines err into out" do
      ::Timeout.timeout(1) do
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
      ::Timeout.timeout(1) do
        input = ::StringIO.new("hello\n")
        output = ::StringIO.new
        func = proc do
          puts(gets + "world\n")
        end
        exec.exec_proc(func, in: input, out: output)
        assert_equal("hello\nworld\n", output.string)
      end
    end

    it "handles file redirects" do
      ::FileUtils.mkdir_p(tmp_dir)
      ::FileUtils.rm_rf(output_path)
      ::Timeout.timeout(1) do
        func = proc do
          puts(gets + "world\n")
        end
        exec.exec_proc(func, in: [:file, input_path], out: [:file, output_path])
        assert_equal("hello\nworld\n", ::File.read(output_path))
      end
    end

    it "closes stdin" do
      ::Timeout.timeout(1) do
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
      ::Timeout.timeout(1) do
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
      ::Timeout.timeout(1) do
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
      ::Timeout.timeout(1) do
        func = proc do
          exit gets.nil? ? 0 : 1
        end
        result = exec.exec_proc(func, in: :null)
        assert_equal(0, result.exit_code)
      end
    end

    it "redirects stdout to null" do
      ::Timeout.timeout(1) do
        func = proc do
          puts "THIS SHOULD NOT BE DISPLAYED."
        end
        result = exec.exec_proc(func, out: :null)
        assert_equal(0, result.exit_code)
      end
    end

    it "redirects stderr to null" do
      ::Timeout.timeout(1) do
        func = proc do
          warn "THIS SHOULD NOT BE DISPLAYED."
        end
        result = exec.exec_proc(func, err: :null)
        assert_equal(0, result.exit_code)
      end
    end
  end

  describe "controller" do
    it "reads and writes streams" do
      ::Timeout.timeout(1) do
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
      ::Timeout.timeout(1) do
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
  end

  describe "environment setting" do
    it "is passed into the subprocess" do
      result = exec.ruby(["-e", 'puts ENV["FOOBAR"]'],
                         out: :capture, env: {"FOOBAR" => "hello"})
      assert_equal("hello\n", result.captured_out)
    end
  end

  describe "default options" do
    it "is reflected in spawned processes" do
      exec.configure_defaults(out: :capture)
      result = exec.ruby(["-e", 'puts "hello"'])
      assert_equal("hello\n", result.captured_out)
    end

    it "can be overridden in spawned processes" do
      exec.configure_defaults(out: :capture)
      result = exec.ruby(["-e", 'puts "hello"'], out: :controller) do |c|
        assert_equal("hello\n", c.out.gets)
      end
      assert_nil(result.captured_out)
    end
  end
end
