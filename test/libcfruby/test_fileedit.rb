#!/usr/bin/env ruby
# Unit Tests for filedit module

$: << File.dirname(__FILE__) + '/../../lib'

require 'test/unit'
require 'tempfile'
require 'libcfruby/fileedit'

# Tests the Cfruby::FileEdit module methods
class TC_FileEdit < Test::Unit::TestCase

	def setup()
		# disable file backups - we aren't testing that here
		Cfruby::FileOps.set_backup(false)

		@multilinefilecontents = <<FILEBLOCK
first line
second line
third line
last line
FILEBLOCK
		@multilinefile = Tempfile.new('test')
		@multilinefile.write(@multilinefilecontents)
		@multilinefile.close(false)
		@multilinefilename = @multilinefile.path()
		
		@emptyfile = Tempfile.new('test')
		@emptyfile.close(false)
		@emptyfilename = @emptyfile.path()		
	end
	
	
	def teardown()
		@multilinefile.close(true)
		@emptyfile.close(true)
		Cfruby::FileOps.set_backup(true)	
	end
	
	
	# test file_must_contain when the file already contains the line
	def test_file_must_contain_contains()
		Cfruby::FileEdit.file_must_contain(@multilinefilename, "second line")
		File.open(@multilinefilename, File::RDONLY) { |fp|
			lines = fp.readlines()
			assert_equal(@multilinefilecontents.split("\n").length, lines.length)
		}
	end


	# test file_must_contain when passed an Array and a block
	def test_file_must_contain_multiline()
		arrayblock = Array.new()
		arrayblock << "foo\n"
		arrayblock << "bar\n"
		arrayblock << "baz\n"
		Cfruby::FileEdit.file_must_contain(@multilinefilename, arrayblock)
		File.open(@multilinefilename, File::RDONLY) { |fp|
			lines = fp.readlines()
			arrayblock.each() { |line|
				assert(lines.include?(line))
			}
		}
		
		# and for the same type of thing, but for an entire block
		# first, potentially split
		block = <<BLOCK
this
is
my block
BLOCK
		Cfruby::FileEdit.file_must_contain(@multilinefilename, block, :block => false)
		File.open(@multilinefilename, File::RDONLY) { |fp|
			lines = fp.readlines()
			block.each_line() { |line|
				assert(lines.include?(line))
			}
		}
		
		# and a fullblock
		block = <<BLOCK
this
1
2
3
4
BLOCK
		# first time should *not* add it
		Cfruby::FileEdit.file_must_contain(@multilinefilename, block, :block => true)
		File.open(@multilinefilename, File::RDONLY) { |fp|
			lines = fp.readlines()
			block.each() { |line|
				if(line == "this\n")
					assert(lines.include?(line))
					next
				end
				assert(!lines.include?(line))
			}
		}
		
		# now we should (pass in another regex for matching)
		Cfruby::FileEdit.file_must_contain(@multilinefilename, block, :block => true, :regex => /not in this file/)
		File.open(@multilinefilename, File::RDONLY) { |fp|
			lines = fp.readlines()
			block.each() { |line|
				assert(lines.include?(line))
			}
			thiscount = 0
			lines.each() { |line|
				if(line == "this\n")
					thiscount = thiscount + 1
				end
			}
			assert(thiscount == 2)
		}
	end
	
	
	# test file_must_contain anchor
	def test_file_must_contain_anchor()
		# anchor with a regex
		Cfruby::FileEdit.file_must_contain(@multilinefilename, "newline #1", :anchor => /third/)
		File.open(@multilinefilename, File::RDONLY) { |fp|
			lines = fp.readlines()
			assert(lines[2] =~ /third/)
			assert(lines[3] == "newline #1\n")
		}
		
		# test a regex anchor that isn't there
		assert_raise(Cfruby::FileEdit::AnchorNotFoundError) {
			Cfruby::FileEdit.file_must_contain(@multilinefilename, "foonards", :anchor => /bobs your uncle/)			
		}

		# anchor with a line number
		Cfruby::FileEdit.file_must_contain(@multilinefilename, "newline #2", :anchor => 0)
		File.open(@multilinefilename, File::RDONLY) { |fp|
			lines = fp.readlines()
			assert(lines[0] =~ /first/)
			assert(lines[1] == "newline #2\n")
		}

		# test impossible integer anchors
		assert_raise(Cfruby::FileEdit::AnchorNotFoundError) {
			Cfruby::FileEdit.file_must_contain(@multilinefilename, "foonards", :anchor => 9000)
		}

		assert_raise(Cfruby::FileEdit::AnchorNotFoundError) {
			Cfruby::FileEdit.file_must_contain(@multilinefilename, "foonards", :anchor => -20)
		}
	end
	
	
	# test comment/uncomment
	def test_comment()
		Cfruby::FileEdit.comment(@multilinefilename, /last line/)
		File.open(@multilinefilename, File::RDONLY) { |fp|
			lines = fp.readlines()
			assert(lines.include?("# last line\n"), "comment failed to comment the line")
		}

		Cfruby::FileEdit.comment(@multilinefilename, /third line/, :commentwith => "$$")
		File.open(@multilinefilename, File::RDONLY) { |fp|
			lines = fp.readlines()
			assert(lines.include?("$$ third line\n"), "comment failed to comment the line")
		}

		Cfruby::FileEdit.uncomment(@multilinefilename, /last line/)
		File.open(@multilinefilename, File::RDONLY) { |fp|
			lines = fp.readlines()
			assert(lines.include?("last line\n"), "comment failed to uncomment the line")
		}

		Cfruby::FileEdit.uncomment(@multilinefilename, /third line/, :commentwith => "$$")
		File.open(@multilinefilename, File::RDONLY) { |fp|
			lines = fp.readlines()
			assert(lines.include?("third line\n"), "comment failed to uncomment the line")
		}
	end
	
	
	# test file_must_contain when the file doesn't contain the line
	def test_file_must_contain_new()
		Cfruby::FileEdit.file_must_contain(@multilinefilename, "new line")
		File.open(@multilinefilename, File::RDONLY) { |fp|
			lines = fp.readlines()
			assert_equal(true, lines.include?("new line\n"))
		}
	end
	
	
	# test file_must_contain positioning - append
	def test_file_must_contain_append()
		Cfruby::FileEdit.file_must_contain(@multilinefilename, "new line", :position => Cfruby::FileEdit::APPEND)
		File.open(@multilinefilename, File::RDONLY) { |fp|
			lines = fp.readlines()
			assert_equal("new line\n", lines[-1])
		}
	end


	# test file_must_contain with fuzzymatch
	def test_file_must_contain_fuzzy()
		Cfruby::FileEdit.file_must_contain(@multilinefilename, "\tnew  line", :position => Cfruby::FileEdit::APPEND)
		File.open(@multilinefilename, File::RDONLY) { |fp|
			lines = fp.readlines()
			assert_equal("\tnew  line\n", lines[-1])
		}

		added = Cfruby::FileEdit.file_must_contain(@multilinefilename, "new line", :fuzzymatch => true, :position => Cfruby::FileEdit::APPEND)
		assert_equal(false, added, "file_must_contain added the fuzzy match when it shouldn't have")

		added = Cfruby::FileEdit.file_must_contain(@multilinefilename, "new line", :fuzzymatch => false, :position => Cfruby::FileEdit::APPEND)
		assert_equal(true, added, "file_must_contain didn't add the strict match when it should have")
		
		# test regexp escaping with fuzzymatch
		assert_nothing_raised() {
			Cfruby::FileEdit.file_must_contain(@multilinefilename, '0 0 * * 5 /usr/local/sbin/pkg_version -v -L =', :fuzzymatch=>true)
		}
		
		@resolvfile = Tempfile.new('test')
		@resolvefilecontents = <<FILEBLOCK
# our servers
nameserver      69.9.164.130
nameserver      69.9.164.131
FILEBLOCK
		@resolvfile.write(@multilinefilecontents)
		@resolvfile.close(false)

		Cfruby::FileEdit.file_must_contain(@resolvfile.path, 'domain titanresearch.com', :fuzzymatch=>true)
		Cfruby::FileEdit.file_must_contain(@resolvfile.path, 'nameserver 69.9.164.130', :fuzzymatch=>true)
		Cfruby::FileEdit.file_must_contain(@resolvfile.path, 'nameserver 69.9.164.131', :fuzzymatch=>true)
		Cfruby::FileEdit.file_must_contain(@resolvfile.path, 'nameserver 66.180.175.18', :fuzzymatch=>true)
		Cfruby::FileEdit.file_must_contain(@resolvfile.path, 'nameserver 69.9.191.4', :fuzzymatch=>true)
		Cfruby::FileEdit.file_must_contain(@resolvfile.path, 'nameserver 69.9.160.191', :fuzzymatch=>true)
		
		assert_equal(true, Cfruby::FileEdit.contains?(@resolvfile.path, 'domain titanresearch.com'))
		assert_equal(true, Cfruby::FileEdit.contains?(@resolvfile.path, 'nameserver 69.9.164.130'))
		assert_equal(true, Cfruby::FileEdit.contains?(@resolvfile.path, 'nameserver 69.9.164.131'))
		assert_equal(true, Cfruby::FileEdit.contains?(@resolvfile.path, 'nameserver 66.180.175.18'))
		assert_equal(true, Cfruby::FileEdit.contains?(@resolvfile.path, 'nameserver 69.9.191.4'))
		assert_equal(true, Cfruby::FileEdit.contains?(@resolvfile.path, 'nameserver 69.9.160.191'))
	end
	
	
	# test file_must_contain positioning - prepend
	def test_file_must_contain_prepend()
		Cfruby::FileEdit.file_must_contain(@multilinefilename, "new line", :position => Cfruby::FileEdit::PREPEND)
		File.open(@multilinefilename, File::RDONLY) { |fp|
			lines = fp.readlines()
			assert_equal("new line\n", lines[0])
		}
		
		Cfruby::FileEdit.file_must_contain(@multilinefilename, "anchor line", :position => Cfruby::FileEdit::PREPEND, :anchor => /third/)
		File.open(@multilinefilename, File::RDONLY) { |fp|
			lines = fp.readlines()
			assert_equal("anchor line\n", lines[3])
			assert(lines[4] =~ /third/)
		}		
	end


	# test file_must_contain positioning - insert
	def test_file_must_contain_insert()
		Cfruby::FileEdit.file_must_contain(@multilinefilename, "new line", :position => Cfruby::FileEdit::PREPEND, :anchor => 3)
		File.open(@multilinefilename, File::RDONLY) { |fp|
			lines = fp.readlines()
			assert_equal("new line\n", lines[3])
		}
	end

	
	# test file_must_contain when the file doesn't contain the line - empty file
	def test_file_must_contain_new_empty()
		Cfruby::FileEdit.file_must_contain(@emptyfilename, "new line")
		File.open(@emptyfilename, File::RDONLY) { |fp|
			lines = fp.readlines()
			assert_equal(true, lines.include?("new line\n"))
		}
	end
	
	
	# test file_must_contain positioning - append - empty file
	def test_file_must_contain_append_empty()
		Cfruby::FileEdit.file_must_contain(@emptyfilename, "new line", :position => Cfruby::FileEdit::APPEND)
		File.open(@emptyfilename, File::RDONLY) { |fp|
			lines = fp.readlines()
			assert_equal("new line\n", lines[-1])
		}
	end

	
	# test file_must_contain positioning - prepend - empty file
	def test_file_must_contain_prepend_empty()
		Cfruby::FileEdit.file_must_contain(@emptyfilename, "new line", :position => Cfruby::FileEdit::PREPEND)
		File.open(@emptyfilename, File::RDONLY) { |fp|
			lines = fp.readlines()
			assert_equal("new line\n", lines[0])
		}
	end


	# test file_must_contain positioning - insert - empty file
	def test_file_must_contain_insert_empty()
		Cfruby::FileEdit.file_must_contain(@emptyfilename, "new line")
		File.open(@emptyfilename, File::RDONLY) { |fp|
			lines = fp.readlines()
			assert_equal("new line\n", lines[0])
		}
	end
	
	
	# tests contains?
	def test_contains?()
		assert_equal(Cfruby::FileEdit.contains?(@multilinefilename, "third"), true, "contains? returns false for comtains? 'third'")
		assert_equal(Cfruby::FileEdit.contains?(@multilinefilename, /second/), true, "contains? returns false for comtains? /second/")
		assert_equal(Cfruby::FileEdit.contains?(@multilinefilename, "bobby"), false, "contains? returns true for comtains? 'bobby'")
		assert_equal(Cfruby::FileEdit.contains?(@multilinefilename, /[0-9]/), false, "contains? returns true for comtains? /[0-9]/")
	end

	
	# test set_contents
	def test_set_contents()
		remove = Array.new()
		remove << "first line\n"
		remove << "second line\n"
		add = Array.new()
		add << "new third line\n"
		add << "new second line\n"
		add << "new first line\n"
		Cfruby::FileEdit.set_contents(@multilinefilename, remove, add)
		File.open(@multilinefilename, File::RDONLY) { |fp|
			lines = fp.readlines()
			assert_equal(@multilinefilecontents.split("\n").length+1, lines.length)
			add.each() { |line|
				assert(lines.include?(line))
			}
			remove.each() { |line|
				assert(!lines.include?(line))
			}
		}
	end
	
	
	# test file_must_contain and file_must_not_contain without fuzzy matching
	def test_file_must_nofuzzy()
		Cfruby::FileEdit.file_must_contain(@multilinefilename, "  first line", :fuzzymatch => false)
		File.open(@multilinefilename, File::RDONLY) { |fp|
			lines = fp.readlines()
			assert(lines.length == @multilinefilecontents.split("\n").length + 1)
			firstcount = 0
			lines.each() { |line|
				if(line =~ /first/)
					firstcount = firstcount + 1
				end
			}
			assert_equal(2, firstcount)
		}
		
		Cfruby::FileEdit.file_must_not_contain(@multilinefilename, "  first line", :fuzzymatch => false)
		File.open(@multilinefilename, File::RDONLY) { |fp|
			lines = fp.readlines()
			assert(lines.length == @multilinefilecontents.split("\n").length)
			firstcount = 0
			lines.each() { |line|
				if(line =~ /first/)
					firstcount = firstcount + 1
				end
			}
			assert_equal(1, firstcount)
		}
	end
	
	
	# file must not contain an Array
	def test_file_must_not_contain_array()
		mustnotcontain = Array.new()
		mustnotcontain << @multilinefilecontents.split("\n")[1]
		mustnotcontain << @multilinefilecontents.split("\n")[2]

		Cfruby::FileEdit.file_must_not_contain(@multilinefilename, mustnotcontain)
		File.open(@multilinefilename, File::RDONLY) { |fp|
			lines = fp.readlines()
			assert_equal(@multilinefilecontents.split("\n").length-2, lines.length)
			mustnotcontain.each() { |line|
				assert_equal(false, lines.include?(line))
			}
		}		
	end
	
	
	# file must not contain a line it doesn't have - str and regex
	def test_file_must_not_contain_not_found()
		Cfruby::FileEdit.file_must_not_contain(@multilinefilename, "new line")
		File.open(@multilinefilename, File::RDONLY) { |fp|
			lines = fp.readlines()
			assert_equal(@multilinefilecontents.split("\n").length, lines.length)
			assert_equal(false, lines.include?("new line\n"))
		}
		
		Cfruby::FileEdit.file_must_not_contain(@multilinefilename, /johnny/)
		File.open(@multilinefilename, File::RDONLY) { |fp|
			lines = fp.readlines()
			assert_equal(@multilinefilecontents.split("\n").length, lines.length)
		}
	end
	
	
	# file must not contain a line it does have - str and regex
	def test_file_must_not_contain_found()
		Cfruby::FileEdit.file_must_not_contain(@multilinefilename, "second line")
		File.open(@multilinefilename, File::RDONLY) { |fp|
			lines = fp.readlines()
			assert_equal(false, lines.include?("second line\n"))
		}
		
		Cfruby::FileEdit.file_must_not_contain(@multilinefilename, /last/)
		File.open(@multilinefilename, File::RDONLY) { |fp|
			lines = fp.readlines()
			assert_equal(false, lines.include?("last line\n"))
		}
	end
	
	
	# test appending a line
	def test_file_append()
		# test the empty file
		Cfruby::FileEdit.file_append(@emptyfilename, "new line")
		lines = File.open(@emptyfilename, File::RDONLY).readlines()
		assert_equal(1, lines.length)
		assert_equal("new line", lines[-1])
		
		# test the multiline file
		Cfruby::FileEdit.file_append(@multilinefilename, "new line")
		lines = File.open(@multilinefilename, File::RDONLY).readlines()
		assert_equal(@multilinefilecontents.split("\n").length+1, lines.length)
		assert_equal("new line", lines[-1])		
	end

	# test prepending a line
	def test_file_prepend()
		# test the empty file
		Cfruby::FileEdit.file_prepend(@emptyfilename, "new line")
		lines = File.open(@emptyfilename, File::RDONLY).readlines()
		assert_equal(1, lines.length)
		assert_equal("new line\n", lines[0])
		
		# test the multiline file
		Cfruby::FileEdit.file_prepend(@multilinefilename, "new line")
		lines = File.open(@multilinefilename, File::RDONLY).readlines()
		assert_equal(@multilinefilecontents.split("\n").length+1, lines.length)
		assert_equal("new line\n", lines[0])		
	end

end
