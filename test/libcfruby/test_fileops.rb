#!/usr/bin/env ruby
# Unit Tests for filedit module

$: << File.dirname(__FILE__) + '/../../lib'

require 'test/unit'
require 'tempfile'
require 'fileutils'
require 'libcfruby/fileops'
require 'libcfruby/flowmonitor'
require 'libcfruby/os'
require 'libcfruby/users'

# blocking observer for network tests
class TestFileOpsObserverBlocker < FlowMonitor::Observer
	attr_reader :lastmessage

	def initialize()
		@lastmessage = nil
	end

	def handle_message(message)
		@lastmessage = message
		return(false)
	end
end


# Tests the Cfruby::FileEdit module methods
class TC_FileOperations < Test::Unit::TestCase

	def setup()
		FileUtils.chdir('/')
		@basefile = Tempfile.new('fileop')
		@basefile.close(false)
		@deletefiles = Array.new()
	end
	
	
	def teardown()
		@deletefiles.each() { |filename|
			FileUtils.rm(filename)
		}
		@basefile.close(true)
	end
	
	
	def test_rsync()
		observer = TestFileOpsObserverBlocker.new()
		
		begin
			Cfruby.controller.register(observer)
			Cfruby::FileOps.copy("rsync://testuser@www.testserver.com:/home/tester/testfile", "/tmp", :archive => true)
			assert_equal("rsync -a testuser@www.testserver.com:/home/tester/testfile /tmp - pre-empted", observer.lastmessage.message)

			Cfruby::FileOps.copy("rsync://testuser@www.testserver.com:/home/tester/testfile", "/tmp", :recursive => true)
			assert_equal("rsync -r testuser@www.testserver.com:/home/tester/testfile /tmp - pre-empted", observer.lastmessage.message)

			Cfruby::FileOps.copy("rsync://testuser@www.testserver.com:/home/tester/testfile", "/tmp", :flags => "-n")
			assert_equal("rsync -n testuser@www.testserver.com:/home/tester/testfile /tmp - pre-empted", observer.lastmessage.message)
		ensure
			Cfruby.controller.unregister_all()
		end
		
		# test an actual rsync
		rsyncfile = Tempfile.new('fileops')
		tofile = Tempfile.new('fileops')
		File.open(rsyncfile.path, File::WRONLY | File::TRUNC) { |fp|
			fp.puts("rsync content")
		}
		Cfruby::FileOps.copy("rsync://#{rsyncfile.path}", tofile.path)
		File.open(tofile.path, File::RDONLY) { |fp|
			lines = fp.readlines()
			assert_equal("rsync content", lines[0].strip())
		}
	end
	
	
	def test_create()
		createfile = Tempfile.new('fileop')
		filename = createfile.path
		createfile.close(true)
		assert_nothing_raised("Error creating an empty file") {
			Cfruby::FileOps.create(filename)
		}
		FileUtils.rm(filename)
	end


	def test_mkdir()
		
		createdir = Tempfile.new('fileop')
		dirname = createdir.path
		createdir.close(true)
		begin
			# test making a directory passing a single dirname
			assert_nothing_raised("Error creating an new directory") {
				Cfruby::FileOps.mkdir(dirname)
			}
			assert_equal(true, File.directory?(dirname), "Failed to created directory with FileOps.mkdir")

			# test on a directory that is already there
			assert_nothing_raised("Error calling mkdir on an existing directory") {
				Cfruby::FileOps.mkdir(dirname)			
			}
			assert_equal(true, File.directory?(dirname), "Failed to created directory with FileOps.mkdir")

			# test the perms on the new directory - obviously they should be based on the umask, but
			# at least one informal test showed a possible problem in this area.  We are going to use a
			# shell command to test this
			permtestfile = Tempfile.new('fileop')
			permtestfile.close(true)
			`mkdir #{permtestfile.path}`
			properperms = File.stat(permtestfile.path).mode
			FileUtils.rm_rf(permtestfile.path)
			assert_equal(properperms, File.stat(dirname).mode, "mode of new directory not properly set according to umask")
		ensure
			FileUtils.rm_rf(dirname)
		end

		
		# test with an array
		dirfiles = Array.new()
		1.upto(20) { 
			createdir = Tempfile.new('fileop')
			dirfiles << createdir
		}
		
		directories = Array.new()
		dirfiles.each() { |dirfile|
			dirname = dirfile.path
			directories << dirname
			dirfile.close(true)
			assert_nothing_raised("Error creating a new directory") {
				Cfruby::FileOps.mkdir(dirname)
			}
			assert_equal(true, File.directory?(dirname), "Failed to created directory with FileOps.mkdir")
		}
		
		directories.each() { |dirname|
			FileUtils.rmdir(dirname)
		}
		
	end


	def test_rmdir
		dirfile = Tempfile.new('fileops')
		dirfilepath = dirfile.path
		dirfile.close(true)
		assert(!File.exists?(dirfilepath))
		
		# remove an empty dir
		Cfruby::FileOps.mkdir(dirfilepath)
		assert(File.exists?(dirfilepath))
		assert(test(?d, dirfilepath))
		Cfruby::FileOps.rmdir(dirfilepath)
		assert(!File.exists?(dirfilepath))
		
		# remove a non-existent dir
		assert_nothing_raised() {
			Cfruby::FileOps.rmdir(dirfilepath)
		}
		assert(!File.exists?(dirfilepath))

		# remove a full dir
		Cfruby::FileOps.mkdir(dirfilepath)
		assert(test(?d, dirfilepath))
		Cfruby::FileOps.touch(dirfilepath + "/inside")
		assert(File.exists?(dirfilepath + "/inside"))
		Cfruby::FileOps.rmdir(dirfilepath, :force => true)
		assert(!File.exists?(dirfilepath))

		# rmdir on a file
		notdirfile = Tempfile.new('fileops')
		assert(File.exists?(notdirfile.path))
		assert(!test(?d, notdirfile.path))
		assert_raise(Cfruby::FileOps::FileOpsWrongFiletypeError) {
			Cfruby::FileOps.rmdir(notdirfile.path)
		}
	end
	
	
	def test_link()
		linktofile = Tempfile.new('fileops')
		linkfile = Tempfile.new('fileops')
		linkfilepath = linkfile.path
		linkfile.close(true)

		begin
			# basic link
			assert(!File.exists?(linkfilepath))
			Cfruby::FileOps.link(linktofile.path, linkfilepath)
			assert(File.symlink?(linkfilepath))
			assert(Cfruby::FileOps::SymlinkHandler.points_to?(linkfilepath,linktofile.path))
		
			# re-link
			assert_nothing_raised() {
				Cfruby::FileOps.link(linktofile.path, linkfilepath)
			}
			assert(File.symlink?(linkfilepath))
		
			Cfruby::FileOps.unlink(linkfilepath)
			assert(!File.exists?(linkfilepath))
		
			File.open(linkfilepath, File::WRONLY | File::CREAT | File::TRUNC) { |fp|
				fp.puts("some content")
			}
			assert(File.exists?(linkfilepath))
			
			assert_raise(Cfruby::FileOps::FileOpsOverwriteError) {
				Cfruby::FileOps.link(linktofile.path, linkfilepath)				
			}
			assert_nothing_raised() {
				Cfruby::FileOps.link(linktofile.path, linkfilepath, :force => true)
			}
			assert(File.symlink?(linkfilepath))
		ensure
			Cfruby::FileOps.unlink(linkfilepath)
		end
	end
	
	
	def test_backup()
		Cfruby::FileOps.backup(@basefile.path)
		assert_equal(true, test(?f, "#{@basefile.path}_#{Time.now.strftime('%Y%m%d')}_0"), "Simple backup failed")
		Cfruby::FileOps.backup(@basefile.path)
		assert_equal(true, test(?f, "#{@basefile.path}_#{Time.now.strftime('%Y%m%d')}_1"), "Second backup failed")
		Cfruby::FileOps.backup(@basefile.path, :onlyonchange => true)
		assert_equal(false, test(?f, "#{@basefile.path}_#{Time.now.strftime('%Y%m%d')}_2"), "Unnecessary backup created")
		@deletefiles << "#{@basefile.path}_#{Time.now.strftime('%Y%m%d')}_0"
		@deletefiles << "#{@basefile.path}_#{Time.now.strftime('%Y%m%d')}_1"
	end
	
	
	def test_flock()
		newfile = Tempfile.new('fileop')
		newfilepath = newfile.path()
		@deletefiles << newfilepath
		newfile.close(true)
		
		assert_nothing_raised("Basic single lock without contest failed") {
			fp = Cfruby::FileOps.flock(newfilepath, 'w') { |fp|
				fp.print("some entry")
			}
		}
	end
	
	
	def test_local_dir_copy()
		copydir = Tempfile.new('fileop')
		copydirpath = copydir.path
		copydir.close(true)
		Cfruby::FileOps.mkdir(copydirpath)

		# use a tempfile to try to avoid collisions
		newfile = Tempfile.new('fileop')
		newfilepath = newfile.path()
		newfile.close(true)
				
		Cfruby::FileOps.copy(copydirpath, newfilepath)
		assert_equal(true, File.directory?(newfilepath))

		# cleanup
		Cfruby::FileOps.delete(copydirpath)
		Cfruby::FileOps.delete(newfilepath)
	end
	
	
	def test_local_copy()
		# use a tempfile to try to avoid collisions
		newfile = Tempfile.new('fileop')
		newfilepath = newfile.path()
		newfile.close(true)
		
		Cfruby::FileOps.copy(@basefile.path, newfilepath)
		assert_equal(true, test(?f, newfilepath), "Local copy failed")
		# test permissions when copied with euid=0
		if(Process.euid == 0)
			# Permissions should be root
			assert_equal(File.owned?(newfilepath),true)
			# Now try another user
			manager = Cfruby::OS::OSFactory.new().get_os().get_user_manager()
			manager.add_user('lijygrdwa') 
			newfile = Tempfile.new('fileop')
			newfilepath = newfile.path()
			newfile.close(true)
		
			Cfruby::FileOps.copy(@basefile.path, newfilepath, :user=>'lijygrdwa')
			# OK, this is ugly! But we need to make sure the ownership was
			# retained from the :user parameter (failing, as it is
			# root at this point)
			assert_equal(false,(`ls -l #{newfilepath}`=~/lijygrdwa/))
			assert_equal(true, test(?f, newfilepath), "Local copy failed")
			manager.delete_user('lijygrdwa')
		end
		
		# test that the copy doesn't happen again if :onlyonchange is passed
		modified = File.stat(newfilepath).mtime()
		sleep(1)
		Cfruby::FileOps.copy(@basefile.path, newfilepath, :onlyonchange => true)
		assert_equal(modified, File.stat(newfilepath).mtime(), "copy with :onlyonchange failed to skip")
	
		# test :force
		File.open(newfilepath, 'w') { |fp|
			fp.write("foo")
		}
		Cfruby::FileOps.copy(@basefile.path, newfilepath)
		originalsum = Cfruby::Checksum::Checksum.get_checksums(@basefile.path)
		newsum = Cfruby::Checksum::Checksum.get_checksums(newfilepath)
		assert_equal(originalsum.sha1, newsum.sha1, "copy with force failed")
		
		File.open(newfilepath, 'w') { |fp|
			fp.write("foo")
		}
		assert_raise(Cfruby::FileOps::FileOpsOverwriteError) {
			Cfruby::FileOps.copy(@basefile.path, newfilepath, :force => false)
		}
		originalsum = Cfruby::Checksum::Checksum.get_checksums(@basefile.path)
		newsum = Cfruby::Checksum::Checksum.get_checksums(newfilepath)
		assert_not_equal(originalsum.sha1, newsum.sha1, "copy with force => false failed")
		
		# test nonexistent copy file
		assert_raise(Cfruby::FileOps::FileOpsFileExistError) {
			Cfruby::FileOps.copy("/there/is/no/way/I/exist", newfilepath)
		}
		
		# test copy with :backup
		originalfile = Tempfile.new('fileops')
		copyfile = Tempfile.new('fileops')

		File.open(originalfile.path, File::WRONLY | File::TRUNC) { |fp|
			fp.puts("original stuff")
		}
		
		File.open(copyfile.path, File::WRONLY | File::TRUNC) { |fp|
			fp.puts("copy stuff")
		}
		
		# make a forced copy with a backup
		Cfruby::FileOps.copy(copyfile.path, originalfile.path, :backup => true)
		File.open(originalfile.path + "_#{Time.now.strftime('%Y%m%d')}_0", File::RDONLY) { |fp|
			lines = fp.readlines()
			assert_equal("original stuff\n", lines[0])
		}
		Cfruby::FileOps.delete(originalfile.path + "_#{Time.now.strftime('%Y%m%d')}_0")

		# test that copying as root retains root ownership by default (euid and
		# not real uid as it is given in a sudo environment)
		if(Process.euid == 0)
			testfilepath = 'fileops_copy_root'
			Cfruby::FileOps.copy(@basefile.path, testfilepath)
			# test for ownership equals euid
			assert_equal(File.owned?(testfilepath),true)
			Cfruby::FileOps.delete(testfilepath)
		end
		Cfruby::FileOps.delete(newfilepath)
	end
	
	
	def test_touch()
		touchfile = Tempfile.new('fileops')
		touchfilepath = touchfile.path
		touchfile.close(true)
		
		# touch an empty file
		assert(!File.exists?(touchfilepath))
		Cfruby::FileOps.touch(touchfilepath)
		assert(File.exists?(touchfilepath))

		# retouch it and check that nothing is raised and that the file isn't touched
		File.open(touchfilepath, File::WRONLY) { |fp|
			fp.puts("this is my content")
		}
		checksums = Cfruby::Checksum::Checksum.get_checksums(touchfilepath)
		Cfruby::FileOps.touch(touchfilepath)
		assert_equal(checksums, Cfruby::Checksum::Checksum.get_checksums(touchfilepath))

		Cfruby::FileOps.delete(touchfilepath)
		assert(!File.exists?(touchfilepath))
	end
	
	
	def test_delete()
		deleteme = Tempfile.new('fileops')
		deleteme.close(false)
		
		assert(File.exists?(deleteme.path))
		Cfruby::FileOps.delete(deleteme.path)
		assert(!File.exists?(deleteme.path))
		
		deleteme = Tempfile.new('fileops')
		deleteme.close(false)

		assert(File.exists?(deleteme.path))
		Cfruby::FileOps.unlink(deleteme.path)
		assert(!File.exists?(deleteme.path))
	end
	
	
	def test_local_move()
		# use a tempfile to try to avoid collisions
		newfile = Tempfile.new('fileop')
		newfilepath = newfile.path()
		@deletefiles << newfilepath
		newfile.close(true)
		
		Cfruby::FileOps.move(@basefile.path, newfilepath)
		assert_equal(true, test(?f, newfilepath), "Local move failed")
		assert_equal(false, test(?f, @basefile.path), "Local move failed")

		# test move with mode
		modefile = Tempfile.new('fileops')
		FileUtils.chmod(0777, modefile.path)
		goodmode = File.stat(modefile.path).mode()
		FileUtils.chmod(0700, modefile.path)
		oldmode = File.stat(modefile.path).mode()
		newmodefile = Tempfile.new('fileops')
		newmodefilepath = newmodefile.path
		@deletefiles << newmodefilepath
		newmodefile.close(true)
		Cfruby::FileOps.move(modefile.path, newmodefilepath, :mode => '0777')
		assert_equal(goodmode, File.stat(newmodefilepath).mode)
		
		# test move without force
		mvfile = Tempfile.new('fileop')
		mvfilepath = mvfile.path()
		mvfile.close(false)
		
		File.open(mvfilepath, File::WRONLY | File::TRUNC) { |fp|
			fp.puts("mvfile content")
		}
		File.open(newfilepath, File::WRONLY | File::TRUNC) { |fp|
			fp.puts("newfile content")
		}
		assert_raise(Cfruby::FileOps::FileOpsOverwriteError) {
			Cfruby::FileOps.move(mvfilepath, newfilepath, :force => false)
		}
		File.open(newfilepath, File::RDONLY) { |fp|
			content = fp.readlines()
			assert_equal("newfile content\n", content[0])
		}
	end

end
