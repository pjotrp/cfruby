#!/usr/bin/env ruby
# Unit Tests for filedit module

$: << File.dirname(__FILE__) + '/../../lib'

require 'test/unit'
require 'find'
require 'tempfile'
require 'fileutils'
require 'libcfruby/filefind'

# Tests the FileEdit module methods
class TC_FileFind < Test::Unit::TestCase

	def setup()
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
	end
	
	
	def teardown()
		FileUtils.rm_rf(@basedir)
	end
	
	
	def get_find_count(options = {:recursive => true})
		count = 0
		Cfruby::FileFind.find(@basedir, options) { |filename|
			count = count + 1
		}
		
		return(count)
	end
	
	
	# tests finding with a depth of 0 and 1
	def test_find_single()
		count = get_find_count(:nonrecursive => true)
		assert_equal(1, count, "non recursive find found #{count} files")
		
		count = get_find_count(:depth => 1)
		assert_equal(7, count, "recursion depth of 1 found #{count} files")
	end
	
	
	# tests find count of '*'
	def test_find()
		count = get_find_count()
		assert_equal(211, count, "find found #{count} files - expected 211")
	end
	
	
	# tests glob expansion in the basedir
	def test_basedir_glob()
		count = 0
		Cfruby::FileFind.find("#{@basedir}/*") { |filename|
			count = count + 1
		}
		assert_equal(6, count, "find of \"#{@basedir}/*\" failed")
	end
	
	
	# tests find count of directories
	def test_find_dirs()
		count = get_find_count(:directoriesonly => true, :recursive => true)
		assert_equal(43, count, "find found #{count} directories - expected 43")
	end
	
	
	# tests the empty option
	def test_empty()
		emptyfile = Tempfile.new('filefind')
		count = Cfruby::FileFind.find(emptyfile.path, :empty => true) {}
		assert_equal(1, count, ":empty did not find an empty file")
		File.open(emptyfile.path, File::WRONLY) { |fp|
			fp.write("some content")
		}
		count = Cfruby::FileFind.find(emptyfile.path, :empty => true) {}
		assert_equal(0, count, ":empty found a non-empty file")
		path = emptyfile.path()
		emptyfile.close(true)
		
		FileUtils.mkdir(path)
		count = Cfruby::FileFind.find(path, :empty => true) {}
		assert_equal(1, count, ":empty did not find an empty directory")
		FileUtils.touch("#{path}/foo")
		count = Cfruby::FileFind.find(path, :empty => true) {}
		assert_equal(0, count, ":empty found a non-empty directory")
		FileUtils.rm_rf(path)
		
		linkedfile = Tempfile.new('filefind')
		link = Tempfile.new('filefind')
		linkpath = link.path
		link.close(true)
		FileUtils.ln_s(linkedfile.path, linkpath)
		count = Cfruby::FileFind.find(linkpath, :empty => true) {}
		assert_equal(0, count, ":empty found a non-empty symlink")
		linkedfile.close(true)
		count = Cfruby::FileFind.find(linkpath, :empty => true) {}
		assert_equal(1, count, ":empty failed to find an empty symlink")
		FileUtils.rm_f(linkpath)
	end
	

	# tests finding broken links
	def test_broken_links()
		linkedfile = Tempfile.new('filefind')
		link = Tempfile.new('filefind')
		linkpath = link.path
		link.close(true)
		FileUtils.ln_s(linkedfile.path, linkpath)
		count = Cfruby::FileFind.find(linkpath, :brokenlink => true) {}
		assert_equal(0, count, ":brokenlink found a working symlink")
		linkedfile.close(true)
		FileUtils.rm_f(linkedfile.path)
		count = Cfruby::FileFind.find(linkpath, :brokenlink => true) {}
		assert_equal(1, count, ":brokenlink failed to find an broken symlink")
		FileUtils.rm_f(linkpath)
	end
	
	# tests find count of files
	def test_find_files()
		count = get_find_count(:filesonly => true, :recursive => true)
		assert_equal(211-43, count, "find found #{count} files - expected #{211-43}")
	end
	
	
	# tests find glob
	def test_find_glob()
		count = get_find_count(:glob => '*.txt', :recursive => true)
		assert_equal(42, count, "find found #{count} *.txt files - expected 42")
	end
	
	
	# test find with exclusion
	def test_find_exclude()
		count = get_find_count(:exclude => '*.txt', :recursive => true)
		assert_equal(211-42, count, "find found #{count} non *.txt files - expected #{211-42}")
	end
	
	
	# tests find with exclusion and inclusion
	def test_find_include()
		count = get_find_count(:exclude => '*', :include => '*.txt', :recursive => true)
		assert_equal(42, count, "find found #{count} *.txt files - expected 42")
	end
	
	
	# test find with arrays
	def test_find_array()
		count = 0
		files = Array.[]("#{@basedir}/1/snee.txt", "#{@basedir}/2/README")
		Cfruby::FileFind.find(files, :recursive => true) { |filename|
			count = count + 1
		}
		assert_equal(2, count, "find with an array found #{count} files, expected 2")
	end
	
end
