# frozen_string_literal: true

# Run this against local Toys code instead of installed Toys gems.
# This is to support development of Toys itself. Most Toys files should not
# include this.
::Kernel.exec(::File.join(context_directory, "toys-dev"), *::ARGV) unless ::ENV["TOYS_DEV"]
