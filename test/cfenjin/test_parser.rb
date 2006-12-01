#!/usr/local/bin/ruby
# Unit Tests for main Cfruby (parser) program

require 'test/unit'
require 'libcfenjin/test/regression'
require 'libcfenjin/cfp_stat'
require 'libcfenjin/cfp_manager'
require 'libcfenjin/parser'

class TC_CfrubyParser < Test::Unit::TestCase

	def setup
		@basedir = File.dirname(__FILE__)+'/..'
		@playground = File.dirname(__FILE__)+'/playground'
		@examples = @basedir + '/documentation/examples'
		# Make sure it is clean
		teardown
		# ---- Setup global Cfstatus class:
		@cf = Cfruby::Cfp_Stat.new
		Cfruby::FileOps.mkdir @playground
	end

	def teardown
		Cfruby::FileOps.delete(@playground, :force => true, :recursive => true) if File.directory? @playground
	end

	# Regression test (this is an odd one since it starts up Cfruby itself -
	# it is nice because it does an implicit syntax check)

	def test_dumpbin()
		cfrubybin = File.dirname(__FILE__) + '/../../bin/cfenjin'
		examples  = File.dirname(__FILE__) + '/../../documentation/cfenjin/examples' 
		# Note: we have to change directories because the tests can be run
		# from two levels in the source tree and it confuses the automatic
		# class names
		assert_equal(true,Cfruby.regressiontest(`cd #{@basedir} ; #{cfrubybin} --dry-run --dump-compiled #{examples}/cfsshd.rb`,'cfruby_parser'),'Regression test on cfenjin --dump cfsshd.rb')
		assert_equal(true,Cfruby.regressiontest(`cd #{@basedir} ; #{cfrubybin} --dry-run --dump-compiled #{examples}/site.rb #{examples}/cfresolv.rb`,'cfruby_parser2'),'Regression test on cfenjin --dump cfsshd.rb')
	end

	def test_script
		# ---- Test good script
		testscript = File.dirname(__FILE__)+'/libcfenjin/cfscripttest.rb'
		assert(File.exist?(testscript),"Can't locate #{testscript}")
		manager = Cfruby::Cfp_Manager.new @cf
		manager.parse testscript
		manager.compile
		manager.execute
		assert(@cf.site['global_assignment'] == 1)

		# ---- Test bad script (raises syntatx error)
		testscript = File.dirname(__FILE__)+'/libcfenjin/cfscripttest_error.rb'
		assert(File.exist?(testscript),"Can't locate #{testscript}")
		manager = Cfruby::Cfp_Manager.new @cf
		manager.parse testscript
		has_error = false
		begin
			manager.compile
			manager.execute
		rescue SyntaxError, RuntimeError
			has_error = true
		end
		# if no exception is thrown the assertion fails:
		assert(has_error)
	end

	# This tests the different ways one can link a file from Cfruby
	def test_link
		testfn = @playground+'/linktestfile'
		testln = @playground+'/linktestlink'
		Cfruby::FileOps.touch testfn
		assert(File.exist?(testfn))
		# First test library
		Cfruby::FileOps.link testfn,testln
		assert(File.symlink?(testln))
		assert(Cfruby::FileOps::SymlinkHandler.points_to?(testln,testfn))
		# Test link pointing to other file
		testfn2 = testfn+'2'
		Cfruby::FileOps.touch(testfn2)
		assert(Cfruby::FileOps::SymlinkHandler.points_to?(testln,testfn))
		assert(!Cfruby::FileOps::SymlinkHandler.points_to?(testln,testfn2))
		Cfruby::FileOps.delete testln
		Cfruby::FileOps.delete testfn2
		# Now test parser link method
		Cfruby::Parser.new(@cf).run 'link',testfn,testln
		assert(File.symlink?(testln))
		Cfruby::FileOps.delete testln
		# Test syntax parsing
		Cfruby::Parser.new(@cf).links "#{testln} -> #{testfn}"
		assert(File.symlink?(testln))
		Cfruby::FileOps.delete testln
		# Cleanup
		Cfruby::FileOps.delete testfn
	end

	def test_copy
		src  = @playground+'/test_copy_src.tmp'
		dest = @playground+'/test_copy_dest.tmp'
		Cfruby::FileOps.touch src
		assert_equal(0100644,File.stat(src).mode)
		assert(File.exist?(src))
		# First test library
		Cfruby::FileOps.copy src,dest
		assert(File.exist?(dest))
		Cfruby::FileOps.delete dest
		Cfruby::FileOps.copy src,dest,{:mode=>0600}
		assert(File.exist?(dest))
		assert_equal(0100600,File.stat(dest).mode)
		Cfruby::FileOps.delete dest
		# Now test parser link method
		Cfruby::Parser.new.run 'copy',src,dest
		assert(File.exist?(dest))
		Cfruby::FileOps.delete dest
		# Test syntax parsing
		Cfruby::Parser.new.copy "#{src} dest=#{dest}"
		assert(File.exist?(dest))
		Cfruby::FileOps.delete dest
		# Test with mode
		Cfruby::Parser.new.copy "#{src} dest=#{dest} m=600"
		# p sprintf("%o",File.stat(dest).mode)
		assert_equal(0100600,File.stat(dest).mode)
		Cfruby::FileOps.delete dest
		# Test with owner/group (only as root)
		# Cfruby::Parser.new.copy "#{src} dest=#{dest} m=600 o=wrk g=pacs"
		# assert(File.owned?(dest))
		# assert(File.grpowned?(dest))
		# Cfruby::FileOps.delete dest
		# Test euid ownership if root
		if(Process.euid == 0)
			Cfruby::Parser.new.copy "#{src} dest=#{dest} m=600"
			assert_equal(0100600,File.stat(dest).mode)
			assert(File.owned?(dest))
			Cfruby::FileOps.delete dest
		end
		Cfruby::FileOps.delete src
	end
	
	def test_tidy
		target  = @playground+'/test_tidy.tmp'
		# First test library
		Cfruby::FileOps.touch target
		assert(File.exist?(target))
		Cfruby::FileOps.delete target
		assert(!File.exist?(target))
		# Now test parser link method
		Cfruby::FileOps.touch target
		assert(File.exist?(target))
		Cfruby::Parser.new.run 'tidy',target
		assert(!File.exist?(target))
		# Test syntax parsing
		Cfruby::FileOps.touch target
		Cfruby::Parser.new.tidy "#{target}"
		assert(!File.exist?(target))

		# Test recursive tidying
		dir1 = @playground + '/dir1'
		dir1_1 = @playground + '/dir1/dir1'
		dir1_2 = @playground + '/dir1/dir2'
		fn1    = dir1_1 + '/testfn1'
		fn2    = dir1_2 + '/testfn2'
		Cfruby::FileOps.mkdir dir1_1,{:makeparent=>true}
		Cfruby::FileOps.mkdir dir1_2
		Cfruby::FileOps.touch fn1
		Cfruby::FileOps.touch fn2
		assert(File.exist?(fn2))
		Cfruby::Parser.new.tidy "#{dir1_2} rec=inf rmdirs=true"
		assert(!File.exist?(fn2))
		assert(!File.exist?(dir1_2))
		Cfruby::Parser.new.tidy "#{dir1} rec=inf"
		assert(!File.exist?(fn1))
		assert(File.exist?(dir1_1))
		# Try depth delete - should not remove fn1
		Cfruby::FileOps.touch fn1
		Cfruby::Parser.new.tidy "#{dir1} rec=1"
		assert(File.exist?(fn1))
	end
	
	def test_directories
		target  = @playground+'/test_directories.tmp'
		# First test library
		Cfruby::FileOps.mkdir target
		assert(File.directory?(target))
		Cfruby::FileOps.rmdir target
		assert(!File.directory?(target))
		# Now test parser link method
		Cfruby::Parser.new.run 'directories',target
		assert(File.directory?(target))
		Cfruby::FileOps.rmdir target
		# Test syntax parsing
		Cfruby::Parser.new.directories "#{target}"
		assert(File.directory?(target))
		Cfruby::FileOps.rmdir target
		
		Cfruby::Parser.new.directories "#{target}"
		assert(File.directory?(target))
		# p sprintf("%o",File.stat(target).mode)
		assert_equal(040775,File.stat(target).mode)
		Cfruby::FileOps.rmdir target
	end
	
	def test_files
		target  = @playground+'/test_files.tmp'
		# First test library
		Cfruby::FileOps.touch target
		assert(File.file?(target))
		Cfruby::FileOps.delete target
		assert(!File.file?(target))
		# Now test parser link method
		Cfruby::FileOps.touch target
		Cfruby::Parser.new.run 'files',target,{'mode'=>0640}
		assert(File.file?(target))
		# p sprintf("%o",File.stat(target).mode)
		assert_equal(0100640,File.stat(target).mode)
		# File does not exist
		Cfruby::FileOps.delete target
		Cfruby::Parser.new.run 'files',target,{'mode'=>0600}
		assert(!File.file?(target))
		# assert_equal(0100600,File.stat(target).mode)
		# Test syntax parsing
		Cfruby::FileOps.touch target
		Cfruby::Parser.new.files "#{target} m=660"
		assert_equal(0100660,File.stat(target).mode)
		# p sprintf("%o",File.stat(target).mode)
		Cfruby::FileOps.delete target

		# Test pattern/glob feature
		Cfruby::FileOps.touch @playground+'/1a'
		Cfruby::FileOps.touch @playground+'/1b'
		Cfruby::FileOps.touch @playground+'/2c'
		Cfruby::Parser.new.files "#{@playground} pattern=1* m=660 act=fixplain"
		assert_equal(0100660,File.stat(@playground+'/1a').mode)
		assert_equal(0100660,File.stat(@playground+'/1b').mode)
		assert_equal(0100644,File.stat(@playground+'/2c').mode)
	end
	
end

