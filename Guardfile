require 'corvid/builtin/guard'

project_name  = Regexp.quote(determine_project_name)
rspec_options = read_rspec_options(File.dirname __FILE__)

ignore VIM_SWAP_FILES

########################################################################################################################
# test/spec

group :spec do
  guard 'rspec', binstubs: true, spec_paths: ['test/spec'], cli: rspec_options, all_on_start: false, all_after_pass: false, keep_failed: false do
    #watch(%r{^(.+)$}) { |m| puts "------------------------------------------> #{m[1]} modified" }

    # Lib
    watch(%r'^lib/(.+)\.rb$')                 {|m| "test/spec/#{m[1]}_spec.rb"}
    watch(%r'^lib/#{project_name}/(.+)\.rb$') {|m| "test/spec/#{m[1]}_spec.rb"}

    # Each spec
    watch(%r'^test/spec/.+_spec\.rb$')

    # Fixtures
    watch(%r'^test/fixtures/migration/.+$')  {"test/spec/res_patch_manager_spec.rb"}
    upgrading= %w[test/spec/generators/init_spec.rb test/spec/generator/update_spec.rb]
    watch(%r'^test/fixtures/upgrading/.+$')   {upgrading}
    watch('test/helpers/fixture-upgrading.rb'){upgrading}
    watch(%r'^test/fixtures/auto_update.*?/[^/]+\.patch$') {"test/spec/generator/update_spec.rb"}

    # Exceptional cases
    watch(%r'^lib/corvid/builtin/test/resource_patch_tests\.rb') {%w[
        test/spec/generator/update_spec.rb
        test/spec/builtin/builtin_plugin_spec.rb
      ]} if bulk?
  end
end

########################################################################################################################
# test/integration

group :int do
  guard 'rspec', binstubs: true, spec_paths: ['test/integration'], cli: rspec_options, all_on_start: false, all_after_pass: false, keep_failed: false do

    # Lib
    watch(%r'^lib/(.+)\.rb$')                 {|m| "test/integration/#{m[1]}_test.rb"}
    watch(%r'^lib/#{project_name}/(.+)\.rb$') {|m| "test/integration/#{m[1]}_test.rb"}

    # Each spec
    watch(%r'^test/integration/.+_spec\.rb$')
  end
end unless fast_only?
