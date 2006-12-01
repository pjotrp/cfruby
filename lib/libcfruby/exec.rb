# A module that provides a simple wrapper to open/exec calls.  It handles shell
# escaping of arguments and can return stdout and stderr as separate Strings.
#
# Author:: David Powers
# Copyright:: November, 2004
# License:: Ruby License


require 'libcfruby/cfruby'
require 'open3'


module Cfruby

	module Exec
		
		# Escapes +argument+ for passing to a shell by surrounding it in single quotes and
		# escaping any internal single quotes
		def Exec::shellescape(argument)
			argument.gsub(/([\\\t\| &`<>)('"])/) { |s| '\\' << s }
		end

		
		# Runs the given +command+ in a shell, escaping each argument in +args+.  Returns the output of the
		# command run
		def Exec::shellexec(command, *args)
			argarray = Array.new()
			if(args.length == 1 and args[0].kind_of?(Array))
			  args = args[0]
		  end
			args.each() { |argument|
				argarray << "#{shellescape(argument)}"
			}
			
			output = nil
			Cfruby.controller.attempt("run \"#{command.gsub(/ /, "\\ ")} #{argarray.join(' ')}\" in a shell", 'unknown', 'exec') {
				output = `#{shellescape(command.gsub(/ /, "\\ "))} #{argarray.join(' ')}`
			}
						
			return(output)
		end
		
		
		# Runs the given +command+ as a forked process, returns stdout and stderr as
		# separate Arrays of output lines.  If +user+ is given su will be used to run
		# the command as the given user.  FIXME - should use native ruby user switching if
		# possible
		def Exec::exec(command, user=nil)
			
			output = Array.new()
			erroroutput = Array.new()
			
			# the following code is a touch hackish because select returns readable
			# on streams that are at EOF, so we have to check for available input
			# as well as for EOF each time through to avoid getting a bunch of
			# blank entry lines.
			attemptmessage = "run \"#{command}\""
			if(user)
				attemptmessage += " as user '#{user}'"
			end
			Cfruby.controller.attempt(attemptmessage, 'unknown', 'exec') {
				if user != nil
					command = "su #{user} -c #{shellescape(command)}"
				end
				Cfruby.controller.inform('debug', "Running '#{command}'")
				stdin, stdout, stderr = Open3.popen3(command)
				reading = true
				while(!stdout.eof? or !stderr.eof?)
					ready = select([stdout], nil, nil, 0)
					ready[0].each() { |istream|
						line = istream.gets()
						if(line != nil)
							output << line
						end
					}
				
					ready = select([stderr], nil, nil, 0)
					if(ready != nil)
						ready[0].each() { |istream|
							line = istream.gets()
							if(line != nil)
								erroroutput << line
							end
						}
					end
				end
			}

			return(Array.[](output, erroroutput))			
		end
	
	end

end
