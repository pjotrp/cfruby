require 'libcfruby/os'


module Cfruby

	module OS
		
		class Linux < Cfruby::OS::OS

			def initialize()
				@keys = Hash.new()

				@keys['name'] = 'Linux'

				unameoutput = `uname -v`
				@keys['version'] = `cat /proc/version`.strip

				if File.exist? '/etc/HOSTNAME'
					@keys['hostname'] = `cat /etc/HOSTNAME`.strip
				elsif File.exist? '/etc/hostname'
					@keys['hostname'] = `cat /etc/hostname`.strip
				end
				# ---- figure out the distribution
				@keys['distribution'] = 'unknown'
				version = `cat /proc/version`.strip
				@keys['distribution'] = 'debianlinux' if version =~ /Debian/ or File.exist? '/etc/debian_version'
				@keys['distribution'] = 'rocklinux' if version =~ /[Rr]ock/
				Cfruby.controller.inform('debug', "Distro #{self['distribution']}")
			end


			# returns an object implementing the PackageManager interface as appropriate
			# for the default package management system for a given OS
			def get_package_manager()
				# look for portage
				if(File.executable?('/usr/bin/emerge') and File.directory?('/usr/portage'))
					return(Packages::PortagePackageManager.new())
				end

				# look for apt
				if(File.executable?('/usr/bin/apt-get'))
					return(Packages::AptPackageManager.new())
				end
				Cfruby.controller.inform('debug', "No package manager available")

				return(nil)
			end


			# Returns a UserManager object specific to OS X
			def get_user_manager()
				return(Users::LinuxUserManager.new())
			end


			# returns the value of the given key for this OS.  At a minimum an OS should
			# provide the following:
			# name:: returns the name of the OS
			# version:: the version of the OS
			# osname:: e.g. freebsd, linux, windows, etc - these should return true and be case insensitive to allow
			#	lookups of the form lookup('Windows')
			# In addition to the above name and version should be implemented as getter methods for
			# convenience
			def lookup(key)
				return(@keys[key])
			end


			# an alternative to calling lookup
			def [](key)
				return(lookup(key))
			end

		end
		
	end


	module Users
		
		# Implementation of the UserManager class for generic linux systems
		class LinuxUserManager < UserManager

			# adds a user to the system with an optional fixed uid
			def add_user(user, password=nil, uid=nil)
				newuser = nil
				if(!user.respond_to?(:username))
					newuser = UserInfo.new()
					newuser.username = user.to_s
					if(uid != nil)
						newuser.uid = uid.to_i()
					end
				else
					newuser = user
				end

				Cfruby.controller.attempt("Adding user \"#{newuser.username}\"", 'destructive') {
					if(uid == nil)
						`/usr/sbin/useradd #{shellescape(newuser.username)}`
					else
						`/usr/sbin/useradd #{shellescape(newuser.username)} -u #{uid.to_i()}`
					end

					if(newuser.gid != nil)
						`/usr/sbin/useradd -D #{shellescape(newuser.username)} -g #{newuser.gid}`
					end
					if(newuser.shell != nil)
						`/usr/sbin/useradd -D #{shellescape(newuser.username)} -s #{newuser.shell}`
					end
					if(newuser.homedir != nil)
						`/usr/sbin/useradd #{shellescape(newuser.username)} -b '#{shellescape(newuser.homedir)}' -m`
					end

					# set the password
					if(password != nil)
						set_password(newuser.username, password)
					end
				}
			end


			# adds a group to the system with an optional fixed uid
			def add_group(group, gid=nil)
				Cfruby.controller.attempt("Adding group \"#{groupname}\"", 'destructive') {
					if(gid == nil)
						`/usr/sbin/pw groupadd '#{shellescape(group)}'`
					else
						`/usr/sbin/pw groupadd '#{shellescape(group)}' -g #{gid.to_i()}`
					end
				}
			end


			# returns true if group exists, false otherwise
			def group?(group)
				return(infile(group, '/etc/group'))
			end


			# returns a list of all the users on the system
			def users()
				userlist = UserList.new()

				File.open('/etc/passwd', File::RDONLY) { |fp|
					regex = /^([a-zA-Z0-9-]+):[^:]+:([0-9]+):([0-9]+):([^:]*):([^:]*):([^:]*)$/
					fp.each_line() { |line|
						match = regex.match(line.chomp)
						if(match != nil)
							user = UserInfo.new()
							user.username = match[1]
							user.uid = match[2].to_i()
							user.gid = match[3].to_i()
							user.fullname = match[4]
							user.homedir = match[5]
							user.shell = match[6]
							userlist[user.username] = user
						end
					}
				}

				return(userlist)
			end


			# returns a list of all the groups on the system
			def groups()
				userlist = users()

				grouplist = GroupList.new()
				File.open('/etc/group', File::RDONLY) { |fp|
					regex = /^([a-zA-Z0-9-]+):[^:]+:([0-9]+):([^:]*)/
					fp.each_line() { |line|
						match = regex.match(line)
						if(match != nil)
							group = GroupInfo.new()
							group.groupname = match[1]
							group.gid = match[2].to_i()
							group.members = UserList.new()
							if(match[3] != nil)
								users = match[3].split(/,/)
								users.each() { |username|
									if(userlist.has_key?(username))
										group.members[username] = userlist[username]
									end
								}
							end
							grouplist[group.groupname] = group
						end
					}
				}

				return(grouplist)
			end


			# deletes a user from the system
			def delete_user(user, removehome=false)
				username = nil
				if(user.respond_to?(:username))
					username = user.username
				else
					username = user.to_s
				end
				Cfruby.controller.attempt("Removing user \"#{username}\"", 'nonreversible', 'destructive') {
					if(removehome == true)
						`/usr/sbin/userdel #{username} -r`
					else
						`/usr/sbin/userdel #{username}`
					end
				}
			end


			# deletes a group from the system
			def delete_group(group)
				groupname = nil
				if(group.respond_to(:groupname))
					groupname = group.groupname
				else
					groupname = group
				end

				`pw groupdel #{groupname}`
			end


			protected


			def shellescape(str)
				return(str.gsub(/(')/, "\\\1"))
			end


			# returns true if the specified str is in the file in the form of
			# str:... such as in /etc/passwd or /etc/group
			def infile(str, filename)
				regex = Regexp.new("^#{Regexp.escape(str)}:")
				File.open(filename, File::RDONLY) { |fp|
					fp.each_line() { |line|
						if(regex.match(line))
							return(true)
						end
					}
				}

				return(false)
			end
		end
		
	end
	
end
