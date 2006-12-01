# The Processes module attempts to provide a generic interface for retrieving process information from
# a running system
#
# Author:: David Powers
# Copyright:: November, 2004
# License:: Ruby License

require 'libcfruby/cfruby'
require 'libcfruby/os'


module Cfruby

	# The Processes module attempts to provide a generic interface for retrieving process information from
	# a running system
	module Processes
		
		# Base class for all Processes module specific errors
		class ProcessesError < CfrubyError
		end
		
		# Raised when a duplicate processes appears in a process listing
		class DuplicateProcessError < ProcessesError
		end
		
		
		# A holding object for a list of processes and information about them.	Each process is
		# referenced by its unique process id in Hash fashion (plist[1])
		class ProcessList < Hash
			def to_hash()
				
				hash = Hash.new()
				self.each_key() { |key|
					hash[key] = self[key].to_hash
				}
				
				return(hash)
			end
		end
		
		
		# A holding object for information about a process.	 Currently implemented as a
		# simple OpenStruct.	Should provide accessor methods for as many of the following
		# as possible (listed in order of importance):
		# pid:: unique process id 
		# program:: the name or commandline of the program
		# username:: the username of the user running the program
		# flags:: process flags (zombie, jailed, etc)
		# starttime:: when the program was started
		# runtime:: how long the program has been running (cpu time)
		# cpu (%):: percentage of cpu being used
		# mem (%):: percentage of memory being used
		class ProcessInfo < OpenStruct
			def to_s()
				return(self.program)
			end
			
			
			def to_hash()
				keyregex = /^([^=]+)=$/
				hash = Hash.new()
				self.methods.each() { |pkey|
					match = keyregex.match(pkey)
					if(match)
						hash[match[1]] = self.send(match[1].to_sym)
					end
				}
				
				return(hash)
			end
		end
		
		
		# The ProcessManager class serves mostly as an in-code description of the ProcessManager interface.
		# It implements a handful of useful of helper functions, but is generally implemented in a very generic 
		# manner, and should be overridden on a case by case basis specific to a particular operating system
		class ProcessManager
		
			# Kills the given process (expects a ProcessInfo object)
			def kill(process)
				`kill #{process.pid}`
				sleep(3)
				if(processes()[process.pid])
					`kill -9 #{process.pid}`
				end
			end
			
			
			# Returns a ProcessList object that contains key value pairs for
			# every process that is currently running. 
			def processes()
				processes = ProcessList.new()
				processlist = `ps auxww`
				processregex = /^(\S+)\s+([0-9]+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(.*)$/
				processlist.each() { |line|
					line.strip!()
					match = processregex.match(line)
					if(match != nil)
						info = ProcessInfo.new()
						info.username = match[1]
						info.pid = match[2].to_i()
						info.flags = match[8]
						info.starttime = match[9]
						info.runtime = match[10]
						info.program = match[11]
						info.cpu = match[3].to_f()
						info.mem = match[4].to_f()
						if(processes.has_key?(info.pid))
							raise(DuplicateProcessError, "Process #{info.pid} appeared twice in the process listing")
						end
						processes[info.pid] = info
					end
				}
				
				return(processes)
			end
			
			
			# Returns the first ProcessInfo object of a process matching +processname+ (either a String or Regex), or false
			def has_process?(processname)
				if(!processname.kind_of?(Regexp))
					processname = Regexp.new(Regexp.escape(processname))
				end
				
				processes().each_value() { |runningprocess|
					if(processname.match(runningprocess.program))
						Cfruby.controller.inform('debug', "\"#{processname.source}\" is running")
						return(runningprocess)
					end
				}
				
				Cfruby.controller.inform('debug', "\"#{processname.source}\" is not running")
				return(false)
			end
			

			# Calls has_process? after converting name to a Regexp
			def [](name)
				regex = name
				if(!regex.kind_of?(Regexp))
					regex = Regexp.new(Regexp.escape(name))
				end
				return has_process?(regex)				
			end
			
			
			# Calls has_process? after converting the symbol to a Regexp
			def method_missing(symbol, *args)
				if(args == nil or args.length == 0)
					regex = Regexp.new(Regexp.escape(symbol.id2name))
					return has_process?(regex)
				end

				super.method(symbol).call(args)
			end
		end
		
	end
	
end
