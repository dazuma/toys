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

require "monitor"

module Toys
  module Helpers
    ##
    # A module that provides a spinner output.
    #
    module Spinner
      ##
      # Default length of a single frame, in seconds.
      # @return [Float]
      #
      DEFAULT_FRAME_LENGTH = 0.1

      ##
      # Default set of frames.
      # @return [Array<String,Array(String,Integer)>]
      #
      DEFAULT_FRAMES = ["-", "\\", "|", "/"].freeze

      ##
      # Display a spinner during a task. You should provide a block that
      # performs the long-running task. While the block is executing, a
      # spinner will be displayed.
      #
      # @param [String] leading_text Optional leading string to display to the
      #     left of the spinner.
      # @param [Float] frame_length Length of a single frame, in seconds.
      #     Defaults to {DEFAULT_FRAME_LENGTH}.
      # @param [Array<String,Array<String>>] frames An array of frames. Each
      #     frame should be either a string, or a two-element array of string
      #     and integer, where the integer is the visible length of the frame
      #     on screen. The latter form should be used if the frame string
      #     contains non-printing characters such as ANSI escape codes.
      #     Defaults to {DEFAULT_FRAMES}.
      # @param [IO] stream Stream to output the spinner to. Defaults to STDOUT.
      #     Note the spinner will be disabled if this stream is not a tty.
      # @param [String] final_text Optional final string to display when the
      #     spinner is complete.
      #
      def spinner(leading_text: "",
                  frame_length: DEFAULT_FRAME_LENGTH,
                  frames: DEFAULT_FRAMES,
                  stream: $stdout,
                  final_text: "")
        return nil unless block_given?
        unless leading_text.empty?
          stream.write(leading_text)
          stream.flush
        end
        spin = SpinDriver.new(stream, frames, frame_length)
        begin
          yield
        ensure
          spin.stop
          unless final_text.empty?
            stream.write(final_text)
            stream.flush
          end
        end
      end

      ## @private
      class SpinDriver
        include ::MonitorMixin

        def initialize(stream, frames, frame_length)
          @stream = stream
          @frames = frames.map { |f| f.is_a?(::Array) ? f : [f, f.size] }
          @frame_length = frame_length
          @cur_frame = 0
          @stopping = false
          @cond = new_cond
          super()
          @thread = @stream.tty? ? start_thread : nil
        end

        def stop
          synchronize do
            @stopping = true
            @cond.broadcast
          end
          @thread.join if @thread
          self
        end

        private

        def start_thread
          ::Thread.new do
            synchronize do
              until @stopping
                @stream.write(@frames[@cur_frame][0])
                @stream.flush
                @cond.wait(@frame_length)
                size = @frames[@cur_frame][1]
                @stream.write("\b" * size + " " * size + "\b" * size)
                @cur_frame += 1
                @cur_frame = 0 if @cur_frame >= @frames.size
              end
            end
          end
        end
      end
    end
  end
end
