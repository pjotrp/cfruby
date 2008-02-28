# This module contains the logic for parsing Cfruby style syntax -
# including the addition of quotes etc. The actual implementation of
# these methods can be found in cfrubyruntime.rb
#
# Author:: Pjotr Prins
# Copyright:: July 2007
# License:: Ruby License

module Cfruby

	module Cfp_ParserLogic

		# Parse +line+ and turn it into a valid Ruby call
		def form_links line
			if line =~ /->/
				from,to = line.split(/\s*->\s*/)
				line = 'link '+quotepath(to)+','+quotepath(from)
			end
			convert_global_variables(line)
		end

		# Parse groups lines for Cfruby assignments like 'sshd = ( hostname1 hostname2 )'
		def form_groups line
			return line if remark? line
			# Test for assignment with spaces and braces
			if line.strip !~ /^\w+\s+\=\s+\(\s.*\s\)$/
				raise 'Illegal groups command: "'+line+'"' if line.strip != ''
			end
			line = convert_class_assignments(line)
			convert_global_variables(line)
		end

		# Parse control lines for Cfruby assignments like 'sshd = ( hostname1 hostname2 )'
		# Note that the notation is pretty strict. 'sshd = (hostname1 hostname2)', for 
		# example will not translate. This is to allow for standard Ruby assignments in
		# a control block.
		def form_control line
			line = convert_class_assignments(line)
			line = convert_global_assignments(line)
			convert_global_variables(line)
		end

		# Parse +line+ and turn it into a valid Ruby call
		def form_copy line
			cfline 'copy',line
		end

		def form_tidy line
			cfline 'tidy',line
		end

		def form_directories line
			cfline 'directories',line
		end

		def form_files line
			cfline 'files',line
		end

		def form_editfiles line
			convert_global_variables(line)
		end
		
		# In shellcommands lines starting with a (double) quote are
		# executed by libcruby. Backquotes are Ruby commands - and
		# to see the return value we prepend an output statement.
		def form_shellcommands line
			if line.strip =~ /^['"](.*)['"]$/
				cmda = eval('%w{'+$1+'}')
				p cmda
				# TODO: fixme
				raise 'Cannot execute quoted shellcommand (yet)'
				# Exec::shellexec(line)
			elsif line.strip =~ /^[`]/
				escline = line.strip.gsub(/"/,'\"') 
				line = embed_exec_into_informer(line,'Shell: '+escline+"\n")
			end
			convert_global_variables(line)
		end
		
		# Turns a double colon conditional into a Ruby conditional
		def form_conditional line
			return line if !conditional? line
			# ---- Fetch statement
			line.strip =~ /(\S+)::/
			s = $1
			# ---- Split on separators
			toks = s.split(/[.|() !]+/)
			operators  = s.split(/[^.| ()!]+/)
			r = 'if'
			idx = 0
			# ---- Check for leading operators
			idx = -1 if toks[0] == ''
			toks.each do | tok |
				r += translate_operators(operators[idx]) + " isa?('#{tok}')" if tok != ''
				idx += 1
			end
			r += translate_operators(operators[idx])
			r
		end

		# Returns whether a line is a Cfruby style conditional (double colon)
		def conditional? line
			line.strip =~ /[\w.|)(]+::$/
		end
	
		def embed_exec_into_informer s,msg
			"Cfruby.controller.inform(\"verbose\", \""+msg+"\n\#{"+s+"}\")"
		end
	
private

		def remark? line
			# ---- treat empty line as remark
			return true if line.strip == ''
			# ---- remark?
			return line =~ /^\s*#/
		end
		
		# Test for +s+ containing attributes like rec=inf m=666 etc.
		def has_attrib? s
			s.strip =~ /\s/
		end

		# Surround string with quotes if it is a qualified path 
		def quotepath s
			s = s.strip
			s = "\"#{s}\"" if s =~ /^([\/*.])|((http|https|ftp):)/
			s
		end

		# Checks +line+ contains a function call +funcname+
		def func_call funcname,line
			line.strip =~ /^#{funcname}(\s|\()/
		end

		# Parse a Cf style line with options - has some included logic for
    # converting boolean from string, and quoting regex's
    #
		def cfline funcname,line
			return line if remark? line
			# ---- Return Ruby 'if' and 'end' intact
			return line if line.strip =~ /^(if\s|end)/

			ret = line
			if !func_call(funcname,line)
				# p [funcname,line]
				# sleep 3
				# ---- Prepend the function name (i.e. link or copy)
				ret = funcname+' '
				# ---- Get filenames and tags
				a = line.strip.split(/\s+/)
				ret += quotepath(a.shift)
				if a.size > 0
					# ---- Fetch the attributes
					ret += ',{'
					a.each do | attribute |
						parameter,value = attribute.split(/=/)
						if value
							# Translate parameters
							parameter = Cfp_MapOptions::SYNONYM[parameter] if Cfp_MapOptions::SYNONYM[parameter]
							# ---- Put value in quotes unless it is a digit or is (likely)
							#      a path or Ruby variable
							if parameter == 'dest' 
								# ---- File path
								ret += "'#{parameter}'=>"+quotepath(value)+','
              elsif parameter == 'pattern'
                # ---- patterns are always quoted
								ret += "'#{parameter}'=>'#{value}',"
              elsif value and (value.downcase == 'true' or value.downcase == 'false')
                # ---- to boolean
								ret += "'#{parameter}'=>#{value},"
							else
								# ---- is it a string or path?
								value = "'#{value}'" if value !~ /^\d+$/ and value =~ /^(\w|-|\/)+$/
								# ---- should it be octal?
								value = '0'+value if parameter == 'mode' and value =~ /^[1-9]/
								ret += "'#{parameter}'=>"+value+','
							end
						end
					end
					ret.chop!
					ret += '}'
				end
			end
		  convert_global_variables(ret)
		end

		# Convert '|', '&' and '!' operators to Ruby versions
	
		def translate_operators s
			r = ''
			if s
				s.each_byte do | c |
					r += ' and'  if c==46
					r += ' or'   if c==124
					r += ' not'  if c==33
					r += ' ('    if c==40
					r += ' )'    if c==41
				end
			end 
			r
		end

		# Convert a class assignment:
		#
		#   myworkstation = ( hostname1 hostname2 )
		#
		# into the cfenjin assignment:
		#
		#   assign %w{ myworkstation hostname1 hostname2 }
		#   
		def convert_class_assignments(line)
			if line.strip =~ /^\w+\s+\=\s+\(\s.*\s\)$/
				a = line.split(/\s+/)
				a.delete_if { | s | s == '(' or s == ')' or s == '=' }
				line = 'assign %w{ '+a.join(' ')+' }'
			end
			line
		end
		
		# Convert a global assignment into a user Hash
		# assignment
		#
		#   $timeserver = 'ntp.xs4all.nl'
		#
		# into
		#
		#   @cf.site['timeserver'] = 'ntp.xs4all.nl'
		#   
		def convert_global_assignments(line)
			return line if remark?(line)
			if line.strip =~ /^\$([\w_]+)\s*\=\s*(.*)/
				line = "@cf.site['"+$1+"'] = "+$2
				@global_names.push $1
			end
			line
		end

		# Convert a global variable to a user Hash if
		# if it recognised
		#
		#   @ef.AppendIfNoSuchLine "server #{$timeserver}"
		#
		# into
		#
		#   @ef.AppendIfNoSuchLine "server #{@cf.site[timeserver]}"
		#
		def convert_global_variables(line)
			return line if remark?(line)
			# reverse sort strings so partial strings do not replace
			# within a name
			@global_names.sort.reverse.each do | name |
				line = line.gsub(/\$#{name}/,'@cf.site[\''+name+'\']')
			end
			line
		end
	end

end
