require 'corvid/plugin'

module Corvid
  module Builtin
    class BuiltinPlugin < Corvid::Plugin

      require_path 'corvid/builtin/builtin_plugin'

      feature_manifest({
          'corvid'    => ['corvid/builtin/corvid_feature'   ,'Corvid::Builtin::CorvidFeature'],
          'test_unit' => ['corvid/builtin/test_unit_feature','Corvid::Builtin::TestUnitFeature'],
          'test_spec' => ['corvid/builtin/test_spec_feature','Corvid::Builtin::TestSpecFeature'],
          'plugin'    => ['corvid/builtin/plugin_feature'   ,'Corvid::Builtin::PluginFeature'],
      })

    end
  end
end