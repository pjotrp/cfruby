# Author:: David Powers
# Copyright:: July, 2005
# License:: Ruby License
#
# cfrubyscript defines a number of objects and wrapper methods desgined to streamline the
# writing of system amangement scripts directly in ruby using libcfruby.  In addition to the
# methods added to String and Array cfrubyscript predefines the following globals:
#  $os = Cfruby::OS::OSFactory.new.get_os()
#  $pkg = $os.get_package_manager()
#  $user = $os.get_user_manager()
#  $proc = $os.get_process_manager()
#  $sched = $os.get_scheduler()
#
# In addition, cfrubyscript pushes all of the major callable modules of libcfruby into the main namespace
#  FileOps = Cfruby::FileOps
#  Checksum = Cfruby::Checksum::Checksum
#  FileEdit = Cfruby::FileEdit
#  FileFind = Cfruby::FileFind
#  Exec = Cfruby::Exec
#  OS = Cfruby::OS
#
# Finally, cfrubyscript defines a default logger with levels and redirectable output that should be
# suitable for most system scripting.

require 'libcfruby/libcfruby'
require 'logger'


# Including cfrubyscript adds a number of new helper methods to String that are useful in
# cutting down the verbosity of system administration scripts.
class String

	# Calls Cfruby::Packages::PackageManager.install() on the String, allowing for:
	#	'apache'.install()
	def install()
		os = Cfruby::OS::OSFactory.new.get_os()
		pkg_manager = os.get_package_manager()
		pkg_manager.install(self)
	end


	# Calls Cfruby::Packages::PackageManager.uninstall() on the String, allowing for:
	#	'apache'.uninstall()
	def uninstall()
		os = Cfruby::OS::OSFactory.new.get_os()
		pkg_manager = os.get_package_manager()
		pkg_manager.uninstall(self)
	end


	# Calls Cfruby::Exec.exec on the String, allowing for:
	#	'/usr/local/bin/myprogram'.exec()
	def exec()
		return(Cfruby::Exec.exec(self))
	end

	# Calls Cfruby::FileEdit.set on the file named in the String
	def set(variable, value, options={})
		Cfruby::FileEdit.set(self, variable, value, options)
	end

	# Calls Cfruby::FileEdit.file_must_contain on the file named in the String
	def must_contain(str, options={})
		Cfruby::FileEdit.file_must_contain(self, str, options)
	end


	# Calls Cfruby::FileEdit.file_must_not_contain on the file named in the String
	def must_not_contain(str, options={})
		Cfruby::FileEdit.file_must_not_contain(self, str, options)
	end
	
	
	# Calls Cfruby::FileOps.chown_mod on the file named in the String
	def chown_mod(owner, group, mode, options = {})
		Cfruby::FileOps.chown_mod(self, owner, group, mode, options)
	end


	# Calls Cfruby::FileOps.chown on the file named in the String
	def chown(owner = Process::Sys.geteuid(), group = Process::Sys.getegid(), options = {})
		Cfruby::FileOps.chown(self, owner, group, options)
	end


	# Calls Cfruby::FileOps.chmod on the file named in the String
	def chmod(mode, options = {})
		Cfruby::FileOps.chmod(self, mode, options)
	end
	
	
	# Calls Cfruby::FileOps.mkdir on the file named in the String
	def mkdir(options = {})
		Cfruby::FileOps.mkdir(self, options)
	end
	
	
	# returns true if the file named in the String exists
	def exist?()
		return(FileTest.exist?(self))
	end
	alias exists? exist?


	# returns true if the file named in the String is empty (as defined in Cfruby::FileFind.find() 
	# when passed the option :empty => true)
	def fileempty?()
		Cfruby::FileFind.find(self, :empty => true) { |filename|
			return(true)
		}
		
		return(false)
	end
	
end


# Including cfrubyscript adds a number of new helper methods to Array that are useful in
# cutting down the verbosity of system administration scripts.
class Array

	# Calls Cfruby::Exec.exec() on each member, allowing for:
	#	['/usr/local/bin/myprogram', '/usr/local/bin/myotherprogram'].exec()
	def exec()
		self.each() { |command|
			Cfruby::Exec.exec(command)
		}
	end

	# Calls Cfruby::Packages::PackageManager.install() on each member, allowing for:
	#	['apache', 'php4', 'eruby'].install()
	def install()
		os = Cfruby::OS::OSFactory.new.get_os()
		pkg_manager = os.get_package_manager()

		self.each() { |pkgname|
			pkg_manager.install(pkgname)
		}
	end


	# Calls Cfruby::Packages::PackageManager.uninstall() on each member, allowing for:
	#	['apache', 'php4', 'eruby'].uninstall()
	def uninstall()
		os = Cfruby::OS::OSFactory.new.get_os()
		pkg_manager = os.get_package_manager()

		self.each() { |pkgname|
			pkg_manager.uninstall(pkgname)
		}
	end


	# Calls Cfruby::FileOps.mkdir on each member, allowing for:
	#	['/var/service', '/etc/scripts'].mkdir()
	def mkdir(options = {})
		self.each() { |filename|
			Cfruby::FileOps.mkdir(filename, options)
		}
	end


	# Calls Cfruby::FileOps.create on each member, allowing for:
	#	['/etc/rc.conf', '/etc/resolv.conf'].create('root', 'wheel')
	def create(owner = Process::Sys.geteuid(), group = Process::Sys.getegid(), mode = 0600)
		self.each() { |filename|
			Cfruby::FileOps.create(filename, owner, group, mode)
		}
	end
	
	
	# Calls Cfruby::FileOps.chown_mod on each member, allowing for:
	#	['/usr/local/etc/exim', '/var/service'].chown_mod('root', 'wheel', 'u=rwX,go-rwx', :recursive => true)
	def chown_mod(owner, group, mode, options = {})
		self.each() { |filename|
			Cfruby::FileOps.chown_mod(filename, owner, group, mode, options)
		}
	end
	
	
	# Calls Cfruby::FileOps.chown on each member, allowing for:
	#	['/usr/local/etc/exim', '/var/service'].chown_mod('root', 'wheel', :recursive => true)
	def chown(owner = Process::Sys.geteuid(), group = Process::Sys.getegid(), options = {})
		self.each() { |filename|
			Cfruby::FileOps.chown(filename, owner, group, options)
		}
	end
	
	
	# Calls Cfruby::FileOps.chmod on each member, allowing for:
	#	['/usr/local/etc/exim', '/var/service'].chown_mod('u=rwX,go-rwx', :recursive => true)
	def chmod(mode, options = {})
		self.each() { |filename|
			Cfruby::FileOps.chmod(filename, mode, options)
		}
	end
end


module Cfruby

	module Script

	# defines an Observer that simple returns false to handle_message to NOOP all cfruby calls
	class NOOPObserver
			def handle_message(message)
			  return(false)
			  end
	end

		# Defines a basic Observer to the cfrubycontroller that is set implicitly when cfrubyscript is required
		class Observer

			def initialize(filename, level)
				
				@levelmap = Hash.new()
				@levelmap['intention'] = 4
				@levelmap['debug'] = 4
				@levelmap['verbose'] = 3
				@levelmap['info'] = 2
				@levelmap['warn'] = 1
				@levelmap['error'] = 0
				@levelmap['fatal'] = 0
				
				@reverselevelmap = Hash.new()
				@reverselevelmap[4] = 'debug'
				@reverselevelmap[3] = 'verbose'
				@reverselevelmap[2] = 'info'
				
				if(level.kind_of?(Numeric))
					level = level.to_i()
					if(level < 0 or level > 4)
						raise(ArgumentError, "log level must be between 0 and 4")
					end
				else
					case(level)
						when('debug')
							level = 4
						when('verbose')
							level = 3
						when('info')
							level = 2
						when('warn')
							level = 1
						when('error')
							level = 0
						when('fatal')
							level = 0
						else
							raise(ArgumentError, "Unknown log level \"#{level}\"")
					end
				end

				@level = Array.new()
				@level << 'exception'
				if(level > 0)
					@level << 'warn'
				end
				if(level > 1)
					@level << 'info'
				end
				if(level > 2)
					@level << 'verbose'
				end
				if(level > 3)
					@level << 'debug'
					@level << 'intention'
				end

				if(filename == nil)
					@logger = Logger.new(STDOUT)
				else
					@logger = Logger.new(filename, 5, 1048576)
				end
				@errlogger = Logger.new(STDERR)
			end

			def handle_message(message)
				messagelevel = message.type

				# increase the level of the message based on the call depth if it is info or higher
				# and it is a finished attempt
				currentlevel = @levelmap[message.type].to_i()
				if(message.tags.has_key?('attemptdone'))
					bumplevel = calculate_bump(message.caller) - 1
					if(bumplevel > 0)
						newlevel = currentlevel + bumplevel
						if(newlevel > 4)
							messagelevel = 'debug'
						else
							messagelevel = @reverselevelmap[newlevel] 
						end
					end
				end

				if(@level.include?(messagelevel))
					@logger << "#{Time.now.strftime("%Y-%m-%d %H:%M")} - (#{messagelevel}) #{message.message}\n"
				end
				
				# handle install messages special-like
				if(message.tags.has_key?('install') and message.type == 'intention')
					@logger << "#{Time.now.strftime("%Y-%m-%d %H:%M")} - (#{message.type}) #{message.message}\n"
				end

				if(message.type == 'exception')
					@errlogger << "#{Time.now.strftime("%Y-%m-%d %H:%M")} - (#{message.type}) #{message.message}\n"
				end
			end
			
			
			private
			
			# run through a Kernel.caller returned stack and calculate how many calls to
			# attempt in flowmonitor.rb have been nested
			def calculate_bump(stack)
				calls = 0
				last = ''
				stack.each() { |s|
					if(s =~ /\/flowmonitor\.rb:/)
						if(last !~ /\/flowmonitor\.rb:/)
							calls = calls + 1
						end
					end
					last = s
				}
				
				return(calls)
			end

		end

	end

end


# sets up an observer that prevents any actual actionf rom being taken by the cfruby library
def set_cfruby_noop
  Cfruby.controller.register(Cfruby::Script::NOOPObserver.new())
end

# sets the filename and level for cfrubyscript logging - defaults to stdout and 'info'.	 Level may
# be given as a number between 0 and 4 or a named level ('debug', 'verbose', 'info', 'warn')
def set_cfruby_log(filename, level=1)
	Cfruby.controller.unregister($cflogger)
	$cflogger = Cfruby::Script::Observer.new(filename, level)
	Cfruby.controller.register($cflogger)
end

$cflogger = Cfruby::Script::Observer.new(nil, 1)
Cfruby.controller.register($cflogger)

# define global variables for the major system specific items
$os = Cfruby::OS::OSFactory.new.get_os()
$pkg = $os.get_package_manager()
$user = $os.get_user_manager()
$proc = $os.get_process_manager()
$sched = $os.get_scheduler()

# push all of the major callable modules into the main namespace
FileOps = Cfruby::FileOps
Checksum = Cfruby::Checksum::Checksum
FileEdit = Cfruby::FileEdit
FileFind = Cfruby::FileFind
Exec = Cfruby::Exec
OS = Cfruby::OS

