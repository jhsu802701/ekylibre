# Inspired from Redmine and Discourse
# http://www.redmine.org/projects/redmine/repository/entry/trunk/lib/redmine/plugin.rb
module Ekylibre

  class PluginRequirementError < StandardError
  end

  class Plugin

    @registered_plugins = {}

    cattr_accessor :directory, :mirrored_assets_directory
    self.directory = Ekylibre.root.join("plugins")
    # Where the plugins assets are gathered for asset pipeline
    self.mirrored_assets_directory = Ekylibre.root.join("tmp", "plugins", "assets")

    # Returns a type (stylesheets, fonts...) directory for all plugins
    def self.type_assets_directory(type)
      mirrored_assets_directory.join(type)
    end


    class << self
      attr_accessor :registered_plugins

      def field_accessor(*names)
        class_eval do
          names.each do |name|
            define_method(name) do |*args|
              args.empty? ? instance_variable_get("@#{name}") : instance_variable_set("@#{name}", *args)
            end
          end
        end
      end

      def import_stylesheets(theme)
        stylesheets = []
        @registered_plugins.each do |name, plugin|
          if plugin.themes_assets[theme] and plugin.themes_assets[theme][:stylesheets]
            plugin.themes_assets[theme][:stylesheets].each do |stylesheet|
              stylesheets << "@import \"plugins/#{plugin.name}/#{stylesheet}\";"
            end
          end
        end
        return "" if stylesheets.empty?
        return stylesheets.join("\n")
      end


      # Load all plugins
      def load
        Dir.glob(File.join(self.directory, '*')).sort.each do |directory|
          if File.directory?(directory)
            lib = File.join(directory, "lib")
            if File.directory?(lib)
              $:.unshift lib
              ActiveSupport::Dependencies.autoload_paths += [lib]
            end
            initializer = File.join(directory, "Plugfile")
            if File.file?(initializer)
              plugin = new(initializer)
              registered_plugins[plugin.name] = plugin
              Rails.logger.info "Load #{plugin.name} plugin"
            else
              Rails.logger.warn "No Plugfile found in #{directory}"
            end
          end
        end
      end

      def each(&block)
        registered_plugins.each do |key, plugin|
          yield plugin
        end
      end

    end

    attr_reader :root, :themes_assets, :routes
    field_accessor :name, :summary, :description, :url, :author, :author_url, :version


    # Links plugin into app
    def initialize(plugfile_path)
      @root = Pathname.new(plugfile_path).dirname

      instance_eval(File.read(plugfile_path), plugfile_path, 1)

      if @name
        @name = @name.to_sym
      else
        raise "Need a name for plugin #{plugfile_path}"
      end

      @themes_assets = {}.with_indifferent_access

      # Adds locales
      Rails.application.config.i18n.load_path += Dir.glob(@root.join('config', 'locales', '**', '*.{rb,yml}'))

      # Adds view path
      @view_path = @root.join('app', 'views')
      if @view_path.directory?
        ActionController::Base.prepend_view_path(@view_path)
        ActionMailer::Base.prepend_view_path(@view_path)
      end

      # Adds the app/{controllers,helpers,models} directories of the plugin to the autoload path
      Dir.glob File.expand_path(@root.join('app', '{controllers,helpers,models,jobs,mailers,inputs}')) do |dir|
        ActiveSupport::Dependencies.autoload_paths += [dir]
      end

      # Adds assets
      if assets_directory.exist?
        # Emulate "subdir by plugin" config
        # plugins/<plugin>/app/assets/*/ => tmp/plugins/assets/*/plugins/<plugin>/
        Dir.chdir(assets_directory) do
          Dir.glob("*") do |type|
            type_dir = self.class.type_assets_directory(type)
            plugin_type_dir = type_dir.join("plugins", @name) # mirrored_assets_directory(type)
            FileUtils.rm_rf plugin_type_dir
            FileUtils.mkdir_p(plugin_type_dir.dirname) unless plugin_type_dir.dirname.exist?
            FileUtils.ln_sf(assets_directory.join(type).relative_path_from(plugin_type_dir.dirname), plugin_type_dir)
            unless Rails.application.config.assets.paths.include?(type_dir.to_s)
              Rails.application.config.assets.paths << type_dir.to_s
            end
          end
        end
      end
    end

    def app_version
      Ekylibre.version
    end


    # def gem
    # end

    # def plugin
    # end

    # Require app version, used for compatibility
    # app '1.0.0'
    # app '~> 1.0.0'
    # app '> 1.0.0'
    # app '>= 1.0.0', '< 2.0'
    def app(*constraints)
      options = constraints.extract_options!

      constraints.each do |constraint|
        unless constraint =~ /\A((~>|>=|>|<|<=)\s+)?\d.\d(\.[a-z0-9]+)*\z/
          raise PluginRequirementError, "Invalid version constraint expression: #{constraint}"
        end
      end

      unless Gem::Dependency.new('ekylibre-erp', *constraints).match?('ekylibre-erp', Ekylibre.version)
        raise PluginRequirementError, "Plugin (#{@name}) is incompatible with current version of app"
      end
      return true
    end



    # Adds a snippet in app (for side or help places)
    def add_snippet(name, options = {})
      Ekylibre::Snippet.add("#{@name}-#{name}", snippets_directory.join(name), options)
    end


    # Adds a snippet in app (for side or help places)
    def add_stylesheet(name)
      Rails.application.config.assets.precompile << "plugins/#{@name}/#{name}"
    end

    # Adds a stylesheet inside a given theme
    def add_theme_stylesheet(theme, file)
      add_theme_asset(theme, file, :stylesheets)
    end


    def add_routes(&block)
      @routes = block
    end

    def add_menus(&block)
      Ekylibre::Parts.exec_dsl(&block)
    end


    # TODO Add other callback for plugin integration
    # def add_cell
    # end

    # def add_theme(name)
    # end

    private

    def snippets_directory
      @view_path.join("snippets")
    end

    def assets_directory
      @root.join("app", "assets")
    end

    def themes_directory
      @root.join("app", "themes")
    end

    def add_theme_asset(theme, file, type)
      @themes_assets[theme] ||= {}
      @themes_assets[theme][type] ||= []
      @themes_assets[theme][type] << file
    end

  end
end
