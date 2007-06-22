# The cached version of file editing - only writes to disk when the file
# changes.
#
# Author:: Pjotr Prins
# Copyright:: July 2007
# License:: Ruby License

# require 'language/deepcopy'
require 'libcfenjin/cfp_cksum'
# require 'filelock'
	
module Cfruby
	
	class FileEditCached
	
		attr_reader :filename

		include Cfp_Cksum
		
		def initialize fn
			@filename = fn
			@lines = Array.new
			if File.exist? fn
				FileOps.flock(fn) { | f|
					f.each_line do | line |
						@lines.push line
					end
				}
			end
			@original_cksum = cksum @lines
		end
	
		def changed?
			cksum(@lines) != @original_cksum
		end
	
		def AutoCreate
			@createnew = true
		end
	
		def EmptyEntireFilePlease
			@lines = Array.new
		end
	
		def Warning msg=''
			fullmsg = 
				"# WARNING: DO NOT CHANGE THIS FILE - it is maintained by #{ENV['USER']} #{msg} "+`date`
			if NoSuchLine '^# WARNING: DO NOT CHANGE THIS FILE'
				PrependIfNoSuchLine fullmsg
			else
				@lines[0] = fullmsg
			end
		end
	
		def PrependIfNoSuchLine line
			@lines.unshift forcenl(line) if NoSuchLine line,false
		end
	
		def AppendIfNoSuchLine line
			@lines.push forcenl(line) if NoSuchLine line,false
		end
	
		def NoSuchLine check, regex=true
			@lines.each do | line |
				if regex
					return false if line =~ /^#{check}$/
				else
					# p line.strip,check.strip
					return false if line.strip == check.strip
				end
			end
			true
		end
	
		def ReplaceAll repl,with
			@lines.each_index do | i |
				@lines[i] = @lines[i].gsub(/#{repl}/,with)
			end
		end
	
		def ReplaceAllAppend repl,with
			ReplaceAll repl,with
			AppendIfNoSuchLine with 
		end
	
		# Edit a text file replacing a section with first line and last
		# line passed as a regular expression.
		#
		# Optionally you can include replacing the fist and last lines.
	
		def ReplaceSection first,last,with,include_first_last=false
			@lines.each_index do | i |
				if @lines[i] =~ /^#{first}$/
					fi = i
		fi -= 1 if include_first_last
					section = ''
					begin
						i = i+1
						if @lines[i] =~ /#{last}$/
							if section != with
								# $logger.log "EditFile replacing section #{first} with \"#{with}\""
					i += 1 if include_first_last
								before = @lines.slice(0..fi)
								after  = @lines.slice(i,@lines.size)
								# ---- insert new
								@lines = before + with.split("\n") + after
							end
							return
						end
						section += @lines[i]
					end while @lines[i]
				end
			end
			# $logger.warn "Section #{first} in #{@filename} does not exist!"
		end
		
		def HashCommentLinesContaining s
			@lines.each_index do | i |
				@lines[i] = '#'+@lines[i] if @lines[i] =~ /#{s}/ and @lines[i] !~ /^#/
			end
		end
	
		def write dobackup=true
			if !File.exist? @filename and !@createnew
				# $logger.log "EditFile not creating (non existent file) #{@filename}"
				return
			end
	
			if changed?    
				if dobackup and File.exist? @filename
					FileOps.backup @filename
				end
				# $logger.log "EditFile writing updated #{@filename}"
				FileOps.flock(@filename,'w') { | f |
					@lines.each do | line |
						f.puts line
					end
				}
			else
				# $logger.log "EditFile #{@filename} unchanged"
			end
		end
	
		# This function allows you to use a block type:
		#
		#   EditFileCached.edit fn do | e |
		#     e.AppendIfNoSuchLine 'Yes!'
		#   end
	
		def FileEditCached.edit fn
			e = FileEditCached.new fn
			yield e
			e.write
		end
	
	private
	
		# ---- supporting functions
	
		def forcenl line
			line.sub(/\s+$/,"\n")
		end

	end

end
