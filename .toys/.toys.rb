# frozen_string_literal: true

# Copyright 2019 Daniel Azuma
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.
;

# Run this against local Toys code instead of installed Toys gems.
# This is to support development of Toys itself. Most Toys files should not
# include this.
::Kernel.exec(::File.join(context_directory, "toys-dev"), *::ARGV) unless ::ENV["TOYS_DEV"]

include :gems, suppress_confirm: true
gem "highline", "~> 2.0"
gem "minitest", "~> 5.13"
gem "minitest-focus", "~> 1.1"
gem "minitest-rg", "~> 5.2"
gem "rake", "~> 13.0"
gem "rdoc", "~> 6.1.2"
gem "redcarpet", "~> 3.5" unless ::RUBY_PLATFORM == "java"
gem "rspec", "~> 3.9"
gem "rubocop", "~> 0.78.0"
gem "yard", "~> 0.9.20"
