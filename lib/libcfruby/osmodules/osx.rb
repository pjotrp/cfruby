require 'libcfruby/os'


module Cfruby

	module OS

		class OSXOS < Cfruby::OS::OS

			def initialize()
				@keys = Hash.new()

				@keys['name'] = 'FreeBSD'
				@keys['osx'] = true
				@keys['OSX'] = true
				@keys['MacOS'] = true
				@keys['darwin'] = true
				@keys['Darwin'] = true

				unameoutput = `/usr/bin/uname -v`
				@keys['version'] = unameoutput[/Darwin Kernel Version ([^ ]+):/, 1]

				@keys['hostname'] = `/bin/hostname`.strip
			end


			# Returns a UserManager object specific to OS X
			def get_user_manager()
				return(Users::OSXUserManager.new())
			end


			# returns an object implementing the PackageManager interface as appropriate
			# for the default package management system for a given OS
			def get_package_manager()
				if(File.executable?('/sw/bin/fink'))
					return(Packages::FinkPackageManager.new())
				end

				return(nil)
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
		
		# Implementation of the UserManger for OS X
		class OSXUserManager < UserManager

      DSCLBIN = '/usr/bin/dscl'

			# adds a user to the system.  If userinfo is a string then it will
			# add the named user with an optional uid.  If userinfo is an actual
			# UserInfo object then uid is ignored and everything possible will be
			# used from userinfo (or generated if not supplied)
			def add_user(userinfo, password=nil, uid=nil)
				newuser = UserInfo.new()
				newuser.username = nil
				newuser.uid = nil
				newuser.gid = nil
				newuser.fullname = nil
				newuser.shell = nil
				newuser.homedir = nil

				if(userinfo.respond_to?(:username))
					if(userinfo.username == nil)
						raise(BadUsernameError, "No username given")
					end
					newuser.username = userinfo.username
					newuser.uid = userinfo.uid
					newuser.gid = userinfo.gid
					newuser.fullname = userinfo.fullname
					newuser.shell = userinfo.shell
					newuser.homedir = userinfo.homedir
				else
					newuser.username = userinfo.to_s()
					newuser.uid = uid
				end

				Cfruby.controller.attempt("Adding user \"#{newuser.username}\"", 'destructive') {
					if(newuser.uid == nil)
						lastuid = `/usr/bin/nidump passwd . | /usr/bin/cut -d: -f3 | /usr/bin/sort -n | /usr/bin/tail -n 1`
						newuser.uid = lastuid.to_i() + 1
						if(newuser.uid == 0)
							raise(AddUserError, "Error generating new uid")
						end
					end

					if(newuser.gid == nil)
						newuser.gid = newuser.uid
					end

					`/usr/bin/niutil -create . /users/#{newuser.username}`
					`/usr/bin/niutil -createprop . /users/#{newuser.username} passwd`
					`/usr/bin/niutil -createprop . /users/#{newuser.username} gid #{newuser.gid.to_i()}`
					`/usr/bin/niutil -createprop . /users/#{newuser.username} uid #{newuser.uid.to_i()}`
					`/usr/bin/niutil -createprop . /users/#{newuser.username} shell #{newuser.shell.to_s()}`
					`/usr/bin/niutil -createprop . /users/#{newuser.username} home "#{newuser.homedir.to_s()}"`
					`/usr/bin/niutil -createprop . /users/#{newuser.username} realname "#{newuser.fullname.to_s()}"`
					`/usr/bin/niutil -createprop . /users/#{newuser.username} _shadow_passwd`

					# make the home directory
					if(newuser.homedir != nil and !File.exist?(newuser.homedir.to_s()))
						FileUtils.mkdir_p(newuser.homedir.to_s())
					end

					# set the password
					if(password != nil)
						set_password(newuser.username, password)
					end
				}
			end


			# adds a group to the system with an optional fixed uid
			def add_group(groupname, gid=nil)
				Cfruby.controller.attempt("Adding group \"#{groupname}\"", 'destructive') {
					`/usr/bin/niutil -create . /groups/#{groupname}`

					newgroupid = gid
					if(newgroupid == nil)
						lastgid = `/usr/bin/nidump group . | /usr/bin/cut -d: -f3 | /usr/bin/sort -n | /usr/bin/tail -n 1`
						newgroupid = lastgid.to_i() + 1
					end				

					`/usr/bin/niutil -createprop . /groups/#{groupname} gid #{newgroupid}`
					`/usr/bin/niutil -createprop . /groups/#{groupname} users`
				}
			end


			# deletes a user from the system
			def delete_user(username, removehome=false)
				Cfruby.controller.attempt("Removing user \"#{username}\"", 'nonreversible', 'destructive') {
					# get the homedir before we destroy the user if we are going to delete it
					# don't actually destroy the directory yet because we may fail to actually
					# delete the user
					homedir = nil
					if(removehome)
						homedir = `/usr/bin/niutil -readprop . /users/#{username} home`.strip()
					end

					# FIXME - add check for error return code
					output = Cfruby::Exec.exec("/usr/bin/niutil -destroy . /users/#{username}")
					if(output[1].join().strip() != '')
						print(output[1].join("\n"))
						raise(DeleteUserError, "Unable to delete user \"#{username}\"")
					end

					if(homedir != nil)
						FileUtils.rmdir(homedir)
					end
				}
			end


			# deletes a group from the system
			def delete_group(group)
			end


			# returns true if a user exists, false otherwise
			def user?(username)
				if(users.has_key?(username))
					return(true)
				end

				return(false)
			end


			# returns true if group exists, false otherwise
			def group?(group)
				if(groups.has_key?(group))
					Cfruby.controller.inform('debug', "group \"#{group}\" exists")
					return(true)
				end

				Cfruby.controller.inform('debug', "group \"#{group}\" does not exist")
				return(false)
			end


			# returns a list of all the users on the system
			def users()
				users = UserList.new()

        if dscl?
          # The dscl version is still limited
          idlist = `#{DSCLBIN} . -list /Users UniqueID`
          grouplist = `#{DSCLBIN} . -list /Users PrimaryGroupID`
          idlist.each do | line |
            user = UserInfo.new()
            name,id = line.split
            user.username = name
            user.uid = id.to_i
            users[name] = user
          end
        else
          # get the list of users using niutil
          textlist = `niutil -list . /users`
          textlist.each() { |line|
            line.strip!()
            user = UserInfo.new()
            user.username = line[/^[0-9]+\s+(\S+)$/, 1]
            userlist = `niutil -read . /users/#{user.username}`
            userlist.each() { |subline|
              subline.strip!()
              case(subline)
                when(/^home:/)
                  user.homedir = subline[/:\s*(.*)$/, 1]
                when(/^uid:/)
                  user.uid = subline[/:\s*(.*)$/, 1].to_i()
                when(/^gid:/)
                  user.gid = subline[/:\s*(.*)$/, 1].to_i()
                when(/^realname:/)
                  user.fullname = subline[/:\s*(.*)$/, 1]
              end
            }
            users[user.username] = user
          }
        end
				return(users)
			end


			# returns a list of all the groups on the system
			def groups()
				groups = GroupList.new()

				# get the list of users using niutil
				textlist = `niutil -list . /groups`
				textlist.each() { |line|
					line.strip!()
					group = GroupInfo.new()
					group.groupname = line[/^[0-9]+\s+(\S+)$/, 1]
					grouplist = `niutil -read . /groups/#{group.groupname}`
					grouplist.each() { |subline|
						subline.strip!()
						case(subline)
							when(/^gid:/)
								group.gid = subline[/:\s*(.*)$/, 1].to_i()
						end
					}

					groups[group.groupname] = group
				}

				return(groups)
			end

      def dscl?
        File.exist?(DSCLBIN)
      end
		end

	end


	module Packages

		# PackageManager implementation for fink for OS X
		class FinkPackageManager < PackageManager

			def initialize()
				# search for fink
				@finkbin = '/sw/bin/fink'
			end

			# Installs the latest version of the named package
			def install(packagename, force=false)
				packagename.strip!()

				# FIXME - check to see if it is already installed

				Cfruby.controller.attempt("Installing \"#{packagename}\"", 'destructive', 'unknown', 'install') {
					`#{@finkbin} install '#{packagename.gsub(/(\')/, "\\\1")}'`
				}
			end


			# Uninstalls the named package
			def uninstall(packagename)
				pacakgename.strip!()

				Cfruby.controller.attempt("Uninstalling \"#{packagename}\"", 'destructive', 'unknown') {
					`#{finkbin} remove '#{packagename.gsub(/(\')/, "\\\1")}'`
				}
			end


			# Returns a PackageList object that contains key value pairs for
			# every installed package where the key is the package name and
			# the value is a PackageInfo object
			def installed_packages()
				installedpackagelist = `#{@finkbin} list -i`

				installedpackages = PackageList.new()
				installedpackagelist.each_line() { |line|
					linearr = line.split()
					installedpackages[linearr[1]] = PackageInfo.new()
					installedpackages[linearr[1]].name = linearr[1]
					installedpackages[linearr[1]].version = linearr[2]
					installedpackages[linearr[1]].description = linearr[3]
					installedpackages[linearr[1]].installed = true
				}

				return(installedpackages)
			end


			# Returns a PackageList object that contains key value pairs for
			# every package (installed or not) where the key is the package name and
			# the value is a PackageInfo object
			def packages()
				packages = installed_packages()

				packagelist = `#{@finkbin} list -n`

				packagelist.each_line() { |line|
					linearr = line.split()
					packages[linearr[0]] = PackageInfo.new()
					packages[linearr[0]].name = linearr[0]
					packages[linearr[0]].version = linearr[1]
					packages[linearr[0]].description = linearr[2]
				}

				return(packages)
			end

		end
	
	end
	
end
