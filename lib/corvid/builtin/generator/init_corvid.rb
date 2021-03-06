require_relative 'base'
require 'corvid/builtin/generator/init_test_unit'
require 'corvid/builtin/generator/init_test_spec'

class Corvid::Builtin::Generator::InitCorvid < ::Corvid::Generator::Base
  TEST_UNIT_QUESTION= 'Add support for unit tests?'
  TEST_SPEC_QUESTION= 'Add support for specifications?'

  desc 'init', 'Creates a new Corvid project in the current directory.'
  method_option :'test-unit', type: :boolean, desc: TEST_UNIT_QUESTION.sub(/\?$/,'.')
  method_option :'test-spec', type: :boolean, desc: TEST_SPEC_QUESTION.sub(/\?$/,'.')
  declare_option_to_run_bundle_at_exit(self)
  def init
    with_latest_resources(builtin_plugin) {|ver|
      with_action_context feature_installer!('corvid'), &:install
      write_client_versions builtin_plugin.name => ver
      add_plugin            builtin_plugin
      add_feature           feature_id_for(builtin_plugin.name,'corvid')

      invoke 'init:test:unit', [], RUN_BUNDLE => false if read_boolean_option_or_prompt_user :'test-unit', TEST_UNIT_QUESTION
      invoke 'init:test:spec', [], RUN_BUNDLE => false if read_boolean_option_or_prompt_user :'test-spec', TEST_SPEC_QUESTION

      run_bundle_at_exit()
    }
  end
end
