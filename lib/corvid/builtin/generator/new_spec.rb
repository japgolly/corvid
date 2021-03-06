require_relative 'base'

class Corvid::Builtin::Generator::NewSpec < ::Corvid::Generator::Base
  namespace 'new:test'

  argument :name, type: :string, desc: "The specification name, or source file for which to generate a spec."

  desc 'spec', 'Generates a new specification.'
  def spec
    validate_requirements! 'corvid:test_spec'
    with_installed_resources(builtin_plugin) {
      template2 'test/spec/%src%_spec.rb.tt'
    }
  end

  # Template vars
  private
  def src
    preprocess_template_name_arg(name)
      .sub(/^test[\\\/]+spec[\\\/]+/,'')
      .sub(/_spec$/,'')
  end
  def bootstrap_dir; '../'*src.split(/[\\\/]+/).size + 'bootstrap' end
  def testcase_name; src.split(/[\\\/]+/).last.camelcase end
  def subject; src.camelcase end
end
