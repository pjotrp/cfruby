# Author:: David Powers
# Copyright:: November, 2004
# License:: Ruby License
#
# Module for storing and checking checksums of files


require 'libcfruby/cfruby'
require 'libcfruby/fileops'
require 'libcfruby/filefind'
require 'digest/md5'
if /^1\.8/ === RUBY_VERSION then
  require 'md5'
end
require 'digest/sha1'
require 'ostruct'
require 'yaml'
require 'pathname'
require 'tempfile'


module Cfruby

	# Module for storing and checking checksum information
	module Checksum
		# base class for all Checksum Exceptions
		class ChecksumError < CfrubyError
		end
		
		# raised when a checksum does not match a previously recorded checksum
		class ChecksumMatchError < ChecksumError
		end
		
		# raised when permissions do not match previously recorded permissions or when
		# the checksum database has a bad mode
		class ChecksumPermissionError < ChecksumError
		end
		
		# raised when uid or gid do not match previously recorded values or when the checksum
		# database has bad ownership
		class ChecksumOwnershipError < ChecksumError
		end
		
		
		# Returned by get_checksums. The checksum contains the
		# following fields:
		# uid:: User id of the file's owner
		# gid:: Group id of the file's group
		# permissions:: Integer representation of the file's permissions
		# md5:: MD5 hash of the file's contents
		# sha1:: SHA1 hash of the file's contents
		# timestamp:: The modification time of the file
		class ChecksumValues < OpenStruct
			def ==(other)
				self.each_key?() { |key|
					if(!other.has_key?(key))
						return(false)
					elsif(self[key] != other[key])
						return(false)
					end
				}
				
				return(true)
			end
		end
		
		
		# The Checksum class ties to a database file and has methods for adding files to the database,
		# and checking existing files against their previously added checkums.  In addition get_checksums
		# may be called on files or IO streams without instantiating an instance of Checksum for quick
		# checks.
		class Checksum
			
			attr_reader :database, :databasefile
			
			
			# Takes an optional databasefile to use and a user, group, and mode to enforce for that file.
			# Most functions cannot be used without an actual database file.
			def initialize(databasefile=nil, user=Process.euid, group=Process.egid, mode=0600)
				@mode = mode
				@user = user
				@group = group

				# convert mode to internal representation
				modefile = Tempfile.new('checksum')
				modefilepath = modefile.path
				modefile.close(true)
				Cfruby::FileOps.create(modefilepath, Process.euid, Process.egid, mode)
				@statmode = File.stat(modefilepath).mode
				Cfruby::FileOps.delete(modefilepath)

				@database = Hash.new()
				
				if(databasefile != nil)
					self.databasefile=(databasefile)
				end
			end
			
			
			# handles assigning the databasefile
			def databasefile=(newdatabasefile)
				@databasefile = newdatabasefile

				if(!File.exists?(@databasefile))
					save_database()
				end
				open_database()
				
				Cfruby.controller.inform('debug', "checksum databasefile set to \"#{@databasefile}\"")
			end
			
			
			# returns the checksum of object (may be a filename or an IO object).  The checksum contains the
			# following fields:
			# uid:: User id of the file's owner
			# gid:: Group id of the file's group
			# permissions:: Integer representation of the file's permissions
			# md5:: MD5 hash of the file's contents
			# sha1:: SHA1 hash of the file's contents
			# timestamp:: The modification time of the file
			def Checksum.get_checksums(object)
				checksums = ChecksumValues.new()
				
				md5digest = Digest::MD5.new()
				shadigest = Digest::SHA1.new()
				buffer = String.new()
				opened = false
				
				fp = object
				
				# handle Pathname objects as strings
				if(object.kind_of?(Pathname))
					object = object.realpath.to_s()
				end
				
				if(!object.respond_to?(:read))
					filename = object.to_s()
					fp = File.open(filename, File::RDONLY)
					opened = true
					stats = File.stat(filename)
					checksums.uid = stats.uid
					checksums.gid = stats.gid
					checksums.permissions = stats.mode.to_s(8)
				else
					checksums.uid = nil
					checksums.gid = nil
					checksums.permissions = nil
				end

				begin
					while(fp.read(2048, buffer) != nil)
						md5digest << buffer
						shadigest << buffer
					end
				ensure
					# close it if we opened it
					if(opened)
						fp.close()
					end
				end

				checksums.md5 = md5digest.hexdigest()
				checksums.sha1 = shadigest.hexdigest()
				checksums.timestamp = Time.now()
				
				return(checksums)
			end
			
			
			# Calls check and returns true or false (instead of throwing an Exception) if a checksum fails
			def check?(basedir, options={})
				begin
					check(basedir, options)
				rescue ChecksumError
					Cfruby.controller.inform('warn', $!.to_s())
					return(false)
				end
				
				return(true)
			end
			
			
			# If the files found by calling Cfruby::FileFind.find on basedir are in the database,
			# and matches the listed checksums then nothing is done.  If they are not in the 
			# database they are added.  If a file is in the database and the checksum is different 
			# an appropriate Exception (ChecksumMatchError, ChecksumPermissionError, or ChecksumOwnershipError) 
			# is raised.
			def check(basedir, options = {})
				Cfruby.controller.attempt("Checking checksums of \"#{basedir}\" against checksum database \"#{databasefile}\"") {
					FileFind.find(basedir, options) { |filename|
						filename = filename.realpath()
					
						# get the current checksums
						checksums = Checksum.get_checksums(filename)
					
						if(@database.has_key?(filename))
							if(@database[filename].md5 != checksums.md5 or @database[filename].sha1 != checksums.sha1)
								raise(ChecksumMatchError, "Checksums do not match previously recorded value for #{filename}")
							elsif(@database[filename].permissions != checksums.permissions)
								raise(ChecksumPermissionError, "Permsisions to not match previously recorded permissions for #{filename}")
							elsif(@database[filename].uid != checksums.uid or @database[filename].gid != checksums.gid)
								raise(ChecksumOwnershipError, "user and/or group do not match previosuly recorded values for #{filename}")
							end
						else
							Cfruby.controller.attempt("adding \"#{filename}\" to checksum database", 'destructive', 'nonreversible') {
								@database[filename] = checksums
								save_database()
							}
						end
					}
				}
			end
			
			
			# Checks every file currently in the database
			def check_all()
				@database.each_key() { |filename|
					check(filename)
				}
			end


			# Calls check_all and returns true or false instead of throwing an Exception if a checksum fails
			def check_all?()
				begin
					check_all()
				rescue ChecksumError
					return(false)
				end

				return(true)
			end
			
			
			# Updates the checksums of every file in the database
			def update_all()
				@database.each_key() { |filename|
					update(filename)
				}
			end
			
		
			# Updates the database checksums for a given set of files
			def update(basedir, options = {})
				Cfruby.controller.attempt("Updating checksum database \"#{@databasefile}\" with \"#{basedir}\"", 'nonreversible', 'destructive') {
					FileFind.find(basedir, options) { |filename|
						filename = filename.realpath()
						Cfruby.controller.inform('info', "updating checksum for \"#{filename}\"")
						@database[filename] = Checksum.get_checksums(filename)
					}
				
					save_database()
				}
			end
			

private

			# Checks the user, group, and permissions of the database file.  Returns true if the file matches everything it should
			# false if the file doesn't exist, and raises an exception if the file does not match @mode, @user, or @group
			def check_mode()
				Cfruby.controller.inform('debug', "checking checksum database permisions for \"#{@databasefile}\"")

				#if it does exist test the mode.  Raise an exception if it fails the test or return true
				stat = File.stat(@databasefile)
				
				if(stat.mode != @statmode)
					raise(ChecksumPermissionError, "Checksum database \"#{@databasefile}\" does not have permissions of \"#{@mode.to_s(8)}\"")
				end
				
				if(stat.uid != @user or stat.gid != @group)
					raise(ChecksumOwnershipError, "Checksum database \"#{@databasefile}\" is not owned by uid #{@user} and group #{@group}")
				end
				
				return(true)
			end
			
			
			# Reads in a checksum database from disk in YAML format
			def open_database()
				# throw an exception if the mode isn't right
				check_mode()

				Cfruby.controller.inform('debug', "opening checksum database \"#{@databasefile}\"")
				File.open(@databasefile, File::RDONLY) { |fp|
					@database = YAML.load(fp)
				}
			end
			
			
			# Saves the current database back to disk
			def save_database()
				Cfruby.controller.attempt("saving checksum database", 'nonreversible', 'destructive') {
					if(!test(?f, @databasefile))
						FileOps.create(@databasefile, @user, @group, @mode)
					end
				
					check_mode()

					File.open(@databasefile, File::WRONLY|File::TRUNC) { |fp|
						YAML.dump(@database, fp)
					}
				}
			end
		end
		
	end	
end
