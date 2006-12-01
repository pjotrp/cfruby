# OS module and related classes.  OS is primarily responsible for providing abstract, OS independant
# interfaces that are implemented for each supported OS.
#
# Author:: David Powers
# Copyright:: November, 2004
# License:: Ruby License

require 'libcfruby/cfruby'
require 'libcfruby/packages'
require 'libcfruby/processes'
require 'libcfruby/users'
require 'libcfruby/scheduler'


module Cfruby

	module OS
	
		# Base class for all OS module Exceptions
		class OSError < CfrubyError
		end
		
		# Raised in the event that the OS type cannot be detected
		class OSUndetectableError < OSError
		end
		
		# Raised in the event that we can't figure out jail status for FreeBSD
		class OSFreeBSDJailError < OSError
		end
		
		
		# Uses OSFactory to return an appropriate OS object
		def OS.get_os()
			factory = Cfruby::OS::OSFactory.new()
			return(factory.get_os())				
		end


		# OSFactory implements the Factory pattern and uses a set of heuristics to
		# return an appropriate class of the OS interface
		class OSFactory
		
			# Uses a set of heuristics to determine the OS it is running under and
			# attempts to return an object implementing the OS interface that matches
			# that OS
			def get_os()
				Cfruby.controller.inform('debug', 'Retrieving an OS object')
				
				# try to use uname to get the OS
				os = set_with_uname()
				if(os != nil)
					Cfruby.controller.inform('debug', "OS #{os['name']}")
					return(os)
				end
				
				# if we failed, try RUBY_PLATFORM
				os = set_with_RUBY_PLATFORM()
				if(os != nil)
					Cfruby.controller.inform('verbose', "OS #{os['name']}")
					return(os)
				end
				
				raise(OSUndetectableError, "OS is not recognized!")
			end
			
			private
			
			# Attempts to set os variables based on RUBY_PLATFORM
			def set_with_RUBY_PLATFORM()
				# try to use RUBY_PLATFORM to get the OS type
				# Darwin
				Cfruby.controller.inform('debug', "Platform reported by Ruby interpreter: #{RUBY_PLATFORM}")
				case
					when(RUBY_PLATFORM =~ /darwin/i)
						return(OSXOS.new())
					when(RUBY_PLATFORM =~ /freebsd/i)
						return(FreeBSDOS.new())
					when(RUBY_PLATFORM =~ /openbsd/i)
						return(OpenBSDOS.new())
					when(RUBY_PLATFORM =~ /linux/i)
						return(Linux.new())
				end
				
				Cfruby.controller.inform('debug', "Unknown platform (by RUBY_PLATFORM)")
				return(nil)
			end
			
			
			# Attempts to set os variables based on the return of the uname command
			def set_with_uname()
				# try the os type
				unameos = `uname -s`
				Cfruby.controller.inform('debug', "Platform reported by uname: #{unameos}")
				if(unameos =~ /^\s*freebsd/i)
					return(FreeBSDOS.new())
				end
				if(unameos =~ /^\s*darwin/i)
					return(OSXOS.new())
				end
				if(unameos =~ /^\s*linux/i)
					return(Linux.new())
				end
				
				Cfruby.controller.inform('debug', "Unknown platform (by uname)")
				return(nil)
			end


		end
		
		
		# The OS class serves only as an in-code description of the OS interface.  It can be
		# subclassed, but the methods do nothing useful
		class OS
						
			# Returns an object implementing the PackageManager interface as appropriate
			# for the default package management system for a given OS
			def get_package_manager()
				return(Packages::PackageManager.new())
			end
			
			
			# Returns an object implementing the UserManager interface as appropriate
			# for a given OS
			def get_user_manager()
				return(Users::UserManager.new())
			end
			
			
			# Returns an object implementing the ProcessManager interface as appropriate
			# for a given OS
			def get_process_manager()
				return(Processes::ProcessManager.new())
			end
			
			
			# Returns an object implementing the Scheduler interface as appropriate for
			# a given OS
			def get_scheduler()
				return(Scheduler::Scheduler.new())
			end
			
			# Returns the value of the given key for this OS.  At a minimum an OS should
			# provide the following:
			# <tt>name</tt>:: returns the name of the OS
			# <tt>version</tt>:: the version of the OS
			# <tt>osname</tt>:: e.g. freebsd, linux, windows, etc - these should return true and be case insensitive to allow
			#	lookups of the form lookup('Windows')
			# <tt>hostname</tt>:: the hostname of the machine
			# In addition to the above name and version should be implemented as get methods for
			# convenience
			def lookup(key)
				return(nil)
			end
			
			
			# An alternative to calling lookup
			def [](key)
				return(lookup(key))
			end


			# Call lookup on anything we have no real method for
			def method_missing(symbol, *args)
				if(args == nil or args.length == 0)
					return lookup(symbol.id2name)
				end
				
				super.method(symbol).call(args)
			end


			# Returns the name-version of the OS
			def to_s()
				return("#{lookup('name')} #{lookup('version')}")
			end
			
		end
		
	end
	
end

# The modules depend on interfaces defined in os, so they must be required at the bottom
require 'libcfruby/osmodules/all'

