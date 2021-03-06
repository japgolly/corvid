# encoding: utf-8
require_relative '../bootstrap/spec'
require 'corvid/res_patch_manager'

describe Corvid::ResPatchManager do
  ResPatchManager= Corvid::ResPatchManager
  run_each_in_empty_dir_unless_in_one_already

  def migration_dir(ver=nil)
    d= "#{Fixtures::FIXTURE_ROOT}/migration"
    d+= "/#{ver}" if ver
    d
  end

  describe '#normalise_timestamp_in_patch_header_line!' do
    def process(str)
      described_class.new.send :normalise_timestamp_in_patch_header_line!, str
      nil
    end

    it("removes millisecond precision on --- lines"){
      process x= "--- .corvid/Gemfile\t2012-09-06 07:57:58.005077313 +1000"
      x.should == "--- .corvid/Gemfile\t2012-09-06 07:57:58.000000000 +1000"
    }

    it("removes millisecond precision on +++ lines"){
      process x= "+++ test/unit/%src%_test.rb.tt\t2012-09-06 07:57:58.255746233 +1000"
      x.should == "+++ test/unit/%src%_test.rb.tt\t2012-09-06 07:57:58.000000000 +1000"
    }

    it("uses a fixed date for /dev/null on --- lines"){
      process x= "--- /dev/null\t2012-09-03 14:23:42.983420216 +1000"
      x.should == "--- /dev/null\t1980-01-01 00:00:00.000000000 +1000"
    }

    it("uses a fixed date for /dev/null on +++ lines"){
      process x= "+++ /dev/null\t2012-09-03 14:23:42.983420216 +1000"
      x.should == "+++ /dev/null\t1980-01-01 00:00:00.000000000 +1000"
    }
  end

  #---------------------------------------------------------------------------------------------------------------------

  describe 'File migration (using reconstructed resources)', :slow do

    def populate_with(ver)
      FileUtils.cp_r "#{migration_dir ver}/.", '.'
    end

    def migrate(from_ver, to_ver)
      rpm= ResPatchManager.new '/whatever'
      rpm.send :with_reconstruction_dir, migration_dir do
        rpm.send :migrate_changes_between_versions, from_ver, to_ver, Dir.pwd
      end
    end

    context 'clean slate' do
      def test_clean_install(ver)
        migrate nil, ver
        assert_files migration_dir(ver)
      end
      it("should install 001"){ test_clean_install 1 }
      it("should install 002"){ test_clean_install 2 }
      it("should install 003"){ test_clean_install 3 }
    end

    context 'clean upgrading' do
      def test_clean_update(from,to)
        populate_with from
        migrate from, to
        assert_files migration_dir(to)
      end
      it("should update from 001 to 002"){ test_clean_update 1,2 }
      it("should update from 001 to 003"){ test_clean_update 1,3 }
      it("should update from 002 to 003"){ test_clean_update 2,3 }
    end

    context 'dirty upgrading' do
      def copy_file(ver, filename)
        FileUtils.mkdir_p File.dirname(filename)
        FileUtils.cp "#{migration_dir ver}/#{filename}", filename
      end
      it("should update from 000 to 002 - v2 file manually copied"){
        copy_file 2, "stuff/.hehe"
        migrate 0, 2
        assert_files migration_dir(2)
      }
      it("should update from 000 to 002 - v1 file manually copied"){
        copy_file 1, "stuff/.hehe"
        migrate 0, 2
        assert_files migration_dir(2)
      }
      it("should update from 001 to 002 - v1 file edited"){
        populate_with 1
        File.write 'stuff/.hehe', "hehe\n\nawesome"
        migrate 1, 2
        assert_files migration_dir(2), 'stuff/.hehe' => "hehe2\n\nawesome"
      }
      it("should update from 001 to 003 - v2 file manually copied"){
        populate_with 1
        copy_file 2, "stuff/.hehe"
        migrate 1, 3
        assert_files migration_dir(3)
      }
      it("should update from 002 to 003 - file deleted in v3 edited"){
        populate_with 2
        File.write 'v2.txt', "Before\nv2 bro\nAfter"
        migrate 2, 3
        File.delete "v2.txt.orig" if File.exists?('v2.txt.orig')
        assert_files migration_dir(3), 'v2.txt' => "Before\nAfter"
      }
    end
  end

  #---------------------------------------------------------------------------------------------------------------------

  describe 'Resource patch creation & deployment', :slow do

    def copy_to(ver, dir)
      FileUtils.cp_r "#{migration_dir ver}/.", dir
    end

    def create_pkg
      ResPatchManager.new('mig').create_res_patch_files! 'a','b'
    end

    def deploy_pkg(ver=:latest)
      %w[a b].each{|d| FileUtils.rm_rf d if Dir.exists?(d) }
      ResPatchManager.new('mig').with_resources(ver){|dir|
        Dir.chdir(dir){
          yield
        }
      }
    end

    def deploy_latest
      %w[a b r].each{|d| FileUtils.rm_rf d if Dir.exists?(d) }
      ResPatchManager.new('mig').deploy_latest_resources 'r'
      if block_given?
        Dir.chdir('r'){ yield }
      end
    end

    def shuffle
      FileUtils.rm_r 'a'
      File.rename 'b', 'a'
      Dir.mkdir 'b'
    end

    def create_patch_1
      %w[a b mig].each{|d| Dir.mkdir d unless Dir.exists? d }
      copy_to 1, 'b'
      create_pkg
      Dir['mig/**/*'].should == %w[mig/00001.patch]
    end
    def create_patch_2
      shuffle
      copy_to 2, 'b'
      create_pkg
      Dir['mig/**/*'].sort.should == %w[mig/00001.patch mig/00002.patch]
    end
    def create_patch_3
      shuffle
      copy_to 3, 'b'
      create_pkg
      Dir['mig/**/*'].sort.should == %w[mig/00001.patch mig/00002.patch mig/00003.patch]
    end

    context 'no res patches' do
      run_all_in_empty_dir {
        Dir.mkdir 'mig'
      }
      it("should do nothing when attemping to deploy latest"){ deploy_latest{ get_files.should be_empty } }
      it("should do nothing when attemping to deploy v0"){ deploy_pkg{ get_files.should be_empty } }
    end

    context '1 res patch' do
      run_all_in_empty_dir {
        create_patch_1
      }
      it("should deploy v1"){ deploy_pkg{ assert_files migration_dir 1 } }
      it("should deploy latest"){ deploy_latest{ assert_files migration_dir 1 } }
    end

    context '2 res patches' do
      run_all_in_empty_dir {
        create_patch_1
        create_patch_2
      }
      it("should deploy v2"){ deploy_pkg{ assert_files migration_dir 2 } }
      it("should deploy v1"){ deploy_pkg(1){ assert_files migration_dir 1 } }
      it("should deploy latest"){ deploy_latest{ assert_files migration_dir 2 } }
    end

    context '3 res patches' do
      run_all_in_empty_dir {
        create_patch_1
        create_patch_2
        @patch_1= File.read 'mig/00001.patch'
        create_patch_3
      }
      it("should deploy v3"){ deploy_pkg{ assert_files migration_dir 3 } }
      it("should deploy v2"){ deploy_pkg(2){ assert_files migration_dir 2 } }
      it("should deploy v1"){ deploy_pkg(1){ assert_files migration_dir 1 } }
      it("should not modify patches prior to n-1"){ File.read('mig/00001.patch').should == @patch_1 }
      it("should deploy latest"){ deploy_latest{ assert_files migration_dir 3 } }
    end

  end
end
