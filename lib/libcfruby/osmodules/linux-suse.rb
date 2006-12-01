require 'libcfruby/os'


module Cfruby

	module Packages

# PackageManager implementation for rpm
		class RPMPackageManager < PackageManager

			def initialize()
				# FIXME - search for rpm
				@rpmbin = 'rpm'
			end


			# Installs the latest version of the named package
			def install(packagename, force=false)
				packagename.strip!()

				# FIXME - check to see if it is already installed

				Cfruby.controller.attempt("Installing \"#{packagename}\"", 'destructive', 'unknown', 'install') {
					`#{@rpmbin} -i '#{packagename.gsub(/(\')/, "\\\1")}'`
				}
			end


			# Uninstalls the named package
			def uninstall(packagename)
				pacakgename.strip!()

				Cfruby.controller.attempt("Uninstalling \"#{packagename}\"", 'destructive', 'unknown') {
					`#{@rpmbin} -e #{packagename}`
				}
			end


			# Returns a PackageList object that contains key value pairs for
			# every installed package where the key is the package name and
			# the value is the currently installed version.  See PackageList for
			# more information
			def installed_packages()
			end


			# Returns a PackageList object that contains key value pairs for
			# every package (installed or not) where the key is the package name and
			# the value is a PackageInfo object
			def packages()
			end

		end
		
	end

end
