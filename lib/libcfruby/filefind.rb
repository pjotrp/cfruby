# A powerful set of filesystem traversal classes based on the find utility
#
# Author:: David Powers
# Copyright:: January, 2005
# License:: Ruby License

require 'libcfruby/cfruby'
require 'libcfruby/fileops'
require 'time'
require 'pathname'


module Cfruby

	module FileFind
		
		class FileFindError < Cfruby::CfrubyError
		end
		
		class FileExistError < FileFindError
		end
		

		# The FileMatch class implements a matches? method which is called on each file in turn
		# during a directory traversal. The class encapsulates the logic necessary to determine
		# which files should be included in Find output and which should not.
		class FileMatch
			
			# Options:
			# <tt>:glob</tt>:: can be a standard file glob (*.txt) or a regular expression or an array of either
			# <tt>:directoriesonly</tt>:: set to true will cause only directories to be matched
			# <tt>:filesonly</tt>:: set to true will cause only files to be matched
			# <tt>:exclude</tt>:: exclude any files matching the given pattern or patterns (may be standard file globs or regular expressions)
			# <tt>:include</tt>:: overrides excluded files selectively
			# <tt>:newerthan</tt>:: only files younger than this
			# <tt>:olderthan</tt>:: only files older than this
			# <tt>:empty</tt>:: true if the file is 0 length or the directory is empty or a symlink is broken
			# <tt>:brokenlink</tt>:: true if a symlink is broken
			# <tt>:largerthan</tt>:: only files larger than this (bytes, or /([0-9]+)(kmg)b?/)
			# <tt>:smallerthan</tt>:: only files smaller than this (bytes, or /([0-9]+)(kmg)b?/)
			def initialize(options = {})
				@globs = Array.new()
				@regex = Array.new()
				if(options[:glob])
					if(options[:glob].kind_of?(String))
						Cfruby.controller.inform('debug', "adding \"#{options[:glob].to_s}\" to search parameters")
						@globs << options[:glob]
					elsif(options[:glob].kind_of?(Regexp))
						Cfruby.controller.inform('debug', "adding \"#{options[:glob].to_s}\" to search parameters as a regular expression")
						@regex << options[:glob]
					elsif(options[:glob][0].kind_of?(String))
						options[:glob].each() { |subglob|
							Cfruby.controller.inform('debug', "adding \"#{subglob.to_s}\" to search parameters")
							@globs << subglob
						}
					elsif(options[:glob][0].kind_of?(Regexp))
						options[:glob].each() { |subglob|
							Cfruby.controller.inform('debug', "adding \"#{subglob.to_s}\" to search parameters as a regular expression")
							@regex << subglob
						}
					end
				end
				
				@matchmethods = Array.new()
				if(options[:directoriesonly])
					Cfruby.controller.inform('debug', "limiting search to directories only")
					@matchmethods << :directoriesonly
				elsif(options[:filesonly])
					Cfruby.controller.inform('debug', "limiting search to files only")
					@matchmethods << :filesonly
				end

				if(options[:olderthan])
					if(!options[:olderthan].kind_of?(Time))
						@olderthan = Time.parse(options[:olderthan])
					else
						@olderthan = options[:olderthan]
					end
					Cfruby.controller.inform('debug', "limiting search to items older than #{@olderthan.to_s}")
					@matchmethods << :olderthan
				end
				
				if(options[:smallerthan])
					@smallerthan = convertsize(options[:smallerthan])
					Cfruby.controller.inform('debug', "limiting search to items smaller than #{@smallerthan} bytes")
					@matchmethods << :smallerthan
				end

				if(options[:largerthan])
					@largerthan = convertsize(options[:largerthan])
					Cfruby.controller.inform('debug', "limiting search to items larger than #{@largerthan} bytes")
					@matchmethods << :largerthan
				end
				
				if(options[:empty])
					@matchmethods << :empty
				end
				
				if(options[:brokenlink])
					@matchmethods << :brokenlink
				end

				@excludeglobs = Array.new()
				@excluderegex = Array.new()
				@includeglobs = Array.new()
				@includeregex = Array.new()
				if(options[:exclude])
					if(options[:exclude].kind_of?(String))
						Cfruby.controller.inform('debug', "excluding items matching #{options[:exclude]}")
						@excludeglobs << options[:exclude]
					elsif(options[:exclude].kind_of?(Regexp))
						Cfruby.controller.inform('debug', "excluding items matching #{options[:exclude]} as a regular expression")
						@excluderegex << options[:exclude]
					elsif(options[:exclude][0].kind_of?(String))
						options[:exclude].each() { |subglob|
							Cfruby.controller.inform('debug', "excluding items matching #{subglob} as a regular expression")
							@excludeglobs << subglob
						}
					elsif(options[:exclude][0].kind_of?(Regexp))
						options[:exclude].each() { |subglob|
							Cfruby.controller.inform('debug', "excluding items matching #{subglob}")
							@excluderegex << subglob
						}
					end
				end
				
				if(options[:include])
					if(options[:include].kind_of?(String))
						Cfruby.controller.inform('debug', "including items matching #{options[:include]}")
						@includeglobs << options[:include]
					elsif(options[:include].kind_of?(Regexp))
						Cfruby.controller.inform('debug', "including items matching #{options[:include]} as a regular expression")
						@includeregex << options[:include]
					elsif(options[:include][0].kind_of?(String))
						options[:include].each() { |subglob|
							Cfruby.controller.inform('debug', "including items matching #{subglob}")
							@includeglobs << subglob
						}
					elsif(options[:include][0].kind_of?(Regexp))
						options[:include].each() { |subglob|
							Cfruby.controller.inform('debug', "including items matching #{subglob} as a regular expression")
							@includeregex << subglob
						}
					end
				end
		
			end
			
			def matches?(filename)
				basename = filename.basename
			
				# binary conditions
				@matchmethods.each() { |method|
					if(!self.send(method, filename))
						return(false)
					end
				}
				
				# basic matching
				@globs.each() { |glob|
					if(!File.fnmatch(glob, basename, File::FNM_DOTMATCH))
						return(false)
					end
				}
				@regex.each() { |regex|
					if(!regex.match(basename))
						return(false)
					end
				}
				
				# exclude/include
				exclude = false
				@excludeglobs.each() { |glob|
					if(File.fnmatch(glob, basename, File::FNM_DOTMATCH))
						exclude = true
						break
					end
				}
				@excluderegex.each() { |regex|
					if(regex.match(basename))
						exclude = true
						break
					end
				}
				
				if(!exclude)
					return(true)
				else
					@includeglobs.each() { |glob|
						if(File.fnmatch(glob, basename, File::FNM_DOTMATCH))
							return(true)
						end
					}
					@includeregex.each() { |regex|
						if(regex.match(basename))
							return(true)
						end
					}		
				end
				
				return(!exclude)
			end
		
		private
		
			# converts a str size into an Integer size in bytes
			def convertsize(str)
				if(str.kind_of?(Numeric))
					return(str)
				end
				
				str.strip!()
				regex = /^([0-9]+(?:\.[0-9]+)?)\s*([gmk])b?$/i
				match = regex.match(str)
				if(match == nil)
					raise(ArgumentError, "Unable to parse size of \"#{str}\"")
				end
				
				size = match[1].to_f()
				
				case(match[2].downcase())
				when('g')
					size = size * 1024 * 1024 * 1024
				when('m')
					size = size * 1024 * 1024
				when('k')
					size = size * 1024
				end
				
				return(size)
			end
			
		
			def directoriesonly(filename)
				return(File.directory?(filename))
			end
			
			
			def filesonly(filename)
				return(test(?f, filename))
			end
			
			
			def olderthan(filename)
				age = FileOps::SymlinkHandler.stat(filename).mtime()
				return(age < @olderthan)
			end
			
			
			def newerthan(filename)
				age = FileOps::SymlinkHandler.stat(filename).mtime()
				return(age < @olderthan)
			end
			
			
			def smallerthan(filename)
				return(FileOps::SymlinkHandler.stat(filename).size < @smallerthan)
			end


			def largerthan(filename)
				return(FileOps::SymlinkHandler.stat(filename).size > @largerthan)
			end
			
			
			def empty(filename)
				test = Pathname.new(filename)
				if(test.directory?)
					count = 0
					test.each_entry { |d|
						if(d.to_s !~ /^\.+$/)
							count = count + 1
						end
					}
					if(count == 0)
						return(true)
					end
				elsif(test.symlink?)
					begin
						test.realpath
					rescue
						if($!.to_s() =~ /No such file or directory/)
							return(true)
						else
							raise($!)
						end
					end
				elsif(test.file?)
					if(test.size == 0)
						return(true)
					end
				end
				
				return(false)
			end
			
			
			def brokenlink(filename)
				return(Cfruby::FileOps::SymlinkHandler.broken?(filename))
			end
		end
		
		
		
		# Find files that conform to a set of options within a given base directory and yield them to
		# a given block.  In addition to all of the options available to FileMatch the following options
		# may be given:
		# <tt>:depth</tt>:: the maximum depth to recurse into the base directory
		# <tt>:recursive</tt>:: recurse (default to a depth => 200)
		# <tt>:nonrecursive</tt>:: don't recurse at all (equivilant to :depth => 0)
		# <tt>:followsymlinks</tt>:: if true symlinks are expanded and returned as their realpath, otherwise they are returned as is (default false)
		# <tt>:returnorder</tt>:: if unset files are returned in traversal order, if set to 'delete' files are returned first followed by directories
		# <tt>:filematch</tt>:: normally internal use only, allows passing in of a FileMatch object (all other file matching options ignored)
		#
		# Returns the number of files found
		def FileFind.find(basedir, options = {}, &block)
			filematch = nil
			matched = 0

			if(options[:filematch] != nil)
				filematch = options[:filematch]
			else
				# set real options based on helper options
				if((options[:nonrecursive] or options[:recursive]) and options[:depth])
					raise(ArgumentError, ":depth argument is not meaningful with :recursive or :nonrecursive")
				end
				if(options[:nonrecursive])
					options[:depth] = 0
				elsif(options[:recursive])
					options[:depth] = 200 if options[:depth] == nil
					options.delete(:recursive)
				end

				# set basic options if they weren't passed in
				if(options[:glob] == nil)
					Cfruby.controller.inform('debug', "No glob given for search, using '*'")
					options[:glob] = '*'
				end
				if(options[:depth] == nil)
					Cfruby.controller.inform('debug', "No depth given for search, using 0")
					options[:depth] = 0
				end

				# get a filematch object
				filematch = FileMatch.new(options)
			end

			# add the filematch back to options so we can pass it back to
			# ourselves recursively
			options[:filematch] = filematch
			
			# set some options to local variables to prevent a lookup on every file
			maxdepth = options[:depth]

			# set the file return order
			deleteorder = false
			if(options[:returnorder] == 'delete')
				deleteorder = true
			end
			
			# allow people to pass in lists
			if(basedir.respond_to?(:each) and !basedir.kind_of?(String) and !basedir.kind_of?(Pathname))
				basedir.each() { |subdir|
					find(subdir, options) { |filename|
						matched += 1
						yield(filename)
					}
				}
				return(matched)
			else
				# attempt to expand with a glob and expand_path
				dirs = Dir.glob(File.expand_path(basedir.to_s))
				if(dirs.length > 1)
					find(dirs, options) { |filename|
						matched += 1
						yield(filename)
					}
					return(matched)
				elsif(dirs.length == 0)
					# if we didn't get anything out of the glob expansion, then the file doesn't really exist
					raise(FileExistError, "\"#{basedir}\" does not exist")
				else
					basedir = dirs[0]
				end
			end
			
			# convert basedir into an absolute pathname
			if(!basedir.kind_of?(Pathname))
				basedir = Pathname.new(basedir)
			end
			
			if(!basedir.symlink?() and !basedir.exist?())
				raise(FileExistError, "#{basedir.to_s} does not exist")
			end
			
			directories = Array.new()
			visited = Hash.new()
			# if the given basedir is a symlink, only follow it if :followsymlink == true
			if(basedir.symlink? and !options[:followsymlinks])
				if(filematch.matches?(basedir.expand_path))
					matched += 1
					yield(basedir.expand_path)
				end
			else
				basedir = basedir.realpath
				directories << Array.[](basedir, 0)
			end

			yielddirs = Array.new()
			
			while(directories.length > 0)
				currentdir = directories.pop()
				
				# skip this directory if we have already been there
				if(visited[currentdir[0]] != nil)
					next
				else
					visited[currentdir[0]] = true
				end
				
				currentdepth = currentdir[1]
				currentdir = currentdir[0]
				
				# add the directory to the yielddirs list if we need to, or yield it
				# depending on :returnorder
				if(filematch.matches?(currentdir))
					if(deleteorder)
						yielddirs << currentdir
					else
						matched += 1
						yield(currentdir)
					end
				end

				# yield files at this level and recurse if needed.  We use a form of pseudo recursion to avoid
				# exhausting the stack depth.  Directories that match the find are added to a special yielddirs
				# list and are yielded to the caller after the entire recursion has finished.  This ensures that
				# things like recursive delete work properly.
				if(currentdepth < maxdepth)
					Dir.glob("#{currentdir}/*", File::FNM_DOTMATCH) { |filename|
						filename = FileFind.expand_path(Pathname.new(filename), options)

						# skip if it escapes our basedir
						if(filename.relative_path_from(basedir).to_s() =~ /(^|\/)\.\.(\/|$)/)
							next
						end

						# if it is a directory add it to the list for recursion
						if(filename.directory?())
							directories.push(Array.[](filename, currentdepth+1))
						elsif(filematch.matches?(filename))
							Cfruby.controller.inform('debug', "found #{filename}")
							matched += 1
							yield(filename)
						end
					}
				end

			end
			
			while(yielddirs.length > 0)
				matched += 1
				yield(yielddirs.pop)
			end

			return(matched)
		end
		
		
		private
		
		
		# Returns an expanded absolute pathname - expanding symlinks if necessary.  Options:
		# <tt>:followsymlinks</tt>:: Follow symlinks
		def FileFind.expand_path(pathname, options)
			if(options[:followsymlinks])
			  if(Cfruby::FileOps::SymlinkHandler.broken?(pathname))
			    Cfruby.controller.inform('info', "Found broken symlink \"#{pathname.expand_path.to_s()}\" - unable to follow")
			    return(pathname.expand_path())
		    else
				  return(pathname.realpath())
			  end
			else
				return(pathname.expand_path())
			end
		end
					
	end
	
end
