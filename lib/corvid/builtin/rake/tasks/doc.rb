require 'yard'

YARD::Rake::YardocTask.new(:doc)

namespace :doc do
  def get_doc_output_dirs
    yardopts= File.read("#{APP_ROOT}/.yardopts").gsub(/[\r\n]+/,' ')
    %w[db output-dir].map do |opt_key|
      if yardopts =~ /--#{opt_key}\s+(.+?)(?:\s|$)/
        $1
      end
    end.compact
  end

  task :clean do
    get_doc_output_dirs.each do |dir|
      full_dir= File.join(APP_ROOT,dir)
      if File.exists?(full_dir)
        puts "Deleting #{dir}"
        FileUtils.rm_rf full_dir
      end
    end
  end

  desc 'Starts the YARD server.'
  task :server do
    cmd= "bundle exec yard server --reload"
    puts "Running: #{cmd}"
    Dir.chdir(APP_ROOT){ system cmd }
  end

  # Create aliases for doc:server
  task serve: :server
  task s: :server

  desc 'Clean & Serve: Wipes existing doc db and starts the YARD server.'
  task cs: [:clean, :server]
end

namespace :clean do
  task :doc => 'doc:clean'
end
