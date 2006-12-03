p $:

require 'rubygems'

spec = Gem::Specification.new do |s|
	s.name = 'cfruby'
	s.version = "1.0"
	s.platform = Gem::Platform::RUBY
	s.summary = "A collection of modules, classes, and tools for system maintenance and configuration"
	s.description = "Cfruby provides a large array of helpful modules, classes, and tools for simple, powerful, cross platform system maintenance"

	# update VERSION in bin/cfenjin
	`echo #{s.version} > bin/VERSION`

	# libraries
	s.files = Dir.glob(File.dirname(__FILE__) + "/../lib/libcfenjin/*")
	s.files = s.files + Dir.glob(File.dirname(__FILE__) + "/../lib/libcfenjin/test/*")
	s.files = s.files + Dir.glob(File.dirname(__FILE__) + "/../lib/libcfruby/*")
	s.files = s.files + Dir.glob(File.dirname(__FILE__) + "/../lib/libcfruby/osmodules/*")

	# tests
	s.files = s.files + Dir.glob(File.dirname(__FILE__) + "/../test/*")
	s.files = s.files + Dir.glob(File.dirname(__FILE__) + "/../test/cfenjin/*")
	s.files = s.files + Dir.glob(File.dirname(__FILE__) + "/../test/cfenjin/libcfenjin/*")
	s.files = s.files + Dir.glob(File.dirname(__FILE__) + "/../test/cfenjin/regression/*")
	s.files = s.files + Dir.glob(File.dirname(__FILE__) + "/../test/libcfruby/*")
	s.test_file = File.dirname(__FILE__) + '/../test/runner.rb'
	
	# binaries
	s.files = s.files + Dir.glob(File.dirname(__FILE__) + "/../bin/*")
	s.bindir = 'bin'
	s.executables << 'cfenjin'
	s.executables << 'cfyaml'
	
	s.required_ruby_version = '>= 1.8.1'
	s.autorequire = 'libcfruby/libcfruby'
	s.author = "David Powers, Pjotr Prins, Kelley Reynolds, Kevin Way"
	s.email = "david@grayskies.net"
	s.rubyforge_project = "cfruby"
	s.homepage = "http://cfruby.rubyforge.org"
	s.has_rdoc = true
end


if $0==__FILE__
	Gem.manage_gems
	Gem::Builder.new(spec).build
end
