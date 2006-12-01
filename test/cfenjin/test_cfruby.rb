#!/usr/local/bin/ruby
# Unit Tests for main Cfruby programme

require 'test/unit'
require 'libcfenjin/test/regression'

class TC_CfrubyBin < Test::Unit::TestCase
	
	# Regression test (this is an odd one since it starts up Cfruby itself -
	# it is nice because it does an implicit syntax check)

	def test_helptext()
		cfrubybin = File.dirname(__FILE__) + '/../../bin/cfenjin'
		
		assert(Cfruby.regressiontest(`#{cfrubybin} --help`,'cfruby_helptext'),
					 'Regression test on cfruby --help')
	end
	
end
