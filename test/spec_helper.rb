# encoding: utf-8

STDIN.close

require_relative '../lib/corvid/environment'
require 'golly-utils/testing/rspec/files'
require 'golly-utils/testing/rspec/arrays'
require 'tmpdir'
require 'fileutils'
require 'yaml'
require 'corvid/builtin/manifest'

RUN_BUNDLE= 'run_bundle'
BOOTSTRAP_ALL= 'test/bootstrap/all.rb'
BOOTSTRAP_UNIT= 'test/bootstrap/unit.rb'
BOOTSTRAP_SPEC= 'test/bootstrap/spec.rb'
BUILTIN_FEATURES= Corvid::Builtin::Manifest.new.feature_manifest.keys.map(&:freeze).freeze

# Add test/ to lib path
$:<< "#{CORVID_ROOT}/test"

require 'helpers/gemfile_patching'
module Fixtures
  FIXTURE_ROOT= "#{CORVID_ROOT}/test/fixtures"
end

module TestHelpers

  def add_feature!(feature_name)
    f= YAML.load_file('.corvid/features.yml') + [feature_name]
    File.write '.corvid/features.yml', f.to_yaml
  end

  def assert_corvid_features(*expected)
    f= YAML.load_file('.corvid/features.yml')
    f.should be_kind_of(Array)
    f.should == expected.flatten
  end

  def invoke_sh(cmd,env=nil)
    cmd= cmd.map(&:inspect).join ' ' if cmd.kind_of?(Array)
    env ||= {}
    env['BUNDLE_GEMFILE'] ||= nil
    env['RUBYOPT'] ||= nil
    system env, cmd
    $?.success?
  end
  def invoke_sh!(args,env=nil)
    invoke_sh(args,env).should eq(true), 'Shell command failed.'
  end
  def invoke_corvid(args,env=nil)
    args= args.map(&:inspect).join ' ' if args.kind_of?(Array)
    cmd= %`"#{CORVID_ROOT}/bin/corvid" #{args}`
    invoke_sh cmd, env
  end
  def invoke_corvid!(args,env=nil)
    invoke_corvid(args,env).should eq(true), 'Corvid failed.'
  end
  def invoke_rake(args,env=nil)
    args= args.map(&:inspect).join ' ' if args.kind_of?(Array)
    cmd= "bundle exec rake #{args}"
    invoke_sh cmd, env
  end
  def invoke_rake!(args,env=nil)
    invoke_rake(args,env).should eq(true), 'Rake failed.'
  end

  # TODO remove files() and dirs() test helpers.
  def files(force=false)
    @files= nil if force
    @files ||= Dir['**/*'].select{|f| ! File.directory? f}.sort
  end
  def dirs(force=false)
    @dirs= nil if force
    @dirs ||= Dir['**/*'].select{|f| File.directory? f}.sort
  end

  def copy_fixture(fixture_name, target_dir='.')
    FileUtils.cp_r "#{Fixtures::FIXTURE_ROOT}/#{fixture_name}/.", target_dir
  end

  def inside_fixture(fixture_name)
    Dir.mktmpdir {|dir|dir
      Dir.chdir dir do
        copy_fixture fixture_name
        patch_corvid_gemfile
        yield
      end
    }
  end

  def assert_files(src_dir, exceptions={})
    filelist= Dir.chdir(src_dir){
      Dir.glob('**/*',File::FNM_DOTMATCH).select{|f| File.file? f }
    } + exceptions.keys
    filelist.uniq!
    get_files.should == filelist.sort
    filelist.each do |f|
      expected= exceptions[f] || File.read("#{src_dir}/#{f}")
      File.read(f).should == expected
    end
  end

  def generator_config(quiet)
    # Quiet stdout - how the hell else are you supposed to do this???
    config= {}
    config[:shell] ||= Thor::Base.shell.new
    if quiet
      config[:shell].instance_eval 'def say(*) end'
      config[:shell].instance_eval 'def quiet?; true; end'
      #config[:shell].instance_variable_set :@mute, true
    end
    config
  end

  def quiet_generator(generator_class)
    config= generator_config(true)
    g= generator_class.new([], [], config)
    decorate_generator g
  end

  def decorate_generator(g)
    # Use a test res-patch manager if available
    g.rpm= @rpm if @rpm
    g
  end

  def run_generator(generator_class, args, no_bundle=true, quiet=true)
    args= args.split(/\s+/) unless args.is_a?(Array)
    args<< "--no-#{RUN_BUNDLE}" if no_bundle

    config= generator_config(quiet)

    # Do horrible stupid Thor-internal crap to instantiate a generator
    task= generator_class.tasks[args.shift]
    args, opts = Thor::Options.split(args)
    config.merge!(:current_task => task, :task_options => task.options)
    g= generator_class.new(args, opts, config)

    decorate_generator g
    g.invoke_task task
  end
end

module IntegrationTestDecoration
  SEP1= "\e[0;40;34m#{'_'*120}\e[0m"
  SEP2= "\e[0;40;34m#{'-'*120}\e[0m"
  SEP3= "\e[0;40;34m#{'='*120}\e[0m"
  def self.included spec
    spec.class_eval <<-EOB
      before(:all){ puts ::#{self}::SEP1; $__GOLTEST_ITD=1 }
      before(:each){ $__GOLTEST_ITD ?  $__GOLTEST_ITD= nil : puts(::#{self}::SEP2) }
      after(:all){ puts ::#{self}::SEP3 }
    EOB
  end
end

RSpec.configure do |config|
  config.include TestHelpers
  config.include GemfilePatching
end
