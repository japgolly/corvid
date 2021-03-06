# encoding: utf-8
require_relative '../../bootstrap/spec'
require 'corvid/builtin/test/resource_patch_tests'

describe BUILTIN_PLUGIN do
  include Corvid::Builtin::ResourcePatchTests

  include_resource_patch_tests {|dir|
    "#{dir}/1/Rakefile".should exist_as_file
  }

  include_feature_update_tests
end
