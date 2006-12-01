# Methods for line-based editing of files.  Generally geared towards editing configuration files
# on POSIX-based systems.
#
# Author:: David Powers
# Copyright:: November, 2004
# License:: Ruby License

require 'libcfruby/cfruby'
require 'libcfruby/checksum'
require 'tempfile'
require 'pathname'

module Cfruby

	# Methods for line-based editing of files.  Generally geared towards editing configuration files
	# on POSIX-based systems.
	module FileEdit
		
		APPEND = "append"
		PREPEND = "prepend"
				
		class FileEditError < Cfruby::CfrubyError
		end
		
		class AnchorNotFoundError < FileEditError
		end
		
		
		# Returns true if the given +pattern+ (str or regular expression) is found in +filename+
		def FileEdit.contains?(filename, pattern)
			if(!pattern.kind_of?(Regexp))
				pattern = Regexp.new(Regexp.escape(pattern.to_s()))
			end
			
			File.open(filename, File::RDONLY) { |fp|
				fp.each_line() { |line|
					if(pattern.match(line))
						return(true)
					end
				}
			}
			
			return(false)
		end
		
				
		# Ensures that filename contains str. If str is a single line, that line will be searched
		# for.  If str contains multiple lines then, by default, it will be split on /\n/ and each line
		# will be checked/added in turn.  If :block => true is passed in then the first line of a multiline
		# block will be searched for (or :regex if it is given), and the entire block will be added if it 
		# is not found.  If str contains an array then file_must_contain will be called on each item in order.  
		# Returns true if str (or any substr) was added, false if it was not (meaning everything passed was 
		# already in the file).  Options:
		# <tt>:position</tt>:: may be FileEdit::APPEND or FileEdit::PREPEND (or 'append' or 'prepend').  Defaults to FileEdit::APPEND
		# <tt>:anchor</tt>:: may be nil, a line number, or a regular expression.  Used to determine where to append or prepend
		# <tt>:fuzzymatch</tt>:: defaults to true - causes whitespace in str to be largely ignored for purposes of matching.
		# <tt>:regex</tt>:: if given, then str will be added if regex matches no lines in the file 
		# <tt>:block</tt>:: defaults to false - determines whether multiline str's will be treated as a single block
		# <tt>:allwaysadd</tt>:: If true str will be added even if the given anchor cannot be found.  Defaults to false.
		def FileEdit.file_must_contain(filename, str, options={})
			if(!options[:position])
				options[:position] = APPEND
			elsif(options[:postion] == 'append')
				options[:position] = APPEND
			elsif(options[:position] == 'prepend')
				options[:position] = PREPEND
			end
			
			if(options[:fuzzymatch] == nil)
				options[:fuzzymatch] = true
			end
			
			if(str.kind_of?(Array))
				added = false
				str.each() { |substr|
					if(file_must_contain(filename, substr, options))
						added = true
					end
				}
				return(added)
			elsif(str =~ /\n./ and !options[:block])
				return(file_must_contain(filename, str.split(/\n/), options))
			end
			
			# add a newline to str if it wasn't passed in with one
			if(str !~ /\n$/)
				str = str + "\n"
			end

			regex = options[:regex]
			if(regex == nil)
				# if the str is multi-line, split it and use the first line
				matchstr = str
				if(str =~ /\n./)
					matchstr = str.split(/\n/)[0]
				end
				
				if(options[:fuzzymatch])
					regex = convert_to_fuzzy_regex(matchstr)
				else			
					regex = Regexp.new(Regexp.escape(matchstr))
				end
			end
					
			# don't call contains? here because we need to snag the last line in the file
			lastline = "\n"
			File.open(filename, File::RDONLY) { |fp|
				fp.each_line() { |line|
					if(regex.match(line))
						return(false)
					end
					lastline = line
				}
			}
	
			Cfruby.controller.attempt("adding \"#{str}\" to #{filename}", 'destructive') {
				begin
					# if we get here, it isn't in the file - stick it in
					if(options[:position] == APPEND)
						if(options[:anchor] == nil)
							FileEdit.open(filename, File::RDWR|File::APPEND) { |fp|
								if(lastline !~ /\n$/)
									fp.write("\n")
								end
								fp.write(str)
							}
						elsif(options[:anchor].kind_of?(Integer))
							lines = nil
							File.open(filename, File::RDONLY) { |fp|
								lines = fp.readlines()									
							}
							if(options[:anchor] < 0 or lines.length+1 < options[:anchor])
								raise(AnchorNotFoundError, "options[:anchor] is past the last line in the file \"#{filename}\"")
							end
							lines.insert(options[:anchor]+1, str)
							write_file(filename, lines)
						elsif(options[:anchor].respond_to?(:match))
							added = false
							lines = Array.new()
							File.open(filename, File::RDONLY) { |fp|
								fp.each_line() { |line|
									lines << line
									if(options[:anchor].match(line))
										lines << str
										added = true
									end				
								}
							}
							if(added)
								write_file(filename, lines)
							else
								raise(AnchorNotFoundError, "Anchor \"#{options[:anchor].source}\" not found in \"#{filename}\"")
							end
						else
							raise(ArgumentError, "options[:anchor] was not nil, a number, or a regular expression")
						end
					elsif(options[:position] == PREPEND)						
						if(options[:anchor] == nil)
							File.open(filename, File::RDWR) { |fp|
								lines = fp.readlines
								fp.seek(0, IO::SEEK_SET)
								fp.truncate(0)
								fp.write(str)
								lines.each() { |line|
									fp.write(line)
								}
							}
						elsif(options[:anchor].kind_of?(Integer))
							lines = nil
							File.open(filename, File::RDONLY) { |fp|
								lines = fp.readlines
							}
							if(options[:anchor] < 0 or lines.length < options[:anchor])
								raise(AnchorNotFoundError, "options[:anchor] is past the last line in the file \"#{filename}\"")
							end
							lines.insert(options[:anchor], str)
							write_file(filename, lines)
						elsif(options[:anchor].respond_to?(:match))
							added = false
							lines = Array.new()
							File.open(filename, File::RDONLY) { |fp|
								fp.each_line() { |line|
									if(options[:anchor].match(line))
										lines << str
										added = true
									end				
									lines << line
								}									
							}

							if(added)
								write_file(filename, lines)
							else
								raise(AnchorNotFoundError, "Anchor \"#{options[:anchor].source}\" not found in \"#{filename}\"")
							end
						else
							raise(ArgumentError, "options[:anchor] was not nil, a number, or a regular expression")
						end
					end
				rescue AnchorNotFoundError
					if(options[:allwaysadd])
						options[:anchor] = nil
						file_must_contain(filename, str, options)
					else
						raise($!)
					end
				end
			}
			
			return(true)
		end
		
		
		# Ensures that +filename+ does not contain lines matching +pattern+.  Pattern may be a String,
		# Regexp, or an Array of either.  Options:
		# <tt>:fuzzymatch</tt>:: defaults to true - causes whitespace in pattern (if passed as a String) to be largely ignored for purposes of matching.
		def FileEdit.file_must_not_contain(filename, pattern, options={})
			if(pattern.kind_of?(Array))
				pattern.each() { |p|
					file_must_not_contain(filename, p)
				}
				return()
			elsif(!pattern.kind_of?(Regexp) and pattern.to_s() =~ /\n./)
				file_must_not_contain(filename, pattern.split("\n"))
			end
			
			if(options[:fuzzymatch] == nil)
				options[:fuzzymatch] = true
			end
			
			regex = pattern			
			# convert regex to a real Regexp if it isn't one
			if(!pattern.kind_of?(Regexp))
				if(options[:fuzzymatch])
					regex = convert_to_fuzzy_regex(regex)
				else
					regex = regex.to_s()
					if(regex !~ /\n$/)
						regex += "\n"
					end
					regex = Regexp.new("^#{Regexp.escape(regex.to_s)}$")
				end
			end
			
			# do this in two passes, one with the file open read only to check
			# for the existence of the line, then trunc and write out a new file
			# if it does
			lines = Array.new()
			rewrite = false
			FileEdit.open(filename, File::RDONLY) { |fp|
				fp.each_line() { |line|
					if(regex.match(line))
						rewrite = true
					else
						lines << line
					end
				}
			}
			
			changed = false
			if(rewrite == true)
				Cfruby.controller.attempt("removing \"#{regex.to_s()}\" from #{filename}", 'nonreversible', 'destructive') {
					changed = FileEdit.open(filename, File::TRUNC|File::WRONLY) { |fp|
						lines.each() { |line|
							fp.write(line)
						}
					}
				}
			end
			
			return(changed)
		end
	
		
		# Appends +str+ to the end of +filename+
		def FileEdit.file_append(filename, str) 
			changed = false
			Cfruby.controller.attempt("appending \"#{str}\" to #{filename}", 'destructive') {
				changed = FileEdit.open(filename, File::WRONLY|File::APPEND) { |fp|
					fp.write(str)
				}
			}
			
			return(changed)
		end
		
		
		# Prepends +str+ to +filename+
		def FileEdit.file_prepend(filename, str)
			changed = false
			Cfruby.controller.attempt("prepending \"#{str}\" to #{filename}", 'destructive') {
				lines = File.open(filename, File::RDONLY).readlines()
				changed = FileEdit.open(filename, File::WRONLY|File::TRUNC) { |fp|
					fp.write(str)
					if(str !~ /\n$/)
						fp.write("\n")
					end
					lines.each() { |line|
						fp.write(line)
					}
				}
			}
			
			return(changed)
		end
		
		
		# Atomically sets the contents of +filename+ by first removing all lines in +remove+ and then
		# adding all lines in +add+ using file_must_not_contain and file_must_contain
		def FileEdit.set_contents(filename, remove, add, options={})
			filename = Pathname.new(filename).realpath

			newfile = Tempfile.new('fileedit')
			File.open(filename, File::RDONLY) { |fp|
				fp.each_line() { |line|
					newfile.write(line)
				}
			}
			newfile.close()
			
			changed = false
			if(remove)
				mustnotchanged = file_must_not_contain(newfile.path, remove, options)
				if(mustnotchanged)
					changed = true
				end
			end
			if(add)
				mustchanged = file_must_contain(newfile.path, add, options)
				if(mustchanged)
					changed = true
				end
			end
			
			if(changed)
				FileOps.move(newfile.path, filename, :force=>true, :preserve=>true)
			end
			
			return(changed)
		end
		
		
		# Replaces all lines matching +regex+ with +str+.  Options:
		# <tt>:firstonly</tt>:: if true then the first match is replaced and all other matching lines are removed from the file.
		# <tt>:fuzzymatch</tt>:: (defaults to true) causes String whitespace to be ignored for matching purposes
		# <tt>:alwaysadd</tt>:: (defaults to true) then the line will be added (by calling file_must_contain and passing 
		# through options) to the end of the file even if no lines match +regex+.
		def FileEdit.replace(filename, regex, str, options={})
			if(options[:fuzzymatch] == nil)
				options[:fuzzymatch] = true
			end

			if(options[:alwaysadd] == nil)
				options[:alwaysadd] = true
			end
			
			if(str !~ /\n$/)
				str << "\n"
			end
			
			if(!regex.kind_of?(Array))
				regex = Array.[](regex)
			end
			
			regex.each_index() { |i|
				if(!regex[i].kind_of?(Regexp))
					if(options[:fuzzymatch])
						regex[i] = convert_to_fuzzy_regex(regex[i], :partialstr => true)
					else
						regex[i] = Regexp.new(Regexp.escape(regex[i]))
					end
				end
			}
			
			replaced = false
			Cfruby.controller.attempt("Replacing #{regex[0].source}... with #{str} in \"#{filename}\"", 'destructive', 'nonreversible') {
				lines = Array.new()
				File.open(filename, File::RDONLY) { |fp|
					fp.each_line() { |line|
						regex.each() { |r|
							if(r.match(line))
								if(replaced && options[:firstonly])
									next
								else
									line = str
									replaced = true
								end
							end
						}
						lines << line
					}
				}
			
				if(!replaced and options[:alwaysadd])
					file_must_contain(filename, str, options)
					replaced = true
				elsif(replaced)
					changed = write_file(filename, lines)
					if(changed != true)
						replaced = false
						Cfruby.controller.attempt_abort("unchanged")
					end
				else
					replaced = false
					Cfruby.controller.attempt_abort("unchanged")
				end
			}
			
			if(replaced)
				return(true)
			else
				return(false)
			end
		end
		
		
		# Comments out lines that match +regex+, which may also be given as a string
		# Options:
		# <tt>:commentwith</tt>:: (defaults to '#') Use this at the front of the line to comment the line
		# <tt>:fuzzymatch</tt>:: (defaults to true) If regex is given as a String, ignore whitespace
		def FileEdit.comment(filename, regex, options = {})
			if(options[:fuzzymatch] == nil)
				options[:fuzzymatch] = true
			end

			if(!options[:commentwith])
				options[:commentwith] = '#'
			end

			if(!regex.kind_of?(Array))
				regex = Array.[](regex)
			end
			
			regex.each_index() { |i|
				if(!regex[i].kind_of?(Regexp))
					if(options[:fuzzymatch])
						regex[i] = convert_to_fuzzy_regex(regex[i], :partialstr => true)
					else
						regex[i] = Regexp.new(Regexp.escape(regex[i]))
					end
				end				
			}
		
			commented = Regexp.new("^\\s*#{Regexp.escape(options[:commentwith])}")
		
			changed = false
			Cfruby.controller.attempt("Commenting all lines matching \"#{regex.map() { |r| r.source() }.join(',')}\" in \"#{filename}\"", 'destructive') {
				lines = Array.new()
				File.open(filename, File::RDONLY) { |fp|
					lines = fp.readlines()
				}
			
				lines.each_index() { |i|
					regex.each() { |r|
						if(r.match(lines[i]) and !commented.match(lines[i]))
							lines[i] = options[:commentwith] + ' ' + lines[i]
							Cfruby.controller.inform('verbose', "Commented \"#{lines[i].strip()}\" in #{filename}")
							changed = true
						end						
					}
				}
			
				if(!changed)
					Cfruby.controller.attempt_abort("nothing commented")
				end

				FileEdit.open(filename, File::WRONLY | File::TRUNC) { |fp|
					lines.each() { |line|
						fp.write(line)
					}
				}				
			}
			
			return(changed)
		end
		
		
		# Uncomments lines that match +regex+, which may also be given as a string
		# Options:
		# <tt>:commentwith</tt>:: (defaults to '#') Remove this from the front of the line to uncomment the line
		# <tt>:fuzzymatch</tt>:: (defaults to true) If regex is given as a String, ignore whitespace
		def FileEdit.uncomment(filename, regex, options = {})
			if(options[:fuzzymatch] == nil)
				options[:fuzzymatch] = true
			end

			if(!options[:commentwith])
				options[:commentwith] = '#'
			end

			if(!regex.kind_of?(Array))
				regex = Array.[](regex)
			end

			regex.each_index() { |i|
				if(!regex[i].kind_of?(Regexp))
					if(options[:fuzzymatch])
						regex[i] = convert_to_fuzzy_regex(regex[i], :partialstr => true)
					else
						regex[i] = Regexp.new(Regexp.escape(regex[i]))
					end
				end				
			}

			commented = Regexp.new("^\\s*#{Regexp.escape(options[:commentwith])}")

			changed = false
			Cfruby.controller.attempt("Uncommenting all lines matching \"#{regex.map() { |r| r.source() }.join(',')}\" in \"#{filename}\"", 'destructive') {
				lines = Array.new()
				File.open(filename, File::RDONLY) { |fp|
					lines = fp.readlines()
				}

				lines.each_index() { |i|
					regex.each() { |r|
						if(r.match(lines[i]) and commented.match(lines[i]))
							# use multiline match here to get the newline on the end
							lines[i] = lines[i][/^\s*#{Regexp.escape(options[:commentwith])}\s*(.*)$/m, 1]
							Cfruby.controller.inform('verbose', "Uncommented \"#{lines[i].strip()}\" in #{filename}")
							changed = true
						end						
					}
				}

				if(!changed)
					Cfruby.controller.attempt_abort("nothing uncommented")
				end

				FileEdit.open(filename, File::WRONLY | File::TRUNC) { |fp|
					lines.each() { |line|
						fp.write(line)
					}
				}
			}
			
			return(changed)
		end


		# Sets +variable+ to +value+ in +filename+ (as in hostname = "my.hostname.com").  Options:
		# <tt>:delimiter</tt>:: ('=' by default) determines what delimiter to place between +variable+ and +value+
		# <tt>:whitespace</tt>:: (overrides delimiter) uses a special whitespace matching delimiter if true
		def FileEdit.set(filename, variable, value, options={})
		  replaced = false
			Cfruby.controller.attempt("Setting \"#{variable}\" to \"#{value}\" in \"#{filename}\"", 'destructive', 'nonreversible') {
				delimiter = '='
				replacement = delimiter
				if(options[:whitespace])
					delimiter = "\\s+"
					replacement = ' '
				elsif(options[:delimiter] != nil)
					replacement = options[:delimiter]
					delimiter = Regexp.escape(options[:delimiter])
				end
			
				regex = Regexp.new("^\\s*#{Regexp.escape(variable)}\\s*?#{delimiter}")
				str = "#{variable}#{replacement}#{value}\n"
			
				replaced = replace(filename, regex, str)
				if(replaced != true)
					Cfruby.controller.attempt_abort("unchanged")
				end
			}

			return(replaced)
		end
		
		
		# Handles atomic editing by creating a temporary copy of +filename+ and only writing
		# it back if an actual change has been made.  Yields a File object.
		def FileEdit.open(filename, mode, &block)
			Cfruby.controller.attempt("Editing \"#{filename}\"") {
				newfile = Tempfile.new('fileedit')
				newfile.close(false)
				
				# attempt to chown the temp file - and set move based on our ability to do so
				move = false
				begin
					Cfruby::FileOps.chown(newfile.path, File.stat(filename).uid, File.stat(filename).gid)
					move = true
				rescue
					# we failed - do nothing
				end
				
				# chmod the temp file
				Cfruby::FileOps.chmod(newfile.path, File.stat(filename).mode)
				
				buffer = ''
				File.open(filename, File::RDONLY) { |orig|
					File.open(newfile.path, File::WRONLY|File::TRUNC) { |copy|
						while(orig.read(2048, buffer) != nil)
							copy.write(buffer)
						end
					}
				}

				File.open(newfile.path, mode) { |fp|
					yield(fp)
				}

				if(Cfruby::Checksum::Checksum.get_checksums(filename).sha1 != Cfruby::Checksum::Checksum.get_checksums(newfile.path).sha1)
					# backup the file
					FileOps.backup(filename)
					
					if(move)
						FileOps.move(newfile.path, filename, :force => true, :preserve => true)
					else
						File.open(newfile.path, File::RDONLY) { |orig|
							File.open(filename, File::WRONLY|File::TRUNC) { |copy|
								while(orig.read(2048, buffer) != nil)
									copy.write(buffer)
								end
							}
						}
					end
					
					return(true)
				else
					Cfruby.controller.attempt_abort("unchanged")
				end
			}
			
			return(false)
		end
		
		private
		
		def FileEdit.write_file(filename, lines)
			changed = FileEdit.open(filename, File::WRONLY) { |fp|
				fp.truncate(0)
				lines.each() { |line|
					fp.write(line)
				}
			}
			
			return(changed)
		end


		# turns a string into a fuzzy match string
		# <tt>:partialstr</tt>:: if true, the string is assumed to be part of an entire line rather than a whole line on its own
		def FileEdit.convert_to_fuzzy_regex(str, options = {})
			tokens = str.strip.split(/\s+/).map { |tok|
				Regexp.escape(tok)
			}
			
			regex = tokens.join("\\s+")
			if(!options[:partialstr])
				regex = "^\\s*#{regex}\\s*$"
			end
			regex = Regexp.new(regex)
			
			Cfruby.controller.inform('debug', "\"#{str}\" converted to \"#{regex.source()}\"")
			return(regex)
		end
		
	end
	
end
