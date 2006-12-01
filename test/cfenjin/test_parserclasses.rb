#!/usr/local/bin/ruby
# Unit Tests for main Cfruby (parser) program

require 'test/unit'
require 'libcfenjin/test/regression'
require 'libcfenjin/parser'

class TC_CfrubyParserClasses < Test::Unit::TestCase

	def setup
		@parser = Cfruby::Parser.new
		@hostname = Cfruby::OS.get_os().hostname
	end

	def teardown
	end

	def test_classes
		@parser.cfgroup %w{ server machine1 machine2 }
		@parser.cfgroup %w{ mailer server server }
		@parser.cfgroup %w{ procmail mailer }
		@parser.cfgroup 'test', [ @hostname ]
		# @parser.dump_classlist
		assert(!@parser.isa?('server'))
		assert(!@parser.isa?('mailer'))
		assert(!@parser.isa?('procmail'))
		assert(@parser.isa?('test'))
	
		# FIXME: test circulars
		# @parser.cfgroup %w{ mailer procmail }
		# @parser.dump_classlist
		# assert(!@parser.isa?('mailer'))
		# assert(!@parser.isa?('procmail'))
	end

end

