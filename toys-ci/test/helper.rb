# frozen_string_literal: true

require "minitest/autorun"
require "minitest/focus"
require "minitest/mock"
require "minitest/rg"

require "toys-ci"

::Toys.executable_path = ::ENV["TOYS_BIN_PATH"]

module Toys
  module TestHelper
    class DummyResult
      def initialize(captured_out = nil)
        @success = !captured_out.nil?
        @captured_out = captured_out.to_s
      end

      attr_reader :captured_out

      def success?
        @success
      end
    end

    class << self
      def stub_changed_files(context, ref, files, &block)
        if block
          stub_changed_files_in_block(context, ref, files, block)
        else
          stub_changed_files_permanently(context, ref, files)
        end
      end

      private

      def stub_changed_files_in_block(context, ref, files, block)
        sha = make_dummy_sha
        callable = proc do |cmd, **_kwargs|
          if cmd == ["git", "rev-parse", ref]
            DummyResult.new(sha)
          elsif cmd == ["git", "diff", "--name-only", sha]
            DummyResult.new(files&.join("\n"))
          else
            raise "Unknown command: #{cmd.inspect}"
          end
        end
        context.stub(:exec, callable, &block)
      end

      def stub_changed_files_permanently(context, ref, files)
        sha = make_dummy_sha
        original_method = context.method(:exec)
        context.define_singleton_method(:exec) do |cmd, **kwargs, &block|
          if cmd == ["git", "rev-parse", ref]
            DummyResult.new(sha)
          elsif cmd == ["git", "diff", "--name-only", sha]
            DummyResult.new(files&.join("\n"))
          else
            original_method.call(cmd, **kwargs, &block)
          end
        end
      end

      def make_dummy_sha
        rand(0x10000000000000000000000000000000000000000).to_s(16).rjust(8, "0")
      end
    end
  end
end
