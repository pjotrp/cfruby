#!/usr/bin/env ruby
# Unit Tests for filedit module

$: << File.dirname(__FILE__) + '/../../lib'

require 'test/unit'
require 'tempfile'
require 'fileutils'
require 'libcfruby/checksum'

# Tests the Cfruby::Checksum::Checksum class
class TC_Checksum < Test::Unit::TestCase

	def setup()
		tempfile = Tempfile.new('checksum')
		@databasefile = tempfile.path
		tempfile.close(true)
		
		@checksum = Cfruby::Checksum::Checksum.new(@databasefile)
		
		# add a test file
		@tempfile = Tempfile.new('checksum')
		@tempfile.print("This is some content")
		@tempfile.close(false)
		@checksum.check(@tempfile.path)
	end
	
	
	def teardown()
		begin
			@tempfile.close(true)
			FileUtils.rm(@databasefile)
		rescue
			# ignore
		end
	end
	
	
	# check getting checksums of a stream
	def test_get_checksum_stream
		basechecksum = Cfruby::Checksum::Checksum.get_checksums(@tempfile.path)
		File.open(@tempfile.path) { |fp|
			streamchecksum = Cfruby::Checksum::Checksum.get_checksums(fp)
			assert_equal(basechecksum, streamchecksum)
		}
	end
	
	
	def test_check?()
		assert(@checksum.check?(@tempfile.path))
		File.open(@tempfile.path, File::WRONLY | File::TRUNC) { |fp|
			fp.puts("snazzy new content")
		}
		assert_equal(false, @checksum.check?(@tempfile.path))
	end
	
	
	# checks the permission, existence, and ownership controls on the database file
	def test_database_checks()
		currentmode = File.stat(@databasefile).mode
		Cfruby::FileOps.chmod(@databasefile, 0700)
		assert_not_equal(currentmode, File.stat(@databasefile).mode)
		assert_raise(Cfruby::Checksum::ChecksumPermissionError) {
			@checksum.update_all
		}
		Cfruby::FileOps.chmod(@databasefile, 0600)
		
		if(Process.euid() == 0)
			assert_raise(Cfruby::Checksum::ChecksumOwnershipError) {
				Cfruby::FileOps.chown(@databasefile, 200, 200)
				@checksum.update_all
			}
		end
	end
	
	
	# check adding a file to the database
	def test_check_new()
		assert_nothing_raised() {
			@checksum.check(@databasefile)
		}
	end
	
	
	# check a file being added to the database and then changed
	def test_checksum_change()
		assert_nothing_raised() {
			@checksum.check(@databasefile)
		}

		assert_raise(Cfruby::Checksum::ChecksumMatchError, "check of changed file content in database failed to raise exception") {
			@checksum.check(@databasefile)
		}
		
		assert_equal(false, @checksum.check?(@databasefile))
	end
	
	
	# check update of file in database
	def test_update()
		@checksum.check(@databasefile)
		
		File.open(@tempfile.path, File::WRONLY|File::APPEND) { |fp|
			fp.print("New content")
		}
		
		assert_nothing_raised("update of checksum failed") {
			@checksum.update(@tempfile.path)
			@checksum.check(@tempfile.path)
		}
	end
end
