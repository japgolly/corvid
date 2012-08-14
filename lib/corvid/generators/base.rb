require 'corvid/environment'
require 'corvid/constants'
require 'corvid/feature_registry'
require 'corvid/plugin_registry'
require 'corvid/naming_policy'
require 'corvid/res_patch_manager'
require 'corvid/generators/actions'

require 'active_support/core_ext/string/inflections'
require 'active_support/inflections'
require 'golly-utils/delegator'
require 'thor'
require 'yaml'

module Corvid

  # Everything within this module directly relates to Thor generators.
  #
  # @see https://github.com/wycats/thor Thor project.
  # @see http://rdoc.info/github/wycats/thor Thor documentation.
  module Generator

    # Abstract Thor generator that adds support for Corvid specific functionality.
    #
    # @abstract
    class Base < Thor
      include Thor::Actions
      include ActionExtentions
      include ::Corvid::NamingPolicy

      # Name of the option that users can use on the CLI to opt-out of Bundler being run at the end of certain tasks.
      RUN_BUNDLE= :'run_bundle'

      # Methods provided to feature installer that each take a block of code.
      FEATURE_INSTALLER_CODE_DEFS= %w[install update].map(&:freeze).freeze

      # Methods provided to feature installer that each take a single value.
      FEATURE_INSTALLER_VALUES_DEFS= %w[].map(&:freeze).freeze

      # @!visibility private
      def self.inherited(c)
        c.class_eval <<-EOB
          def self.source_root; $corvid_global_thor_source_root end
          namespace ::Thor::Util.namespace_from_thor_class(self).sub(/^corvid:generator:/,'')
        EOB
      end

      # This stops stupid Thor thinking the public methods below are tasks and issuing warnings
      # Not using no_tasks{} because it stops Yard seeing the methods.
      @no_tasks= true

      def rpm()
        @rpm ||= ::Corvid::ResPatchManager.new
      end
      # @!attribute [rw] rpm
      #   @return [ResPatchManager] The resource-patch manager that the generator will use.
      attr_writer :rpm

      @no_tasks= true # Shutup Thor, you idiot!

      # @!attribute [rw] feature_registry
      #   @return [FeatureRegistry]
      ::Corvid::FeatureRegistry.def_accessor(self)

      # @!attribute [rw] plugin_registry
      #   @return [PluginRegistry]
      ::Corvid::PluginRegistry.def_accessor(self)

      def builtin_plugin
        @@builtin_plugin ||= ::Corvid::Builtin::BuiltinPlugin.new
      end

      # @see Corvid::FeatureRegistry#read_client_features
      def read_client_features
        feature_registry.read_client_features
      end
      # @see Corvid::FeatureRegistry#read_client_features!
      def read_client_features!
        feature_registry.read_client_features!
      end

      # Reads and parses the contents of the client's {Constants::VERSIONS_FILE VERSIONS_FILE} if it exists.
      #
      # @return [nil,Hash<String,Fixnum>] The version numbers for each plugin or `nil` if the file wasn't found.
      def read_client_versions
        if File.exists?(Constants::VERSIONS_FILE)
          vers= YAML.load_file(Constants::VERSIONS_FILE)
          validate_versions! vers, "\nCheck your #{Constants::VERSIONS_FILE} file."
          vers
        else
          nil
        end
      end

      # Validates the (potential) contents of a client's {Constants::VERSIONS_FILE VERSIONS_FILE}.
      #
      # @param [Hash<String,Fixnum>] vers A hash of plugins to the version of corresponding resources installed.
      # @param [String] errmsg_suffix Optional text to append to error messages when validation fails.
      # @return [void]
      def validate_versions!(vers, errmsg_suffix=nil)
        s= errmsg_suffix ? errmsg_suffix.sub(/\a(?!=\s)/,' ') : ''
        raise "Invalid version settings, hash expected. Received: #{vers.inspect}.#{s}" unless vers.is_a? Hash
        vers.each do |p,v|
          raise "Invalid plugin name: #{p.inspect}." unless p.is_a? String
          raise "Invalid version for #{p}: #{v.inspect}. Number expected." unless v.is_a? Fixnum
        end
      end

      # Reads and parses the contents of the client's {Constants::VERSIONS_FILE VERSIONS_FILE} if it exists.
      #
      # @return [Hash<String,Fixnum>] The version numbers for each plugin.
      # @raise If file not found.
      # @see read_client_version
      def read_client_versions!
        vers= read_client_versions
        raise "File not found: #{Constants::VERSIONS_FILE}\nYou must install Corvid first. Try corvid init:project." if vers.nil?
        vers
      end

      protected

      # The resource directory that contains the appropriate version (as specified by {#with_resources}) of Corvid
      # resources.
      #
      # @return [String]
      # @raise If resources aren't available.
      # @see #with_latest_resources
      # @see #with_resources
      def res_dir
        $corvid_global_thor_source_root || raise("Resources not available. Call with_resources() first.")
      end

      # Makes available to generators the latest version of Corvid resources.
      #
      # @yieldparam [Fixnum] ver The version of the resources being used.
      # @return The return result of `block`.
      # @see #with_resources
      def with_latest_resources(&block)
        with_resources :latest, &block
      end

      # Works with {ResPatchManager} to provide generators with an specified version of Corvid resources.
      #
      # @note Only one version of resources can be made available at one time. Nested calls to this method requesting
      #   the same version (reentrancy) will be allowed, but a nested call for a differing version will fail.
      # @raise If resources of a different version are already available.
      #
      # @return The return result of `block`.
      # @overload with_resources(dir, &block)
      #   @param [String] dir The directory where the resources can be found.
      #   @yieldparam [void]
      # @overload with_resources(ver, &block)
      #   @param [Fixnum, :latest] ver The version of resources to use.
      #   @yieldparam [Fixnum] ver The version of the resources being used.
      def with_resources(ver, &block)

        # Check args
        raise "Block required." unless block
        ver= rpm.latest_version if ver == :latest
        raise "Invalid version: #{ver.inspect}" unless ver.is_a?(String) or ver.is_a?(Fixnum)
        raise "Directory doesn't exist: #{ver}" if ver.is_a?(String) and !Dir.exists?(ver)
        if @@with_resource_version and ver != @@with_resource_version
          raise "Nested calls with different versions not supported. This should never occur; BUG!\nInitial: #{@@with_resource_version.inspect}\nProposed: #{ver.inspect}"
        end

        @@with_resource_depth += 1
        begin

          if @@with_resource_depth > 1
            # Run locally if already pointing at desired resources
            return block.call(ver)
          else
            # Prepare initial state
            setup_proc= lambda {|dir|
              @@with_resource_version= ver
              @source_paths= [dir]
              $corvid_global_thor_source_root= dir
            }

            if ver.is_a?(String)
              # Use existing resource dir
              setup_proc.call ver
              return block.call()
            else
              # Deploy resources via RPM
              rpm.with_resources(ver) {|dir|
                setup_proc.call dir
                return block.call(ver)
              }
            end
          end

        ensure
          # Clean up when done
          if (@@with_resource_depth -= 1) == 0
            $corvid_global_thor_source_root= nil
            @@with_resource_version= nil
            @source_paths= nil
          end
        end
      end

      # Declares a Thor option that allows users to opt-out of Bundler being run at the end of certain tasks.
      #
      # @param [Base] t The calling generator.
      # @return [void]
      # @see RUN_BUNDLE
      # @see #run_bundle
      def self.declare_option_to_run_bundle(t)
        t.method_option RUN_BUNDLE, type: :boolean, default: true, optional: true
      end

      # Unless the option to disable this specifies otherwise, asynchronously sets up `bundle install` to run in the
      # client's project after all generators have completed.
      #
      # @return [void]
      def run_bundle
        if options[RUN_BUNDLE] and !$corvid_bundle_install_at_exit_installed
          $corvid_bundle_install_at_exit_installed= true
          at_exit {
            ENV['BUNDLE_GEMFILE']= nil
            ENV['RUBYOPT']= nil
            run "bundle install"
          }
        end
      end

      # Adds feature ids to the client's {Constants::FEATURES_FILE FEATURES_FILE}.
      #
      # Only feature ids not already in the file will be added, and {Constants::FEATURES_FILE FEATURES_FILE} will only
      # be updated if there are new feature ids to add.
      #
      # @param [Array<String>] feature_ids
      # @return [Boolean] `true` if new features were added to the client's features, else `false`.
      def add_features(*feature_ids)
        validate_feature_ids! *feature_ids

        # Read currently installed features
        installed= read_client_features || []
        size_before= installed.size

        # Add features
        feature_ids.flatten.each do |feature|
          installed<< feature unless installed.include?(feature)
        end

        # Write back to disk
        if installed.size != size_before
          write_client_features installed
          true
        else
          false
        end
      end
      alias :add_feature :add_features

      # TODO
      #
      # @param [Plugin] plugin The plugin instance.
      # @return [true]
      def add_plugin(plugin)
        name= plugin.name
        validate_plugin_name! name
        pdata= plugin_registry.read_client_plugin_details
        pdata ||= {}
        pdata[name]= {path: plugin.require_path, class: plugin.class.to_s}
        File.write Constants::PLUGINS_FILE, pdata.to_yaml
        true
      end

      def add_version(plugin_name, version)
        vers= read_client_versions || {}
        vers[plugin_name]= version
        write_client_versions vers
      end

      # Installs a feature into an existing Corvid project.
      #
      # If the feature is already installed then this tells the user thus and stops.
      #
      # @param [String,Plugin] plugin_or_name The plugin, or name of, that the feature belongs to.
      # @param [String] feature_name The feature name to install.
      # @option options [Boolean] :run_bundle (false) If enabled, then {#run_bundle} will be called after the feature is
      #   added.
      # @option options [Boolean] :say_if_installed (true) If enabled and feature is already installed, then display a message
      #   indicating so to the user.
      # @return [void]
      # @raise If failed to read client's installed features and resource versions.
      # @raise If the feature isn't available at the current version of resources (i.e. update required).
      def install_feature(plugin_or_name, feature_name, options={})
        options= DEFAULT_OPTIONS_FOR_INSTALL_FEATURE.merge options
        plugin_name= plugin_or_name.is_a?(Plugin) ? plugin_or_name.name : plugin_or_name
        feature_id= feature_id_for(plugin_name, feature_name)

        # Read client details
        vers= read_client_versions!
        feature_ids= read_client_features!

        # Corvid installation confirmed - now check if feature already installed
        if feature_ids.include? feature_id
          say "Feature '#{feature_id}' already installed." if options[:say_if_installed]
          return
        end

        # Ensure resources up-to-date
        ver= vers[plugin_name]
        f= feature_registry.instance_for(feature_id)
        if f and f.since_ver > ver
          raise "The #{feature_id} feature requires at least v#{f.since_ver} of #{plugin_name} resources, but you are currently on v#{ver}.\nPlease perform an update first and then try again."
        end

        # Install feature
        # TODO doesn't use plugin resources
        # TODO remember that plugins can call install_feature 'corvid:test_unit' & install feature of a diff plugin
        with_resources(ver) {|ver|
          feature_installer!(feature_name).install
          add_feature feature_id
          yield ver if block_given?
          run_bundle() if options[:run_bundle]
        }
      end

      # @!visibility private
      DEFAULT_OPTIONS_FOR_INSTALL_FEATURE= {
        run_bundle: false,
        say_if_installed: true,
      }.freeze

      # @return [String] The installer filename.
      def feature_installer_file(dir = res_dir(), feature_name)
        validate_feature_name! feature_name
        "#{dir}/corvid-features/#{feature_name}.rb"
      end
      # @return [String] The installer filename.
      # @raise If the installer file doesn't exist.
      def feature_installer_file!(dir = res_dir(), feature_name)
        filename= feature_installer_file(dir, feature_name)
        raise "File not found: #{filename}" unless File.exists?(filename)
        filename
      end

      # @return [nil,String] The installer file contents or `nil` if the file doesn't exist.
      def feature_installer_code(dir = res_dir(), feature_name)
        file= feature_installer_file(dir, feature_name)
        return nil unless File.exist?(file)
        code= File.read(file) # TODO encoding
        allow_declarative_feature_installer_config(code, feature_name)
      end
      # @return [String] The installer file contents.
      # @raise If the installer file doesn't exist.
      def feature_installer_code!(dir = res_dir(), feature_name)
        code= feature_installer_code(dir, feature_name)
        code or (
          feature_installer_file!(dir, feature_name) # This will raise its own error if file not found
          raise "Unable to read feature installer code for '#{feature_name}'."
        )
      end

      # Wraps the code of a feature installer so that values/code blocks are provided as arguments to pre-defined
      # keywords.
      #
      # Eg. the following code:
      #     since_ver 2
      #
      #     install {
      #       do_stuff
      #     }
      # will be translated into:
      #     def since_ver
      #       2
      #     end
      #
      #     def install
      #       do_stuff
      #     end
      #
      # Why? Because this fails fast:
      #     instal {  # <-- typo, this causes an error on parsing now
      #       do_stuff
      #     }
      #
      # @param [String] code The feature installer code.
      # @return [String] The feature installer code wrapped in magic goodness!
      def allow_declarative_feature_installer_config(code, feature)
        iv= '@__corvid_fi_'
        new_code= []
        new_code.concat FEATURE_INSTALLER_VALUES_DEFS.map{|m| "def #{m}(v); #{iv}#{m}= v; end"}
        new_code.concat FEATURE_INSTALLER_CODE_DEFS.map{|m| %|
                          def #{m}(&b)
                            raise "Block not provided for #{m} in #{feature} feature-installer." if b.nil?
                            #{iv}#{m}= b
                          end
                        |}
        new_code<< code
        new_code.concat FEATURE_INSTALLER_VALUES_DEFS.map{|m| %|
                          if instance_variable_defined? :#{iv}#{m}
                            def #{m}; #{iv}#{m} end
                          else
                            undef :#{m}
                          end
                        |}
        new_code.concat FEATURE_INSTALLER_CODE_DEFS.map{|m| %|
                          if instance_variable_defined? :#{iv}#{m}
                            def #{m}(*args) #{iv}#{m}.call(*args) end
                          else
                            undef :#{m}
                          end
                        |}
        code= new_code.join "\n"
        code
      end

      # @return [nil, GollyUtils::Delegator<Base>] An instance of the feature installer, unless any forseeable exception
      #   (such as the installer file not existing) occurs.
      def feature_installer(dir = res_dir(), feature_name)
        code= feature_installer_code(dir, feature_name)
        code && dynamic_installer(code, feature_name)
      end
      # @return [GollyUtils::Delegator<Base>] An instance of the feature installer.
      # @raise If the installer file doesn't exist or any other problem occurs.
      def feature_installer!(dir = res_dir(), feature_name)
        installer= feature_installer(dir, feature_name)
        installer or (
          feature_installer_file!(dir, feature_name) # This will raise its own error if file not found
          raise "Unable to create feature installer for '#{feature_name}'."
        )
      end

      # Turns given code into an object that delegates all undefined methods to this generator.
      #
      # @param [String] code The Ruby code to evaluate.
      # @param [String] feature The name of the feature that the code belongs to (for generating clear error-messages).
      # @param [nil,Fixnum] ver The version of the resources that the code belongs to (for generating clear
      #   error-messages).
      # @return [GollyUtils::Delegator<Base>] A delegator with the provided code on top.
      def dynamic_installer(code, feature, ver=nil)
        d= GollyUtils::Delegator.new self, allow_protected: true
        add_dynamic_code! d, code, feature, ver
      end

      # Mixes given code into an existing object, and wraps each new public method with decorated error-messages when
      # things go wrong.
      #
      # @param [Object] obj The object to embelish with given code.
      # @param [String] code The Ruby code to evaluate.
      # @param [String] feature The name of the feature that the code belongs to (for generating clear error-messages).
      # @param [nil,Fixnum] ver The version of the resources that the code belongs to.
      # @return the same object that was provided in `obj`.
      def add_dynamic_code!(obj, code, feature, ver=nil)
        orig_methods= obj.public_methods
        obj.instance_eval code
        new_methods= obj.public_methods - orig_methods

        errmsg_frag= "#{feature} installer"
        ver ||= @@with_resource_version
        errmsg_frag.prepend "v#{ver} of " if ver

        new_methods.each {|m|
          obj.instance_eval <<-EOB
            alias :__raw_#{m} :#{m}
            def #{m}(*args)
              __raw_#{m} *args
            rescue => e
              raise e.class, "Error executing #{m}() in #{errmsg_frag}.\\n#\{e.to_s}", e.backtrace
            end
          EOB
        }

        obj
      end

      # Creates or replaces the client's {Constants::VERSIONS_FILE VERSIONS_FILE}.
      #
      # @param [Hash<String,Fixnum>] vers A hash of plugins to the version of corresponding resources installed.
      # @return [self]
      def write_client_versions(vers)
        # TODO doesn't call rpm.validate_version! >>> rpm[plugin].validate_version! ver, 1
        validate_versions! vers
        create_file Constants::VERSIONS_FILE, vers.to_yaml, force: true
        self
      end

      # Creates or replaces the client's {Constants::FEATURES_FILE FEATURES_FILE}.
      #
      # @param [Array<String>] feature_ids The feature_ids to write to the file
      # @return [self]
      def write_client_features(feature_ids)
        raise "Invalid features. Array expected. Got: #{feature_ids.inspect}" unless feature_ids.is_a?(Array)
        validate_feature_ids! *feature_ids
        create_file Constants::FEATURES_FILE, feature_ids.to_yaml, force: true
        self
      end

      private
      @@with_resource_depth= 0
      @@with_resource_version= nil

      # Re-enable Thor's support for assuming all public methods are tasks
      no_tasks {}
    end
  end
end
