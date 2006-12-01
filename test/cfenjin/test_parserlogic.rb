#!/usr/local/bin/ruby
# Unit Tests for main Cfruby (parser) program

require 'test/unit'
require 'libcfenjin/test/regression'
require 'libcfenjin/parser'

class TC_CfrubyParserLogic < Test::Unit::TestCase

	def setup
		# ---- Setup global Cfstatus class:
		# @cf = Cfruby::Cfp_Stat.new
		@basedir = File.dirname(__FILE__)+'/../'
		@playground = File.dirname(__FILE__)+'/playground'
		Cfruby::FileOps.mkdir @playground
	end

	def teardown
		Cfruby::FileOps.rmdir @playground
	end

	# Test whether the environment works
	def test_direct
		testfn = @playground+'/linktestfile'
		testln = @playground+'/linktestlink'
		Cfruby::FileOps.touch testfn
		assert(File.exist?(testfn))
		# Test syntax parsing
		Cfruby::Parser.new.links "#{testln} -> #{testfn}"
		assert(File.symlink?(testln))
		Cfruby::FileOps.delete testln
		# Cleanup
		Cfruby::FileOps.delete testfn
	end

	def test_control
		parser = Cfruby::Parser.new 
		# Ruby assignments
		assert_equal('sshd = (any )',parser.form('control','sshd = (any )'))
		assert_equal('sshd =( any )',parser.form('control','sshd =( any )'))
		# Cfruby class assignments
		assert_equal('assign %w{ sshd any }',parser.form('control','sshd = ( any )'))
		assert_equal('assign %w{ sshd any test }',parser.form('control','sshd = ( any test )'))
	end

	def test_link
		parser = Cfruby::Parser.new
		# ---- Ruby pass-through
		assert_equal('link testfn,testln',parser.form('links','link testfn,testln'))
		assert_equal('link testfn,@testln',parser.form('links','link testfn,@testln'))
		# ---- Cfruby style - with local, class and global variables
		assert_equal('link testfn,testln',parser.form('links','testln->testfn'))
		assert_equal('link testfn,@testln',parser.form('links','@testln -> testfn'))
		assert_equal('link $testfn,testln',parser.form('links','testln -> $testfn'))
		# ---- Cfruby style - with strings
		assert_equal('link "testfn","testln"',parser.form('links','"testln" -> "testfn"'))
		assert_equal('link "testfn",\'testln\'',parser.form('links','\'testln\' -> "testfn"'))
	
		# ---- Cfruby style - with file paths
		assert_equal('link "/testfn","./testln"',parser.form('links','./testln->/testfn'))
		assert_equal('link "/"+$testfn,"./#{@testln}"',parser.form('links','"./#{@testln}"->"/"+$testfn'))
		assert_equal('link "/mnt/archive","/usr/archive"',parser.form('links','/usr/archive -> /mnt/archive'))
	end

	def test_copy
		parser = Cfruby::Parser.new
		# ---- Ruby pass-through
		assert_equal('copy dest,src,{"m"=>0444}',parser.form('copy','copy dest,src,{"m"=>0444}'))
		# ---- Cfruby style
		assert_equal('copy src,{\'dest\'=>dest}',parser.form('copy','src dest=dest'))
		assert_equal("copy @masterfiles+'cftest.txt',{'dest'=>\"cftest.txt\",'mode'=>0444}",parser.form('copy',' @masterfiles+\'cftest.txt\' dest="cftest.txt" m=444'))
		assert_equal('copy src,{\'dest\'=>dest,\'mode\'=>0444}',parser.form('copy','src dest=dest m=0444'))
		assert_equal('copy src,{\'dest\'=>dest,\'mode\'=>0444}',parser.form('copy','src dest=dest m=444'))
		assert_equal('copy src,{\'dest\'=>dest,\'mode\'=>0664,\'owner\'=>\'wrk\',\'group\'=>\'group\'}',parser.form('copy','src dest=dest m=664 owner=wrk g=group'))
		assert_equal('copy src,{\'dest\'=>dest,\'mode\'=>0664,\'owner\'=>\'www-data\',\'group\'=>\'www-data\'}',parser.form('copy','src dest=dest m=664 owner=www-data g=www-data'))
		assert_equal('copy src,{\'dest\'=>dest,\'mode\'=>0664,\'owner\'=>\'www-data\',\'group\'=>\'www-data\'}',parser.form('copy','src dest=dest m=664 owner=\'www-data\' g=\'www-data\''))
	end

	def test_tidy
		parser = Cfruby::Parser.new
		assert_equal('tidy testtidy',parser.form('tidy','testtidy'))
		assert_equal("tidy testtidy,{'recurse'=>'inf'}",parser.form('tidy','testtidy rec=inf'))
	end
	
	def test_directories
		parser = Cfruby::Parser.new
		assert_equal("directories \"/mnt/export\"",parser.form('directories','/mnt/export'))
		assert_equal("directories \"/mnt/export\",{'mode'=>0666}",parser.form('directories','/mnt/export m=666'))
	end
	
	def test_files
		parser = Cfruby::Parser.new
		assert_equal("files \"/etc/resolv.conf\"",parser.form('files','/etc/resolv.conf'))
		assert_equal("files \"/etc/resolv.conf\",{'mode'=>0644}",parser.form('files','/etc/resolv.conf m=644'))
	end

	def test_shellcommands
		parser = Cfruby::Parser.new
		assert_equal("Cfruby.controller.inform(\"verbose\", \"message\n\#{command}\")",parser.embed_exec_into_informer('command','message'))
		assert_equal("Cfruby.controller.inform(\"verbose\", \"Shell: `grep root /etc/passwd`\n\n\#{`grep root /etc/passwd`}\")",parser.form('shellcommands','`grep root /etc/passwd`'))
		# with single quotes
		assert_equal("Cfruby.controller.inform(\"verbose\", \"Shell: `grep 'root' /etc/passwd`\n\n\#{`grep 'root' /etc/passwd`}\")",parser.form('shellcommands','`grep \'root\' /etc/passwd`'))
		# with double quotes
		assert_equal("Cfruby.controller.inform(\"verbose\", \"Shell: `grep \\\"root\\\" /etc/passwd`\n\n\#{`grep \"root\" /etc/passwd`}\")",parser.form('shellcommands','`grep "root" /etc/passwd`'))
	end

	# Load the conditional file from the regression test directory
	def test_conditional
		parser = Cfruby::Parser.new
		assert_equal("if isa?('hostname') and isa?('any')",parser.form_conditional('hostname.any::'))
		f = File.new Cfruby.regressiontestpath+'/cfruby_conditionals.txt'
		f.each_line do | line |
			next if line =~ /^\#/ or line =~ /^$/
			from, to = line.split(/::/)
			assert_equal(to.strip, parser.form_conditional(from.strip+'::').strip) if from
		end
	end

end

