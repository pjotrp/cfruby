require 'libcfruby/os'


module Cfruby

	module Packages

		# PackageManager implementation for apt
		class AptPackageManager < PackageManager

			def initialize()
				# FIXME - search for apt utils
				@aptgetbin = 'apt-get'
				@dpkgbin = 'dpkg'
			end


			# Installs the latest version of the named package
			def install(packagename)
				packagename.strip!()

				Cfruby.controller.attempt("Installing \"#{packagename}\"", 'destructive', 'unknown') {
					`#{@aptgetbin} install '#{packagename.gsub(/(\')/, "\\\1")}'`
				}
			end


			# Uninstalls the named package
			def uninstall(packagename)
				packagename.strip!()

				Cfruby.controller.attempt("Uninstalling \"#{packagename}\"", 'destructive', 'unknown') {
					raise(Exception, 'uninstall unimplemented for AptPackageManager')
				}
			end


			# Returns the latest stable version of the named package that
			# is available (installed or not)
			def packages()
				packages = PackageList.new()

				list = `#{@dpkgbin} -l`
				regex = /^ii\s+(\S+)\s+(\S+)/
				list.each_line { | s |
					match = regex.match(s)
					if(match != nil)
						packages[match[1]]= PackageInfo.new()
						packages[match[1]].name = match[1]
						packages[match[1]].version = match[2]
					end
				}

				return(packages)
			end


			# Returns a PackageList object that contains key value pairs for
			# every installed package where the key is the package name and
			# the value is the currently installed version.  See PackageList for
			# more information
			def installed_packages()
			end

		end

	end
	
end
