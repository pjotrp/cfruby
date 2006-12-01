# The packages module attempts to provide a generic interface for package management systems
#
# Author:: David Powers
# Copyright:: November, 2004
# License:: Ruby License

require 'libcfruby/os'
require 'ostruct'


module Cfruby

	# The packages module attempts to provide a generic interface for package management systems
	module Packages
	
		# Generic error for packages
		class PackageError < Cfruby::CfrubyError
		end
		
		# Raised when an install error is detected
		class InstallError < Cfruby::CfrubyError
		end
		
		
		# A holding object for a list of packages and information about them.	 Each package is
		# referenced in the list by name using Hash notation (plist['apache'])
		class PackageList < Hash
			def to_hash()
				
				hash = Hash.new()
				self.each_key() { |key|
					hash[key] = self[key].to_hash
				}
				
				return(hash)
			end
		end

		
		# A holding object for information about a package.	 Currently implemented as a
		# simple OpenStruct.	Should provide accessor methods for as many of the following
		# as possible (listed in order of importance):
		# name:: The name of the package without version numbers (apache)
		# version:: The version of the package (1.3.1r2)
		# fullname:: The full name of the package (Apache Web Server)
		# description:: A short description of the package (A full-featured and fast web server)
		# os-specific items (category, origin, etc)
		class PackageInfo < OpenStruct
			def to_s()
				return("#{self.name}-#{self.version}")
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
		
		
		# The PackageManager class serves mostly as an in-code description of the PackageManager interface.
		# It implements a handful of useful of helper functions, but is generally unimplemented
		class PackageManager
		
			# Installs the latest version of the named package, will not install the package
			# if it is already installed unless force=true.	 Returns true is a package is actually
			# installed, false otherwise.
			def install(packagename, force=false)
			end
			
			
			# Uninstalls the named package
			def uninstall(packagename)
			end
			
			
			# Returns the installed version of the named package
			def installed_version(packagename)
				return(installed_packages()[packagename].version)				
			end
			
			
			# Returns the latest stable version of the named package that
			# is available (installed or not)
			def version(packagename)
				return(packages()[packagename].version)
			end
			
			
			# Returns a PackageList object that contains key value pairs for
			# every installed package where the key is the package name and
			# the value is the currently installed version.	 See PackageList for
			# more information
			def installed_packages()
				return(PackageList.new())
			end
			
			
			# Returns a PackageList object that contains key value pairs for
			# every package (installed or not) where the key is the package name and
			# the value is a PackageInfo object
			def packages()
				return(PackageList.new())
			end
			
			
			# Returns true if the named package is installed
			def installed?(package)
				if(!package.kind_of?(Regexp))
					package = Regexp.new(Regexp.escape(package.to_s))
				end

				Cfruby.controller.inform('debug', "Getting installed? status of \"#{package.source}\"")

				installed_packages.each_value() { |packageinfo|
					if(package.match(packageinfo.name))
						return(true)
					end
				}
				
				return(false)
			end


			# Returns the referenced PackageInfo object, or nil
			def [](packagename)
				return(packages()[packagename])
			end


			# Calls installed? after converting the symbol to a string if symbol ends in ?, otherwise
			# calls []
			def method_missing(symbol, *args)
				if(args == nil or args.length == 0)
					name = symbol.id2name
					if(name =~ /\?$/)
						return(installed?(name[/^(.*)\?$/, 1]))
					else
						return(packages()[name])
					end
				end

				super.method(symbol).call(args)
			end
		end
				
	end
	
end
