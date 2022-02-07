# frozen_string_literal: true

desc "Prepare toys-core Ruby files for documenting"

flag :optimize, "--[no-]optimize" do
  default true
  desc "Remove unused code (default is true)"
end

include :fileutils

CORE_DOCS_DIR = "core-docs"

def run
  cd(context_directory)
  copy_files
  Dir.glob("#{CORE_DOCS_DIR}/**/*.rb") do |path|
    orig_content = File.read(path)
    content = orig_content.dup
    if optimize
      remove_private_docs(content)
      remove_private_class_section(content)
      remove_toplevel_cruft(content)
      replace_method_source(content)
      remove_bare_blocks(content)
      remove_extra_vertical_space(content)
    end
    add_notice(content)
    unless content == orig_content
      File.open(path, "w") { |file| file.write(content) }
    end
  end
end

def copy_files
  core_lib_dir = ::File.join(::File.dirname(context_directory), "toys-core", "lib")
  rm_rf(CORE_DOCS_DIR)
  cp_r(core_lib_dir, CORE_DOCS_DIR)
end

def remove_private_docs(content)
  content.gsub!(/^(?<in> *)  ##\n(?:\k<in>  #[^\n]*\n)*\k<in>  # @private\n(?:\k<in>  #[^\n]*\n)*\k<in>  [A-Z_]+ =[^\n]*\n(?:\k<in>  [^#\n][^\n]*\n)*(?<end>\k<in>end\n|\n)/, "\\k<end>")
  content.gsub!(/^(?<in> *)##\n(?:\k<in>#[^\n]*\n)*\k<in># @private\n(?:\k<in>#[^\n]*\n)*\k<in>attr_\w+ :\w+\n/, "")
  loop do
    break unless content.gsub!(/^(?<in> *)##\n(?:\k<in>#[^\n]*\n)*\k<in># @private\n(?:\k<in>#[^\n]*\n)*\k<in>(?:class|module|def) [^\n]+\n+(?:\k<in>  [^\n]+\n+|\k<in>(?:rescue|ensure)[^\n]*\n+)*\k<in>end\n/, "")
  end
end

def remove_private_class_section(content)
  loop do
    break unless content.gsub!(/^(?<keep>(?<in> *)(?:class|module) [^\n]+\n+(?:\k<in>  [^\n]*\n+)*)\k<in>  private\n+(?:\k<in>  [^\n]+\n+)*\k<in>end\n/, "\\k<keep>\\k<in>end\n")
  end
end

def remove_toplevel_cruft(content)
  content.gsub!(/^require "[^"]+"\n/, "")
  content.gsub!(/\A# frozen_string_literal: true\n\n/, "")
end

def replace_method_source(content)
  content.gsub!(/^(?<in> *)(?<sig>def [^\s()]+(?:\([^)]*\))?)(?: # [^\n]+)?\n+(?:\k<in>  [^\n]+\n+|\k<in>(?:rescue|ensure)[^\n]*\n+)*\k<in>end\n/, "\\k<in>\\k<sig>\n\\k<in>  # Source available in the toys-core gem\n\\k<in>end\n")
end

def remove_bare_blocks(content)
  content.gsub!(/^(?<in> *)(?:\w+ = proc|on_initialize|on_include) do[^\n]*\n(?:\k<in>  [^\n]*\n+)*\k<in>end\n/, "")
end

def remove_extra_vertical_space(content)
  content.gsub!(/\n\n\n+/, "\n\n")
  loop do
    break unless content.gsub!(/\n+(?<keep>\n *end\n)/, "\\k<keep>")
  end
  content.gsub!(/^(?<keep> *(?:class|module) [^\n]+\n)\n+/, "\\k<keep>")
  content.gsub!(/\A\n+/, "")
  content.gsub!(/\n\n+\z/, "\n")
end

def add_notice(content)
  content.gsub!(/^(?<in> *)##\n(?<def>(?:\k<in>#[^\n]*\n)+\k<in>(?:module|class) [A-Z]\w+)/, "\\k<in>##\n\\k<in># **_Defined in the toys-core gem_**\n\\k<in>#\n\\k<def>")
end
