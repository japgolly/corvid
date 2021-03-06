# encoding: utf-8
require_relative '../bootstrap/integration'

describe 'Client Functionality provided by Corvid' do
  run_all_in_empty_dir 'int_test'
  before(:each){ clean }

  def clean
    return unless Dir.exist?('target')
    invoke_rake! 'clean'
    Dir.exist?('target').should == false
  end

  it("should install itself into new project"){
    invoke_corvid! "init --no-#{RUN_BUNDLE} --test-unit --test-spec"
    init_gemfile
    File.write 'lib/hehe.rb', 'class Hehe; def num; 123 end end'
    File.write 'lib/unfinished.rb', "# T\ODO whatever"
  }

  it("should include a todo task"){
    @capture_sh= true
    invoke_rake! 'todo'
    @stdout.should match /unfinished\.rb/
    @stdout.should_not match /hehe\.rb/
  }

  it("should include a stats task"){
    @capture_sh= true
    invoke_rake! 'stats'
    @stdout.should match /Code LOC/
  }

  it("should generate documentation"){

    def check_docs_exist(expected)
      File.exist?('target/doc/index.html').should == expected
      File.exist?('target/yardoc.db').should == expected
      File.exist?('target').should == true
    end

    # Generate docs
    invoke_rake! 'doc'
    check_docs_exist true

    # Clean docs (#1)
    invoke_rake! 'doc:clean'
    check_docs_exist false

    # Clean docs (#2)
    invoke_rake! 'doc'
    check_docs_exist true
    invoke_rake! 'clean:doc'
    check_docs_exist false
  }

  it("should support unit tests"){
    # Create unit test
    invoke_corvid! 'new:test:unit hehe'
    invoke_sh! %!sed -i 's/# T[O]DO/def test_hehe; assert_equal 123, Hehe.new.num end/' test/unit/hehe_test.rb!

    # Invoke via rake (by default without coverage)
    invoke_rake! 'test:unit'
    File.exist?('target/coverage/index.html').should == false

    # Invoke via rake
    invoke_rake! 'test:unit coverage=1'
    File.exist?('target/coverage/index.html').should == true

    # Rerun directly
    clean
    invoke_sh! 'ruby test/unit/hehe_test.rb', 'coverage'=>'1'
    File.exist?('target/coverage/index.html').should == true
  }

  it("should support specs"){
    # Create spec
    invoke_corvid! 'new:test:spec hehe'
    invoke_sh! %!sed -i 's/# T[O]DO/it("num"){ subject.num.should == 123 }/' test/spec/hehe_spec.rb!

    # Invoke via rake
    invoke_rake! 'test:spec coverage=1'
    File.exist?('target/coverage/index.html').should == true

    # Rerun directly
    clean
    invoke_sh! 'bin/rspec test/spec/hehe_spec.rb', 'coverage'=>'1'
    File.exist?('target/coverage/index.html').should == true
  }

end
