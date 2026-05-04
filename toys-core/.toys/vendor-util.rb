# frozen_string_literal: true

desc "Vendor certain gems into toys-core"

long_desc \
  "Copies source files from certain external gems, consolidating them into" \
  " a single file under lib/toys/utils, and renaming the classes to live" \
  " under Toys::Utils.",
  "",
  "The source gem is expected to live in a sibling directory of the toys" \
  " monorepo by default. Use --source to point at a different location."

GEM_DATA = {
  "exec" => {
    source_gem: "exec_service",
    source_class: "ExecService",
    source_files: ["lib/exec_service.rb", "lib/exec_service/*.rb"],
    dest_class: "Exec",
  },
  "xdg" => {
    source_gem: "simple_xdg",
    source_class: "SimpleXDG",
    source_files: ["lib/simple_xdg.rb", "lib/simple_xdg/*.rb"],
    dest_class: "XDG",
  },
  "git_cache" => {
    source_gem: "git_cache",
    source_class: "GitCache",
    source_files: ["lib/git_cache.rb", "lib/git_cache/*.rb"],
    dest_class: "GitCache",
    additional_changes: {
      /\bExecService\b/ => "Toys::Utils::Exec",
      /\bSimpleXDG\b/ => "Toys::Utils::XDG",
      /\bGIT_CACHE_WRITABLE\b/ => "TOYS_GIT_CACHE_WRITABLE",
      'require "exec_service"' => 'require "toys/utils/exec"',
      'require "simple_xdg"' => 'require "toys/utils/xdg"',
    },
  },
}

flag(:all, "--all[=BASE_PATH]") do
  desc "Copy all known util sources (#{GEM_DATA.keys.inspect}) from the optional given base path"
end
remaining_args(:libraries) do
  desc "A list of sources to copy (valid values: #{GEM_DATA.keys.inspect})"
  accept(GEM_DATA.keys)
end

def run
  setup
  libraries.each do |libspec|
    name, path = libspec.split(":")
    setup_lib(name, path)
    copy_lib
  end
end

def setup
  Dir.chdir(context_directory)
  if all
    GEM_DATA.keys.each do |name|
      next if libraries.any? { |lib| lib =~ /^#{name}(:|$)/ }
      if all == true
        libraries.append(name)
      else
        path = File.join(all, name)
        libraries.append("#{name}:#{path}")
      end
    end
  end
  if libraries.empty?
    logger.error("No libraries specified")
    exit(-1)
  end
end

def setup_lib(name, path)
  gem_data = GEM_DATA[name]
  @dest_filebase = name
  @dest_path = ::File.expand_path("lib/toys/utils/#{name}.rb")
  @dest_class = gem_data[:dest_class]
  @source_gem_name = gem_data[:source_gem]
  @source_class = gem_data[:source_class]
  @additional_changes = gem_data[:additional_changes] || {}
  source_root = ::File.expand_path(path || "../../#{@source_gem_name}")
  unless ::File.directory?(source_root)
    logger.error("Source directory not found: #{source_root}")
    exit(1)
  end
  @source_files = []
  gem_data[:source_files].each do |glob|
    ::Dir.glob(glob, base: source_root) do |path|
      @source_files << ::File.expand_path(path, source_root)
    end
  end
  @source_files.uniq!
  @source_files.each do |path|
    next if ::File.file?(path)
    logger.error("Source file not found: #{path}")
    exit(1)
  end
end

def copy_lib
  body = @source_files.map { |path| build_source(path) }.join("\n")
  output = wrap(body)
  ::File.write(@dest_path, output)
  logger.info("Wrote #{@dest_path}")
end

def build_source(path)
  lines = ::File.readlines(path)
  lines = lines.reject { |line| line =~ /\A\s*#\s*frozen_string_literal:/ }
  lines = lines.reject { |line| line =~ /\A\s*require\s+"#{@source_gem_name}\// }
  lines = lines.drop_while { |line| line.strip.empty? }
  lines.join
end

def wrap(body)
  body = rename(body)
  body = indent(body, "    ")
  <<~HEADER + body + <<~FOOTER
    # frozen_string_literal: true

    # This file is vendored from the #{@source_gem_name} gem.
    # Do not edit directly; run `toys vendor-util #{@dest_filebase}` to regenerate.

    module Toys
      module Utils
  HEADER
      end
    end
  FOOTER
end

def rename(content)
  content = content
    .gsub(/\bclass\s+#{@source_class}\b/, "class #{@dest_class}")
    .gsub(/(?<!class |\w)#{@source_class}\b/, "Toys::Utils::#{@dest_class}")
    .gsub(/require "#{@source_gem_name}"/, "require \"toys/utils/#{@dest_filebase}\"")
  @additional_changes.each do |from, to|
    content = content.gsub(from, to)
  end
  content
end

def indent(content, prefix)
  content.each_line.map { |line| line.strip.empty? ? line : prefix + line }.join
end
