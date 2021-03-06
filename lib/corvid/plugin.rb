require 'golly-utils/attr_declarative'
require 'golly-utils/callbacks'

module Corvid
  # A Corvid plugin is an entity outside of Corvid proper, that provides:
  #
  # * {Extension}s.
  # * {Feature}s.
  # * New functionality.
  # * Tasks. (See {Generator::Base} and the `corvid_tasks` callback in {Extension}.)
  class Plugin
    include GollyUtils::Callbacks

    # Plugins can be extensions but are not by default.
    # include Extension

    # @!group Attributes

    # @!attribute [rw] name
    #   The name of the plugin. Must conform to format enforced by {Corvid::NamingPolicy#validate_plugin_name!}.
    #   @return [String] The plugin name.
    attr_declarative :name, required: true

    # @!attribute [rw] require_path
    #   The path for Ruby to `require` in order to load this plugin.
    #   @return [String] The path to require, usually relative to your `lib` dir.
    attr_declarative :require_path, required: true

    # @!attribute [rw] resources_path
    #   The path to the directory containing the plugin's resources.
    #   @return [String] An absolute path.
    attr_declarative :resources_path, required: true

    # @!attribute [rw] requirements
    #   Requirements that must be satisfied before the plugin can be installed.
    #   @return [nil, String, Hash<String,Fixnum|Range|Array<Fixnum>>, Array] Requirements that can be provided to
    #     {RequirementValidator}.
    #   @see RequirementValidator#add
    attr_declarative :requirements

    # @!attribute [rw] feature_manifest
    #   A manifest of all features provided by the plugin.
    #   @return [Hash<String,Array<String>>] A hash with keys being feature names, and the values being a 2-element
    #     array of the feature's require-path, and class name, respectively.
    attr_declarative feature_manifest: {}

    # @!attribute [rw] auto_install_features
    #   A list of features to install automatically when the plugin itself is installed.
    #   @return [Array<String>] An array of feature names. Do not include the plugin prefix.
    attr_declarative auto_install_features: []

    # @!group Callbacks

    # @!parse
    #   # Callback that is run after the plugin is installed.
    #   #
    #   # Generator actions are available and can be invoked as if the callback function were a generator method.
    #   #
    #   # @yield Perform additional actions after installation.
    #   # @return [void]
    #   def after_installed; end
    define_callback :after_installed

  end
end
