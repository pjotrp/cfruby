require 'libcfruby/os'


module Cfruby

	module OS
		
		class FreeBSDOS < Cfruby::OS::OS

			def initialize()
				@keys = Hash.new()

				@keys['name'] = 'FreeBSD'
				@keys['freebsd'] = true
				@keys['FreeBSD'] = true
				@keys['FREEBSD'] = true

				unameoutput = `uname -v`
				@keys['version'] = unameoutput[/FreeBSD ([^ ]+)/, 1]

				@keys['hostname'] = `/bin/hostname`.strip
			end


			# returns an object implementing the PackageManager interface as appropriate
			# for the default package management system for a given OS
			def get_package_manager()
				return(Packages::FreeBSDPackageManager.new())
			end


			# Returns a UserManager object specific to FreeBSD
			def get_user_manager()
				return(Users::FreeBSDUserManager.new())
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
				# If we are requesting jail status, we consult the jailed? function
				if key == 'jailed'
					return(jailed?())
				end

				return(@keys[key])
			end


			# an alternative to calling lookup
			def [](key)
				return(lookup(key))
			end


			# return true, false, or raises an exception if jail status can't be determing
			def jailed?()
				# Get our FreeBSD major version
				version = @keys['version'][0,1].to_i()

				# Our options are somewhat limited if we are freebsd 4.x, so we'll run a few tests
				if version == 4
					# Easiest test, we check for a real kernel, since no jail should have a real one
					if File.exists?('/kernel') && !File.symlink?('/kernel')
						return false
					end

					# Second test, we check the process table
					psoutput = `ps ax`

					# If every line has a J in it, it's likely a jail (the first line isn't a process, that's why the jcount starts at 1)
					lines = psoutput.split("\n")
					jcount = 1
					lines.each() { |line|
						if line =~ /J/
							jcount += 1
						end
					}
					if lines.size == jcount
						return true
					end

					# Last resort, we see if 'injail' exists and if so, we check the return code from that
					if File.exists?('/usr/local/bin/injail')
						`injail`
						if $?.exitstatus == 0
							return true
						elsif $?.exitstatus == 1
							return false
						else
							raise(OSFreeBSDJailError, "/usr/local/bin/injail exists but couldn't determine jail status (error code 2)")
						end
					end

					# If we got this far, we can't figure out if we are in a jail and we lob an error
					raise(OSFreeBSDJailError, "Couldn't determine jail status with any test")					

				end

				# If we are FreeBSD >5, we can consult sysctl (we think)
				if version >= 5
					sysctloutput = `sysctl security.jail.jailed`
					if sysctloutput =~ /1/
						return true
					else
						return false
					end
				end

			end

		end
		
	end


	module Users
		
		# Implementation of the UserManager class for generic FreeBSD systems
		class FreeBSDUserManager < UserManager

			# adds a user to the system with an optional fixed uid
			def add_user(user, password=nil, uid=nil)
				Cfruby.controller.attempt("Adding user \"#{user.to_s}\"", 'destructive') {
					newuser = nil
					if(!user.respond_to?(:username))
						newuser = UserInfo.new()
						newuser.username = user.to_s
						if(uid != nil)
							newuser.uid = uid.to_i()
						end
						# FIXME: Handling the addition of new users needs to be better than this
						# FIXME: Assuming that /home/<username> is the dir is silly, we should use -m somehow
						# FIXME: but still make it overridable.
						newuser.homedir = "/home/#{newuser.username}"
					else
						newuser = user
					end

          if(users[newuser.username])
            Cfruby.controller.attempt_abort("user \"#{user.to_s}\" already exists")
          end

					if(uid == nil)
						`/usr/sbin/pw useradd #{shellescape(newuser.username)}`
					else
						`/usr/sbin/pw useradd #{shellescape(newuser.username)} -u #{uid.to_i()}`
					end

					if(newuser.gid != nil)
						`/usr/sbin/pw usermod #{shellescape(newuser.username)} -g #{newuser.gid}`
					end
					if(newuser.fullname != nil)
						`/usr/sbin/pw usermod #{shellescape(newuser.username)} -n '#{shellescape(newuser.fullname)}'`
					end
					if(newuser.shell != nil)
						`/usr/sbin/pw usermod #{shellescape(newuser.username)} -s #{newuser.shell}`
					end
					if(newuser.homedir != nil)
						`/usr/sbin/pw usermod #{shellescape(newuser.username)} -d '#{shellescape(newuser.homedir)}' -m`
					end

					# set the password
					if(password != nil)
						set_password(newuser.username, password)
					end
				}
			end


			# adds a group to the system with an optional fixed uid
			def add_group(group, gid=nil)
				Cfruby.controller.attempt("Adding group \"#{group}\"", 'destructive') {
					# Only add the group if it's not already there
					if !group?(group)
						if(gid == nil)
							`/usr/sbin/pw groupadd '#{shellescape(group)}'`
						else
							`/usr/sbin/pw groupadd '#{shellescape(group)}' -g #{gid.to_i()}`
						end
					end
				}
			end


			# Add a user to a group   
			def add_user_to_group(username, groupname)
				# Check for validity first
				super(username, groupname)


				`/usr/sbin/pw groupmod #{shellescape(groupname)} -m #{shellescape(username)}`
			end


			# returns true if a user exists, false otherwise
			def user?(user)
				username = ""
				if(user.respond_to?(:username))
					username = user.username
				else
					username = user
				end

				output = Exec::exec("/usr/sbin/pw showuser '#{shellescape(username)}'")
				if(output[0][0] =~ /^#{Regexp.escape(username)}:/)
					return(true)
				else
					return(false)
				end
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
						match = regex.match(line)
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
						`pw userdel #{username} -r`
					else
						`pw userdel #{username}`
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


			# Set the password using the pw script
			def set_password(user, password)
				`echo "#{shellescape(password)}" | /usr/sbin/pw usermod #{shellescape(user)} -h 0`
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


	module Packages

		# PackageManager implementation for the FreeBSD ports system
		class FreeBSDPackageManager < PackageManager

			# Return true if the package is installed
			# Checks the origin as well
			def installed?(package)
				Cfruby.controller.inform('debug', "Getting installed? status of \"#{package}\" by origin")

				installed_packages.each_value() { |packageinfo|
					if(packageinfo.origin == package)
						return(true)
					end
				}

				return(super(package))
			end


			# Installs the latest version of the named package
			def install(packagename, force=false)
				packagename.strip!()

				# determine whether to use portinstall or pkg_add
				if(test(?x, '/usr/local/sbin/portinstall'))
					@portadd = '/usr/local/sbin/portinstall -M BATCH=YES'
				else
					@portadd = '/usr/sbin/pkg_add -r'
				end

				if force
					Cfruby.controller.attempt("Installing \"#{packagename}\"", 'destructive', 'unknown', 'install') {
						Exec.exec("#{@portadd} -f #{packagename}")
					}
					
					return(true)
				elsif !installed?(packagename)
					Cfruby.controller.attempt("Installing \"#{packagename}\"", 'destructive', 'unknown', 'install') {
						output = Exec.exec("#{@portadd} #{packagename}")
						if(output[1].length > 0)
							# portinstall doesn't have useful positive feedback, so we check known negatives
						       	if (output[1][0] =~ /\*\* No such installed package or port/)
								raise(InstallError, "#{packagename} not found by \"#{@portadd}\"")
							end
							if(output[1][0] =~ /\*\* Port marked as IGNORE:/)
								raise(InstallError, "#{packagename} is marked as IGNORE \"#{@portadd}\" for reason: #{output[1][1]}")
							end
							if(output[1][0] =~ /\*\* Command failed/)
								raise(InstallError, "#{packagename} installation failed")
							end
						end
					}
					
					return(true)
				end
				
				return(false)
			end


			# Uninstalls the named package
			def uninstall(packagename)
				packagename.strip!()

				Cfruby.controller.attempt("Uninstalling \"#{packagename}\"", 'destructive', 'unknown') {
					# we have to iterate through all the attributes (name, name-version, origin) to properly delete what this could be.
					packagetodelete = nil
					installed_packages().each_value() { |package|
						if(packagename == package.name) or (packagename == "#{package.name}-#{package.version}") or (packagename == package.origin)
							packagetodelete = package.name + '-' + package.version
							break
						end
					}

					if packagetodelete.nil?
						Cfruby.controller.attempt_abort("package \"#{packagename}\": not installed")
					else
						Exec.exec("/usr/sbin/pkg_delete #{packagetodelete}`")
					end
				}

			end


			# Returns a PackageList object that contains key value pairs for
			# every installed package where the key is the package name and
			# the value is the currently installed version.  See PackageList for
			# more information
			def installed_packages()
				packages = PackageList.new()
				packageregex = /([^ ]+)-([^- ]+)\s+(.*)/

				installedpackageslist = `/usr/sbin/pkg_info`
				installedpackageslist.each_line() { |line|
					line.strip!()
					match = packageregex.match(line)
					if(match != nil)
						name = match[1]
						version = match[2]
						description = match[3]

						packages[name] = PackageInfo.new()
						packages[name].name = name
						packages[name].version = version
						packages[name].description = description
						packages[name].origin = `/usr/sbin/pkg_info -q -o #{name}-#{version}`.strip()
					end
				}

				return(packages)
			end


			# Returns a PackageList object that contains key value pairs for
			# every package (installed or not) where the key is the package name and
			# the value is a PackageInfo object
			def packages()
				packages = PackageList.new()

				os = Cfruby::OS::OSFactory.new().get_os()
				indexfile = '/usr/ports/INDEX'
				if(os['version'] =~ /^5/)
					indexfile = '/usr/ports/INDEX-5'
				end

				# run make fetchindex if the index doesn't exist
				if(!test(?e, indexfile))
					Exec.exec("cd /usr/ports && make fetchindex")
				end

				# parse /usr/ports/INDEX to get a listing
				File.open(indexfile, File::RDONLY) { |fp|
					fp.each_line() { |line|
						line = line.split(/\|/)
						name = line[0][/^(.*)-[^-]+/, 1]
						version = line[0][/-([^-]+)$/, 1]
						description = line[3]

						packages[name] = PackageInfo.new()
						packages[name].name = name
						packages[name].version = version
						packages[name].description = description
						packages[name].origin = line[1]
					}
				}

				return(packages)
			end

		end
				
	end
	
end
