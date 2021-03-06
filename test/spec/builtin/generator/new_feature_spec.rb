# encoding: utf-8
require_relative '../../../bootstrap/spec'
require 'corvid/builtin/generator/new_feature'
require 'corvid/builtin/generator/new_plugin'
require 'corvid/extension'

describe Corvid::Builtin::Generator::NewFeature do
  describe 'new:feature' do
    context "with no client res-patches" do
      run_all_in_empty_dir("my_stuff") {
        copy_dynamic_fixture :bare
        add_feature! 'corvid:plugin'
        create_gemspec_file 'my_stuff'
        run_generator Corvid::Builtin::Generator::NewPlugin, 'plugin big'
        run_generator described_class, 'feature small'
      }

      it("should declare the feature as being since_ver 1"){
        'lib/my_stuff/small_feature.rb'.should be_file_with_contents /since_ver 1/
      }
    end

    context "with 2 mock client res-patches" do
      run_all_in_empty_dir("my_stuff") {
        copy_dynamic_fixture :bare
        add_feature! 'corvid:plugin'
        create_gemspec_file 'my_stuff'
        Dir.mkdir 'resources'
        File.write 'resources/00001.patch', ''
        File.write 'resources/00002.patch', ''
        run_generator Corvid::Builtin::Generator::NewPlugin, 'plugin big'
        run_generator described_class, 'feature small'
      }

      it("should create a feature"){
        'lib/my_stuff/small_feature.rb'.should be_file_with_contents(%r|module MyStuff|)
          .and(%r|class SmallFeature < Corvid::Feature|)
          .and(%r|require 'corvid/feature'|)
      }

      it("should declare the feature as being since_ver 3"){
        'lib/my_stuff/small_feature.rb'.should be_file_with_contents /since_ver 3/
      }

      Corvid::Extension.callbacks.each do |ext_point|
        class_eval <<-EOB
          it("should include extension point in feature: #{ext_point}"){
            'lib/my_stuff/small_feature.rb'.should be_file_with_contents /#{ext_point}/
          }
        EOB
      end

      it("should create a feature installer"){
        'resources/latest/corvid-features/small.rb'.should be_file_with_contents /^install\s*{/
      }

      (Corvid::Generator::Base::FEATURE_INSTALLER_VALUES_DEFS +
       Corvid::Generator::Base::FEATURE_INSTALLER_CODE_DEFS).each do |name|
        class_eval <<-EOB
          it("should include in feature installer: #{name}"){
            'resources/latest/corvid-features/small.rb'.should be_file_with_contents /#{name}/
          }
        EOB
      end

      it("should add the feature to the plugin manifest"){
        'lib/my_stuff/big_plugin.rb'.should be_file_with_contents \
          /feature_manifest\s*\(\{\n\s+'small'\s*=>\s*\['my_stuff\/small_feature'\s*,\s*'::MyStuff::SmallFeature'\],\n/
      }

    end
  end
end
