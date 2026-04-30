# frozen_string_literal: true

desc "Vendor the exec_service gem into toys-core as Toys::Utils::Exec"

long_desc \
  "Copies source files from the exec_service gem and consolidates them into" \
  " a single file at lib/toys/utils/exec.rb, renaming the ExecService class" \
  " to Toys::Utils::Exec.",
  "",
  "The exec_service gem is expected to live in a sibling directory of the" \
  " toys monorepo by default. Use --source to point at a different location."

flag :source_dir, "--source=PATH",
     default: ::File.expand_path("../../../exec_service", __dir__),
     desc: "Path to the exec_service gem checkout"

DEPENDENT_FILES = [
  "controller.rb",
  "executor.rb",
  "opts.rb",
  "result.rb",
  "version.rb",
].freeze

DEST_PATH = ::File.expand_path("../lib/toys/utils/exec.rb", __dir__)

def run
  source_root = ::File.expand_path(source_dir)
  unless ::File.directory?(source_root)
    logger.error("Source directory not found: #{source_root}")
    exit(1)
  end

  main_path = ::File.join(source_root, "lib", "exec_service.rb")
  dep_paths = DEPENDENT_FILES.map { |name| ::File.join(source_root, "lib", "exec_service", name) }
  [main_path, *dep_paths].each do |path|
    next if ::File.file?(path)
    logger.error("Source file not found: #{path}")
    exit(1)
  end

  body = build_main(main_path)
  dep_paths.each do |path|
    body << "\n"
    body << build_dependent(path)
  end

  output = wrap(body, source_root)
  ::File.write(DEST_PATH, output)
  logger.info("Wrote #{DEST_PATH}")
end

def build_main(path)
  lines = ::File.readlines(path)
  lines = strip_frozen_string_literal(lines)
  lines = lines.reject { |line| line =~ /\A\s*require\s+["']exec_service\// }
  lines = lines.drop_while { |line| line.strip.empty? }
  lines.join
end

def build_dependent(path)
  lines = ::File.readlines(path)
  lines = strip_frozen_string_literal(lines)
  lines = lines.drop_while { |line| line.strip.empty? }
  lines.join
end

def strip_frozen_string_literal(lines)
  lines.reject { |line| line =~ /\A\s*#\s*frozen_string_literal:/ }
end

def wrap(body, source_root)
  body = rename(body)
  body = indent(body, "    ")
  <<~HEADER + body + <<~FOOTER
    # frozen_string_literal: true

    # This file is vendored from the exec_service gem.
    # Do not edit directly; run `toys vendor-exec` to regenerate.

    module Toys
      module Utils
  HEADER
      end
    end
  FOOTER
end

def rename(content)
  content
    .gsub(/\bclass\s+ExecService\b/, "class Exec")
    .gsub(/\bExecService\b/, "Toys::Utils::Exec")
    .gsub(/require "exec_service"/, 'require "toys/utils/exec"')
end

def indent(content, prefix)
  content.each_line.map { |line| line.strip.empty? ? line : prefix + line }.join
end
