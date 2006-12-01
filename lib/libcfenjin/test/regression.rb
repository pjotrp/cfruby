# Regression tester
#

module Cfruby

	def Cfruby.regressiontest_create b
		@@test_create = b
	end
	
	#  Invoke the regression test by passing a string - which ends up a file
	#  in test/regression with +filename+. When +create+ is +true+ the file
	#  will be created/overwritten. Otherwise it is tested against returning
	#  whether it has equal or not. When a test fails both test file and new
	#  file exist in the regrssion directory - so you can execute a diff.
	#
	#  Example:
	#    Cfruby.regressiontest `#{cfrubybin} --help`,'cfruby_helptext',$test_create

	def Cfruby.regressiontest text, filename, create = @@test_create
		testdir = regressiontestpath
		fn = testdir+'/'+filename+'.rtest'
		fntest = fn+'.new'
		
		if create
			f = File.open(fn,'w')
			f.write text
			File.unlink fntest if File.exist? fntest
		else
			# ---- here we have to compare info
			if ! File.exist?(fn)
				raise "Cannot execute regression test because file #{fn} does not exist! - use --create option?"
			end
			f = File.open(fn)
			b = ''
			f.each do | line |
				b += line
			end
			if b!=text
				# ---- Write newer file
				f2 = File.open(fntest,'w')
				f2.write text
				return false
			end
		end
		true
	end

	# Returns location of regression test directory, which is part of
	# the source repository in darcs, so as to retain regression test
	# information
	def Cfruby.regressiontestpath
		File.dirname(__FILE__)+'/../../../test/cfenjin/regression'
	end
end
