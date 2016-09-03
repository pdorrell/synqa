require 'rspec/core/rake_task'

gems_dir = "#{ENV['HOME']}/.gem"
ENV['GEM_HOME'] = gems_dir
ENV['GEM_PATH'] = gems_dir

begin
  require "bundler"
  Bundler.setup
rescue LoadError
  $stderr.puts "You need to have Bundler installed to be able build this gem."
end

gemspec = eval(File.read("synqa.gemspec"))

desc "Validate the gemspec"
task :gemspec do
  gemspec.validate
end

desc "Build gem locally"
task :build => :gemspec do
  system "gem build #{gemspec.name}.gemspec"
  FileUtils.mkdir_p "pkg"
  FileUtils.mv "#{gemspec.name}-#{gemspec.version}.gem", "pkg"
end

desc "Install gem locally"
task :install => :build do
  system "gem install --user-install pkg/#{gemspec.name}-#{gemspec.version}.gem"
end

desc "Clean automatically generated files"
task :clean do
  FileUtils.rm_rf "pkg"
end

require 'rake/testtask'
 
Rake::TestTask.new do |t|
  t.libs.push 'test'
  t.pattern = 'test/**/test_*.rb'
  t.warning = true
  t.verbose = true
end
 
task :default => :test
