#!/usr/bin/env ruby
# Unit test for the Exec module

$: << File.dirname(__FILE__) + '/../../lib'

require 'test/unit'
require 'tempfile'
require 'fileutils'
require 'libcfruby/cfyaml'


# Tests the Cfruby::Exec class
class TC_Exec < Test::Unit::TestCase

	def setup()
		# disable file backups - we aren't testing that here
		Cfruby::FileOps.set_backup(false)

		file = Tempfile.new('test')
		file.close()
		@filename = file.path

		@fileconf = Hash.new()
		@fileconf['filename'] = @filename
	end


	def teardown()
		Cfruby::FileOps.set_backup(true)
	end

	def test_mode()
		@fileconf['mode'] = 0600
		CfYAML.configure_file(@fileconf)
		
		t = Tempfile.new('test')
		FileUtils.chmod(0600, t.path)
		assert_equal(File.stat(t.path).mode, File.stat(@filename).mode, "chmod to 0600 failed")
	end
	
	
	def test_chown()
		if(Process.euid() == 0)
			@fileconf['user'] = 0
			CfYAML.configure_file(@fileconf)
			assert_equal(0, File.stat(@filename).uid, "chown to uid 0 failed")

			@fileconf['user'] = nil
			@fileconf['group'] = 0
			CfYAML.configure_file(@fileconf)
			assert_equal(0, File.stat(@filename).gid, "chown to gid 0 failed")
		end
	end


	def test_set()
		@fileconf['set'] = Array.new()
		@fileconf['set'] << Array.[]('foo', 'bar')
		@fileconf['set'] << Array.[]('baz', 'bang')
		CfYAML.configure_file(@fileconf)
		
		File.open(@filename, File::RDONLY) { |fp|
			lines = fp.readlines()
			assert_equal(true, lines.include?("foo=bar\n"), "set foo to bar failed")
			assert_equal(true, lines.include?("baz=bang\n"), "set baz to bang failed")
		}

		@fileconf['set'] = Array.new()
		@fileconf['set'] << Array.[]('foo', 'bong')
		CfYAML.configure_file(@fileconf)

		File.open(@filename, File::RDONLY) { |fp|
			lines = fp.readlines()
			assert_equal(true, lines.include?("foo=bong\n"), "set foo to bong failed")
			assert_equal(true, lines.include?("baz=bang\n"), "set erased previous set of baz to bang failed")
		}
	end
	
end
