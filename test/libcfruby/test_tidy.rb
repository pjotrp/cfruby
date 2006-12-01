#!/usr/bin/env ruby
# Unit Tests for filops module - tidy functions

$: << File.dirname(__FILE__) + '/../../lib'

require 'test/unit'
require 'find'
require 'tempfile'
require 'fileutils'
require 'libcfruby/fileops'


# Tests the FileEdit module methods
class TC_Tidy < Test::Unit::TestCase

	def setup()
		realumask = File.umask()
		
		begin
			FileUtils.chdir('/')
			File.umask(0022)
		
			# build a temporary directory structure to test on
			@basedir = Tempfile.new('testroot')
			@basedirpath = @basedir.path()
			@basedir.close(true)
			@basedir = @basedirpath
			FileUtils.mkdir(@basedir)
			files = Array.[]("snee.txt", "bubba", "README", "I have spaces.mpg")
			innerdirs = Array.[]("1", "2", "3", "foo", "bar", "baz")
			innerdirs.each() { |dirname|
				FileUtils.mkdir("#{@basedir}/#{dirname}")
				files.each() { |filename|
					File.open("#{@basedir}/#{dirname}/#{filename}", File::CREAT|File::WRONLY) { |fp|
						fp.print("I am some content\n")
					}
				}
				innerdirs.each() { |innerdirname|
					FileUtils.mkdir("#{@basedir}/#{dirname}/#{innerdirname}")
					files.each() { |filename|
						File.open("#{@basedir}/#{dirname}/#{innerdirname}/#{filename}", File::CREAT|File::WRONLY) { |fp|
							fp.print("I am some content\n")
						}
					}
				}
			}
		ensure
			File.umask(realumask)
		end
	end
	
	
	def teardown()
		FileUtils.rm_rf(@basedir)
	end
	
	
	def get_find_count(options = {})
		count = 0
		options[:recursive] = true
		Cfruby::FileFind.find(@basedir, options) { |filename|
			count = count + 1
		}
		
		return(count)
	end
	
	
	# test deleting files
	def test_delete()
		Cfruby::FileOps.delete(@basedir, :glob => "README", :recursive => true)
		count = get_find_count()
		assert_equal(211-(6+6*6), count, "#{count} files remaining after delete, expected #{211-7}")
	end

	# test deleting symlinks
	def test_delete_symlink
		# try deleting a symlink not pointing anywhere
		dir = @basedir + '/symlinks'
		fn  = dir + '/testfn'
		sl  = dir + '/testfn_symlink'
		Cfruby::FileOps.mkdir dir
		Cfruby::FileOps.touch fn
		assert(File.exist?(fn))
		Cfruby::FileOps.link(fn,sl, :force=>true)
		assert(File.symlink?(sl))
		Cfruby::FileOps.delete(fn)
		Cfruby::FileOps.delete(sl)  # delete non pointing symlink
		assert(!File.symlink?(sl))
		# repeat forcing a stat on a non-existing file
		Cfruby::FileOps.touch fn
		assert(File.exist?(fn))
		Cfruby::FileOps.link(fn,sl, :force=>true)
		Cfruby::FileOps.delete(fn)
		Cfruby::FileOps.delete(dir, :recursive=>true)
		assert(!File.symlink?(sl))
		# repeat forcing a stat on a non-existing file (using :olderthan)
		Cfruby::FileOps.mkdir dir
		Cfruby::FileOps.touch fn
		assert(File.exist?(fn))
		Cfruby::FileOps.link(fn,sl, :force=>true)
		Cfruby::FileOps.delete(fn)
		Cfruby::FileOps.delete(dir, :recursive=>true, :olderthan=>Time.now)
		assert(!File.exist?(sl))
	end
	
	# test deleting files older than a certain time
	def test_delete_old()
		Cfruby::FileOps.delete(@basedir, :glob => "README", :olderthan => Time.now-20, :recursive => true)
		count = get_find_count()
		assert_equal(211, count, "#{count} files remaining after delete, expected #{211}")
		sleep(15)
		Cfruby::FileOps.delete(@basedir, :glob => "README", :olderthan => Time.now-10, :recursive => true)
		count = get_find_count()
		assert_equal(211-(6+6*6), count, "#{count} files remaining after delete, expected #{211-(6+6*6)}")		
	end


	# test deleting files smaller than a certain size
	def test_delete_small()
		Cfruby::FileOps.delete(@basedir, :glob => "README", :smallerthan => 100, :recursive => true)
		count = get_find_count()
		assert_equal(211-(6+6*6), count, "#{count} files remaining after delete, expected #{211-(6+6*6)}")		
	end


	# test deleting files larger than a certain size
	def test_delete_large()
		Cfruby::FileOps.delete(@basedir, :glob => "README", :largerthan => 100, :recursive => true)
		count = get_find_count()
		assert_equal(211, count, "#{count} files remaining after delete, expected 211")		
	end
	
	
	# test deleting directories
	def test_delete_dir()
		Cfruby::FileOps.delete(@basedir, :force => true, :directoriesonly => true, :glob => "[0-9]", :recursive => true)
		count = get_find_count()
		assert_equal(1+3+(3*4)+(3*3)+(9*4), count, "#{count} files remaining after delete '[0-9]', expected #{1+3+(3*4)+(3*3)+(9*4)}")
	end
	
	# Test deleting of files inside a tree
	def test_delete_dir_noforce
		dir1 = @basedir + '/dir1'
		dir1_1 = dir1+'/dir1'
		dir1_2 = dir1+'/dir2'
		fn1    = dir1_1 + '/testfn1'
		fn2    = dir1_2 + '/testfn2'
		Cfruby::FileOps.mkdir dir1_1, {:makeparent=>true}
		Cfruby::FileOps.mkdir dir1_2
		Cfruby::FileOps.touch fn1
		Cfruby::FileOps.touch fn2
		assert(File.exist?(fn2))
		
		# this should remove fn2 and dir1_2
		Cfruby::FileOps.delete(dir1_2, :recursive => true)
		assert_equal(false, File.exist?(fn2))
		assert_equal(false, File.exist?(dir1_2))
		# this should remove fn1 and leave dir1_1?
		Cfruby::FileOps.delete(dir1, :recursive => true, :filesonly => true)
		assert_equal(false, File.exist?(fn1))
		assert_equal(true, File.exist?(dir1_1))
		# test with depth - should not remove fn1
		Cfruby::FileOps.touch fn1
		Cfruby::FileOps.delete(dir1, :depth => 1, :filesonly => true)
		assert_equal(true, File.exist?(fn1), "#{fn1} doesn't exist after recursive depth limited delete")
	end
	
	# test changing owner and mode - this is a weak test because only root can really change a file owner, so we are really
	# testing to make sure errors aren't raised
	def test_chown_mod()
		Cfruby::FileOps.chown_mod(@basedir, Process::Sys.geteuid, File.stat(@basedir).gid, 0400, :glob => 'README', :recursive => true)
		Find.find(@basedir) { |filename|
			filename = Pathname.new(filename)
			if(File.fnmatch('README', filename.basename))
				assert_equal(File.stat(filename).gid, File.stat(@basedir).gid, "\"#{filename}\" expected to be owned by group #{Process::Sys.getegid}, but was actually owned by #{File.stat(filename).gid}")
				assert_equal(true, filename.owned?(), "\"#{filename}\" expected to be owned by #{Process::Sys.geteuid}, but was actually owned by #{File.stat(filename).uid}")
			end
		}
	end


	# test disabling a file
	def test_disable()
		Cfruby::FileOps.disable(@basedir, :glob => '*.txt', :recursive => true)
		Find.find(@basedir) { |filename|
			filename = Pathname.new(filename)
			if(File.fnmatch('*.txt', filename.basename))
				# this return could change on different platforms since the mode return
				# if platform dependant.  On OS X it returns -1, which translates to 32768
				# if a file has permissions of 0000
				assert_equal(32768, File.stat(filename).mode)
			end
		}
	end
	

	# test chown - this is a weak test because only root can really change a file owner, so we are really
	# testing to make sure errors aren't raised
	def test_chown()
		Cfruby::FileOps.chown(@basedir, Process::Sys.geteuid, Process::Sys.getegid, :glob => 'I*', :filesonly => true, :recursive => true)
		Find.find(@basedir) { |filename|
			filename = Pathname.new(filename)
			if(File.fnmatch('I*', filename.basename))
				assert_equal(true, filename.grpowned?())
				assert_equal(true, filename.owned?())
			end
		}
	end
	
	
	# returns all permutations over arr of length
	def combine(arr, length)
		arr.each_index() { |i|
			if(length == 1)
				yield(Array.[](arr[i]))
			else
				combine(arr.slice(i+1..-1), length-1) { |newarr|
					yield(Array.[](arr[i]) + newarr)
				}
			end
		}
	end
	
	
	# helper function, returns all possible groups of items in an array
	def group(arr)
		1.upto(arr.length) { |grouplength|
			combine(arr, grouplength) { |group|
				yield(group.join(''))
			}
		}
	end
	
	
	# test breakout - make sure a tidy call doesn't travel up past the basedir - based on a bug
	# filed by Kelley Reynolds 2005-07-22
	def test_breakout
		Cfruby::FileOps.chmod("#{@basedir}/1", 'go-wrx,u+wrx')
		fullperms = File.stat("#{@basedir}/1").mode
		assert_not_equal(fullperms, File.stat(@basedir).mode, "Directory traversal escaped up one level")
	end
	
	
	# test chmod
	def test_chmod()
		assert_nothing_raised() {
			Cfruby::FileOps.chmod(@basedir, 0700, :recursive => true)
		}
		
		# Fail when file does not exist
		assert_raises(Cfruby::FileFind::FileExistError) {
		  Cfruby::FileOps.chmod(@basedir+'/not_there', 0700)
	  }
		
		# now test a series against the system chmod command
		prefixes = ['u', 'g', 'o']
		operators = ['-', '+', '=']
		permissions = ['r', 'w', 'x', 'X']
		
		tempfile = Tempfile.new('chmodcheck')
		tempfile.close(false)
		mode = "u=rw,go-rwx"

		FileUtils.chdir('/')
		`chmod 0000 '#{tempfile.path.gsub(/'/, "\\\&")}'`
		`chmod #{mode} '#{tempfile.path.gsub(/'/, "\\\&")}'`
		realchmodperms = File.stat(tempfile.path).mode
		`chmod 0000 '#{tempfile.path.gsub(/'/, "\\\&")}'`
		Cfruby::FileOps.chmod(tempfile.path, mode)
		tidychmodperms = File.stat(tempfile.path).mode

		assert_equal(tidychmodperms, realchmodperms, "expected #{realchmodperms.to_s(8)} after Cfruby::FileOps.chmod(\"#{mode}\"), but got #{tidychmodperms.to_s(8)}")
	end
	
end
