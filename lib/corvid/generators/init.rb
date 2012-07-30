require 'corvid/generators/base'
require 'yaml'

class Corvid::Generator::Init < Corvid::Generator::Base

  desc 'project', 'Creates a new Corvid project in the current directory.'
  method_option :'test-unit', type: :boolean
  method_option :'test-spec', type: :boolean
  run_bundle_option(self)
  def project
    with_latest_resources {|ver|
      feature_installer!('corvid').install
      add_feature 'corvid'
      write_version ver

      invoke 'init:test:unit', [], RUN_BUNDLE => false if boolean_specified_or_ask :'test-unit', 'Add support for unit tests?'
      invoke 'init:test:spec', [], RUN_BUNDLE => false if boolean_specified_or_ask :'test-spec', 'Add support for specs?'

      run_bundle()
    }
  end

  class Test < Corvid::Generator::Base

    desc 'unit', 'Adds support for unit tests.'
    run_bundle_option(self)
    def unit
      install_feature 'test_unit'
    end

    desc 'spec', 'Adds support for specifications.'
    run_bundle_option(self)
    def spec
      install_feature 'test_spec'
    end

    protected

    def install_feature(name, run_bundle=true)

      # Read installation details
      ver= read_deployed_corvid_version!
      features= get_installed_features!

      # Corvid installation confirmed - now check if feature already installed
      if features.include? name
        say "Feature '#{name}' already installed."
      else
        # Install feature
        with_resources(ver) {|ver|
          feature_installer!(name).install
          add_feature name
          yield ver if block_given?
          run_bundle() if run_bundle
        }
      end
    end

  end # class Init::Test
end # class Init
