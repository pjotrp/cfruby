#!/usr/bin/env ruby
# Unit test for the Exec module

$: << File.dirname(__FILE__) + '/../../lib'

require 'test/unit'
require 'tempfile'
require 'fileutils'
require 'libcfruby/exec'
require 'libcfruby/cfrubyscript'


# Tests the Cfruby::Exec class
class TC_Exec < Test::Unit::TestCase

	# writes a dynamic test script to a file for testing purposes
	def write_sampleexec(fp)
		fp.print("#!/usr/bin/env ruby\n")
		fp.print("# Sample executable with both stdout and stderr output for unit testing\n")
		fp.print("# of the Exec module\n")

		fp.puts("if(ARGV.length > 0)")
		fp.puts("\tputs(ARGV[0])")
		fp.puts("\texit()")
		fp.puts("end")

		fp.print("1.upto(10) { |i|\n")
		fp.print("\t$stdout.print(\"stdout - \#{i}\n\")\n")
		fp.print("\t$stderr.print(\"stderr - \#{i}\n\")\n")
		fp.print("}\n")
	end
	

	# test shell execution
	def test_shellexec()
		tempfile = Tempfile.new('sampleexec', './')
		write_sampleexec(tempfile)
		tempfile.close(false)
		FileUtils.chmod(0700, tempfile.path)

		# test via direct call
		output = Cfruby::Exec::shellexec(tempfile.path, "mytest")
		assert_equal("mytest\n", output)
	end
	
	
	# test the exec method
	def test_exec()
		tempfile = Tempfile.new('sampleexec', './')
		write_sampleexec(tempfile)
		tempfile.close(false)
		FileUtils.chmod(0700, tempfile.path)

		# test via direct call
		output = Cfruby::Exec::exec(tempfile.path)
		assert_equal(output.length, 2)
		assert_equal(10, output[0].length, "expected 10 lines of stdout")
		assert_equal(10, output[1].length, "expected 10 lines of stderr")

		# test via the String exec() helper method
		tempfile.path.exec
		assert_equal(output.length, 2)
		assert_equal(10, output[0].length, "expected 10 lines of stdout")
		assert_equal(10, output[1].length, "expected 10 lines of stderr")		
	end

end