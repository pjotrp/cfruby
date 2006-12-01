# The Users module defines classes and methods for retrieving and editing user and group information
#
# Author:: David Powers
# Copyright:: January, 2005
# License:: Ruby License

require 'libcfruby/exec'
require 'ostruct'
require 'tempfile'


module Cfruby
	
	# The Users module defines classes and methods for retrieving and editing user and group information
	module Users
	
		# Base exception for the Users module
		class UsersError < Exception
		end
		
		# Raised when a user could not be added
		class AddUserError < UsersError
		end
		
		# Raised when a user could not be deleted
		class DeleteUserError < UsersError
		end

		# Raised when a bad username is given
		class BadUsernameError < UsersError
		end

		# Raised when an error occurs during a password change
		class ChangePasswordError < UsersError
		end
		
		# Raised when a user could not be found
		class NoSuchUserError < UsersError
		end
		
		# Raised when a group could not be found
		class NoSuchGroupError < UsersError
		end

		# A holding object for a list of users and information about them.	Each user in the list
		# is referenced by username in Hash notation (ulist['root'])
		class UserList < Hash
			def to_hash()
				
				hash = Hash.new()
				self.each_key() { |key|
					hash[key] = self[key].to_hash
				}
				
				return(hash)
			end
		end
		
		
		# A holding object for information about a user.	Currently implemented as a
		# simple OpenStruct.	Should provide accessor methods for as many of the following
		# as possible (listed in order of importance):
		# username:: username of the user (root)
		# uid:: user id of the user (0)
		# gid:: group id of he user (primary) (0)
		# fullname:: full name of the user (Charlie Root)
		# shell:: default shell assigned to the user
		# homedir:: home directory of the user
		class UserInfo < OpenStruct
			def to_s()
				return(self.username)
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
		
		
		# A holding object for a list of groups and information about them.	 Each group in the list
		# is referenced by groupname in Hash notation (glist['wheel'])
		class GroupList < Hash
			def to_hash()
				
				hash = Hash.new()
				self.each_key() { |key|
					hash[key] = self[key].to_hash
				}
				
				return(hash)
			end
		end
		
		
		# A holding object for information about a group.	 Currently implemented as a
		# simple OpenStruct.	Should provide accessor methods for as many of the following
		# as possible (listed in order of importance):
		# groupname:: groupname (wheel)
		# gid:: group id (0)
		# members:: a UserList of group members
		class GroupInfo < OpenStruct
			def to_s()
				return(self.groupname)
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


		# The UserManager class serves only as an in-code description of the UserManager interface.	 It should be
		# subclassed on an OS specific basis
		class UserManager
			
			# Adds a user to the system.	If userinfo is a String then it will
			# add the named user with an optional uid.	If userinfo is an actual
			# UserInfo object then uid is ignored and everything except password
			# will be used from UserInfo (or generated if not supplied)
			def add_user(user, password=nil, uid=nil)
			end
			
			
			# Adds a group to the system with an optional fixed gid
			def add_group(group, gid=nil)
			end
			
			
			# Adds +user+ to +group+
			def add_user_to_group(user, group)
			end
			
			
			# Removes +user+ from +group+
			def remove_user_from_group(user, group)
			end
			
			
			# Ensures that +user+ belongs to exactly the given +grouplist+
			def set_groups(user, grouplist)
			end
			
			
			# Deletes +username+ from the system.	 If +removehome+ is true the users homedir will also be removed
			def delete_user(username, removehome=false)
			end
			
			
			# Deletes +group+ from the system
			def delete_group(group)
			end
			
			
			# Adds +username+ to +groupname+
			def add_user_to_group(username, groupname)
				if !user?(username)
					raise(NoSuchUserError, "No such user: #{username}")
				end

				if !group?(groupname)
					raise(NoSuchGroupError, "No such user: #{groupname}")
				end
			end


			# Deletes +username+ from +groupname+
			def delete_user_from_group(username, groupname)
				if !user?(username)
					raise(NoSuchUserError, "No such user: #{username}")
				end

				if !group?(groupname)
					raise(NoSuchGroupError, "No such user: #{groupname}")
				end
			end


			# Returns true if +user+ exists, false otherwise
			def user?(user)
				if(users()[user] != nil)
					Cfruby.controller.inform('debug', "\"#{user}\" exists")
					return(true)
				else
					Cfruby.controller.inform('debug', "\"#{user}\" does not exist")
					return(false)
				end
			end
			
			
			# Returns true if +group+ exists, false otherwise
			def group?(group)
			end
			
			
			# Returns the uid of +username+
			def get_uid(username)
				user = users()[username]
				if(user == nil)
					raise(NoSuchUserError, "User \"#{username}\" could not be found")
				end
				return(user.uid)
			end

			# Returns the username of +uid+
			def get_name(uid)
				users().each do |user|
					return user[1].username if user[1].uid == uid
				end
				nil
			end
			
			# Returns the groupname of +gid+
			def get_group(gid)
				groups().each do |group|
					return group[1].groupname if group[1].gid == gid
				end
				nil
			end
			
			
			# Returns the gid of +groupname+
			def get_gid(groupname)
				group = groups()[groupname]
				if(group == nil)
					raise(NoSuchGroupError, "Group \"#{groupname}\" could not be found")
				end

				return(group.gid)
			end

			
			# Returns a UserList of all the users on the system
			def users()
			end
			
			
			# Returns a GroupList of all the groups on the system
			def groups()
			end
			
			
			# Sets the password of +user+ to +newpassword+
			def set_password(user, newpassword)
				# We are going to do this with an expect script instead of in pure ruby...
				# partly because doing it in pure ruby turns out to be pretty tricky since
				# ruby doesn't have very good tools for interacting with shell programs, but
				# also because Expect does, and we like doing things with the right tool
				
				Cfruby.controller.attempt("Changing password for \"#{user}\"", 'destructive') {
					# we must be running as root
					if(Process.euid() != 0)
						raise(ChangePasswordError, "Passwords can only be set by root")
					end
				
					# first check for the existence of expect
					haveexpect = `/usr/bin/env expect -v`
					if(haveexpect !~ /expect version/i)
						raise(ChangePasswordError, "Expect binary could not be found")
					end
				
					# create a specialized expect script to change the password
					# and run it
					changepass = <<CHANGEPASS
#!/usr/bin/env expect

spawn passwd #{Cfruby::Exec.shellescape(user)}
set password "#{newpassword.gsub(/(")/, "\\\1")}"
expect "New password:"
send "$password\\r"
expect "password:"
send "$password\\r"
expect eof
CHANGEPASS

					scriptfile = Tempfile.new('cfruby')
					Cfruby::FileOps.chmod(scriptfile.path, "u+x,go-rwx")
					scriptfile.print(changepass)
					scriptfile.close(false)
					`cp #{scriptfile.path} ./footest`
					output = Cfruby::Exec.exec(scriptfile.path)
				}
			end
			
		end
				
	end

end
