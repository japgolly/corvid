require 'raven/generators/base'

class Raven::Generator::Update < Raven::Generator::Base

  desc 'deps', 'Update dependencies. (Recreates Gemfile.raven)'
  method_options dryrun: false
  method_options use_raven_gem: true
  def deps
    d= DepBuilder.new(options)
    d.instance_eval File.read("#{self.class.source_root}/Gemfile.raven")
    content= d.to_s
    if options[:dryrun]
      puts content
    else
      create_file 'Gemfile.raven', content
      unless $raven_bundle_install_at_exit_installed
        $raven_bundle_install_at_exit_installed= true
        #at_exit{ say_status 'exec','bundle install'; system "bundle install" }
        at_exit{ run "bundle install" }
      end
    end
  end

  private

  class DepBuilder
    attr_reader :options

    def initialize(options)
      @options= options
      @header= []
      @libs= {}
      @footer= []
    end

    def header(line)
      @header<< line
    end

    def footer(line)
      @footer<< line
    end

    def group(*names)
      @groups= names
      yield self
      nil
    ensure
      @groups= nil
    end

    def gem(lib, *args)
      options= args.last.kind_of?(Hash) ? args.pop : {}
      if @groups
        options[:group]= [options[:group],@groups].flatten.compact.uniq.sort_by(&:to_s)
        options[:group]= options[:group].first if options[:group].size == 1
      end

      group= options.delete(:group)
      bucket= (@libs[group] ||= [])

      a= ([lib] + args).map(&:inspect)
      a.concat options.to_a.map{|k,v| "#{k}: #{v.inspect}" }
      bucket<< "gem #{a.join ', '}"
      true
    end

    def to_s
      lines= []
      lines.concat @header + [''] unless @header.empty?
      @libs[nil].sort.each{|l| lines<< l } if @libs[nil]
      @libs.keys.compact.sort_by(&:to_s).map do |g|
        lines<< "group #{g.inspect} do"
        @libs[g].sort.each{|l| lines<< "  #{l}"}
        lines<< "end"
        end.to_a
      lines.concat [''] + @footer unless @footer.empty?
      lines.join "\n"
    end
  end
end
