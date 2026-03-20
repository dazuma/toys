# frozen_string_literal: true

require "erb"
require "fileutils"

module Toys
  module Release
    ##
    # Logic for generating and updating gh-pages documentation site files.
    #
    class GhPagesLogic
      ##
      # Create a GhPagesLogic instance.
      #
      # @param repo_settings [Toys::Release::RepoSettings] Repository settings
      #
      def initialize(repo_settings)
        @enabled_component_settings = repo_settings.all_component_settings.select(&:gh_pages_enabled)
        raise ::ArgumentError, "No components have gh-pages enabled" if @enabled_component_settings.empty?
        @url_base_path = "#{repo_settings.repo_owner}.github.io/#{repo_settings.repo_name}"
        @default_redirect_url = "https://#{component_base_path(@enabled_component_settings.first)}/latest"
      end

      ##
      # Clean up non-index files from the v0 subdirectory of each gh-pages-
      # enabled component. The given block is called for each component whose
      # v0 directory contains files other than index.html, and receives the
      # directory path and the list of files to remove. The block should return
      # true to remove the files, or false to skip. If no block is given, files
      # are removed unconditionally.
      #
      # @param gh_pages_dir [String] Path to the gh-pages working tree
      # @yieldparam directory [String] Path relative to gh_pages_dir of the v0 dir
      # @yieldparam children [Array<String>] Non-index filenames to remove
      # @yieldreturn [boolean] Whether to remove the files
      # @return [Array<Hash>] Results, one per enabled component, each with
      #     keys :directory (relative path), :children, and :removed
      #
      def cleanup_v0_directories(gh_pages_dir, &confirm)
        @enabled_component_settings.map do |comp_settings|
          cleanup_component_v0(gh_pages_dir, comp_settings, &confirm)
        end
      end

      ##
      # Generate all gh-pages scaffold files into the given directory.
      # The given block is called for each file that needs to be created or
      # overwritten (but NOT for unchanged files), and receives the destination
      # path, the status (:new or :overwrite), and the existing file type
      # (only meaningful for :overwrite). The block should return true to
      # write the file, or false to skip.
      #
      # @param gh_pages_dir [String] Path to the gh-pages working tree
      # @param template_dir [String] Path to the directory containing ERB
      #     templates for gh-pages files
      # @yieldparam destination [String] Path relative to gh_pages_dir of the destination file
      # @yieldparam status [Symbol] :new or :overwrite
      # @yieldparam existing_ftype [String,nil] The ftype of the existing entry
      # @yieldreturn [boolean] Whether to write the file
      # @return [Array<Hash>] Results, one per file considered, each with
      #     keys :destination (relative path) and :outcome (:wrote, :skipped, or :unchanged)
      #
      def generate_files(gh_pages_dir, template_dir, &confirm)
        results = []
        @enabled_component_settings.each do |comp_settings|
          generate_component_files(gh_pages_dir, template_dir, comp_settings, results, &confirm)
        end
        generate_toplevel_files(gh_pages_dir, template_dir, results, &confirm)
        generate_html404(gh_pages_dir, template_dir, results, &confirm)
        results
      end

      ##
      # Update the 404 page and redirect index pages for a new component
      # release. The optional block is called with a warning message when a
      # required file is not found.
      #
      # @param gh_pages_dir [String] Path to the gh-pages working tree
      # @param component_settings [Toys::Release::ComponentSettings] Settings
      #     for the component being released
      # @param version [Gem::Version] The new version being released
      # @yieldparam warning [String] A warning message for a missing file
      #
      def update_version_pages(gh_pages_dir, component_settings, version, &on_warning)
        update_404_page(gh_pages_dir, component_settings, version, &on_warning)
        update_index_pages(gh_pages_dir, component_settings, version, &on_warning)
      end

      private

      # Context object for ERB template rendering
      class ErbContext
        def initialize(data)
          data.each { |name, value| instance_variable_set("@#{name}", value) }
          freeze
        end

        # @private
        def self.get(data)
          new(data).instance_eval { binding }
        end
      end
      private_constant :ErbContext

      # Struct carrying info about a component for the 404 template
      CompInfo = ::Struct.new(:base_path, :regexp_source, :version_var)
      private_constant :CompInfo

      # Cleans up a single component's v0 directory, yielding to the caller for confirmation.
      def cleanup_component_v0(gh_pages_dir, comp_settings)
        relative_dir = simplifying_join(comp_settings.gh_pages_directory, "v0")
        directory = ::File.expand_path(relative_dir, gh_pages_dir)
        ::FileUtils.mkdir_p(directory)
        children = ::Dir.children(directory) - ["index.html"]
        removed = false
        if !children.empty? && (!block_given? || yield(relative_dir, children))
          children.each { |child| ::FileUtils.remove_entry(::File.join(directory, child), true) }
          removed = true
        end
        {directory: relative_dir, children: children, removed: removed}
      end

      # Returns the URL base path for a component, incorporating its gh_pages_directory if set.
      def component_base_path(comp_settings)
        simplifying_join(@url_base_path, comp_settings.gh_pages_directory)
      end

      # Scans the component's gh-pages directory and returns the highest existing released version,
      # or "0" if no versioned subdirectories exist yet.
      def current_component_version(gh_pages_dir, comp_settings)
        base_dir = ::File.expand_path(comp_settings.gh_pages_directory, gh_pages_dir)
        latest = ::Gem::Version.new("0")
        return latest unless ::File.directory?(base_dir)
        ::Dir.children(base_dir).each do |child|
          next unless /^v\d+(\.\d+)*$/.match?(child)
          next unless ::File.directory?(::File.join(base_dir, child))
          version = ::Gem::Version.new(child[1..])
          latest = version if version > latest
        end
        latest
      end

      # Renders an ERB template from template_dir with the given data hash and returns the result.
      def render_template(template_dir, template_name, data)
        template_path = ::File.join(template_dir, template_name)
        raise "Unable to find template #{template_name}" unless ::File.file?(template_path)
        erb = ::ERB.new(::File.read(template_path))
        erb.result(ErbContext.get(data))
      end

      # Updates the version variable assignment in 404.html for the given component.
      def update_404_page(gh_pages_dir, component_settings, version)
        path = ::File.join(gh_pages_dir, "404.html")
        unless ::File.file?(path)
          yield "404.html not found. Skipping." if block_given?
          return
        end
        content = ::File.read(path)
        version_var = component_settings.gh_pages_version_var
        content.sub!(/#{::Regexp.escape(version_var)} = "[\w.]+";/,
                     "#{version_var} = \"#{version}\";")
        ::File.write(path, content)
      end

      # Updates the redirect URLs in index.html and latest/index.html to point at the new version.
      def update_index_pages(gh_pages_dir, component_settings, version)
        redirect_url = "https://#{component_base_path(component_settings)}/v#{version}"
        ["index.html", "latest/index.html"].each do |filename|
          relative_path = simplifying_join(component_settings.gh_pages_directory, filename)
          absolute_path = ::File.expand_path(relative_path, gh_pages_dir)
          unless ::File.file?(absolute_path)
            yield "#{relative_path} not found. Skipping." if block_given?
            next
          end
          content = ::File.read(absolute_path)
          content.gsub!(/ href="[^"]+"/, " href=\"#{redirect_url}\"")
          content.gsub!(/ content="0; url=[^"]+"/, " content=\"0; url=#{redirect_url}\"")
          content.gsub!(/window\.location\.replace\("[^"]+"\)/, "window.location.replace(\"#{redirect_url}\")")
          ::File.write(absolute_path, content)
        end
      end

      # Returns File.lstat for path, or nil if the path does not exist.
      def safe_lstat(path)
        ::File.lstat(path)
      rescue ::SystemCallError
        nil
      end

      # Returns the contents of path as a string, or nil if the file cannot be read.
      def safe_read(path)
        ::File.read(path)
      rescue ::SystemCallError
        nil
      end

      # Joins paths, simplifying if either argument is "."
      def simplifying_join(path1, path2)
        if path1 == "."
          path2
        elsif path2 == "."
          path1
        else
          "#{path1}/#{path2}"
        end
      end

      # Writes content to a relative destination, appending to results. Skips unchanged files
      # without calling the block; calls the block for new or overwrite cases to confirm.
      def write_file(gh_pages_dir, relative_destination, content, results, &confirm)
        destination = ::File.expand_path(relative_destination, gh_pages_dir)
        stat = safe_lstat(destination)
        if stat
          if stat.file? && safe_read(destination) == content
            results << {destination: relative_destination, outcome: :unchanged}
            return
          end
          status = :overwrite
          ftype = stat.ftype
        else
          status = :new
          ftype = nil
        end
        proceed = confirm ? confirm.call(relative_destination, status, ftype) : true
        if proceed
          ::FileUtils.mkdir_p(::File.dirname(destination))
          ::FileUtils.remove_entry(destination, true) if stat
          ::File.write(destination, content)
          results << {destination: relative_destination, outcome: :wrote}
        else
          results << {destination: relative_destination, outcome: :skipped}
        end
      end

      # Generates the v0 placeholder, component index, and latest/index redirect for one component.
      def generate_component_files(gh_pages_dir, template_dir, comp_settings, results, &confirm)
        version = current_component_version(gh_pages_dir, comp_settings)
        redirect_url = "https://#{component_base_path(comp_settings)}/v#{version}"
        subdir = comp_settings.gh_pages_directory

        write_file(gh_pages_dir, simplifying_join(subdir, "v0/index.html"),
                   render_template(template_dir, "empty.html.erb", {name: comp_settings.name}),
                   results, &confirm)
        write_file(gh_pages_dir, simplifying_join(subdir, "index.html"),
                   render_template(template_dir, "redirect.html.erb", {redirect_url: redirect_url}),
                   results, &confirm)
        write_file(gh_pages_dir, simplifying_join(subdir, "latest/index.html"),
                   render_template(template_dir, "redirect.html.erb", {redirect_url: redirect_url}),
                   results, &confirm)
      end

      # Generates .nojekyll, .gitignore, and (when no root component exists) the root index redirect.
      def generate_toplevel_files(gh_pages_dir, template_dir, results, &confirm)
        write_file(gh_pages_dir, ".nojekyll", "", results, &confirm)
        write_file(gh_pages_dir, ".gitignore", render_template(template_dir, "gitignore.erb", {}), results, &confirm)

        return if @enabled_component_settings.any? { |s| s.gh_pages_directory == "." }

        write_file(gh_pages_dir, "index.html",
                   render_template(template_dir, "redirect.html.erb", {redirect_url: @default_redirect_url}),
                   results, &confirm)
      end

      # Generates 404.html with version variables and redirect-replacement regexps for all components.
      def generate_html404(gh_pages_dir, template_dir, results, &confirm)
        version_vars = {}
        replacement_info = @enabled_component_settings.map do |comp_settings|
          version_vars[comp_settings.gh_pages_version_var] =
            current_component_version(gh_pages_dir, comp_settings)
          base_path = component_base_path(comp_settings)
          regexp_source = "//#{::Regexp.escape(base_path)}/latest(/|$)"
          CompInfo.new(base_path, regexp_source, comp_settings.gh_pages_version_var)
        end
        template_params = {
          default_redirect_url: @default_redirect_url,
          version_vars: version_vars,
          replacement_info: replacement_info,
        }
        write_file(gh_pages_dir, "404.html", render_template(template_dir, "404.html.erb", template_params),
                   results, &confirm)
      end
    end
  end
end
