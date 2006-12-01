require 'libcfruby/os'


module Cfruby

	module Packages

		# PackageManager implementation for the Gentoo portage system
		class PortagePackageManager < PackageManager

			# Installs the latest version of the named package
			def install(packagename, force=false)
				packagename.strip!()

				# FIXME - check to see if it is already installed

				Cfruby.controller.attempt("Installing \"#{packagename}\"", 'destructive', 'unknown', 'install') {
					`emerge '#{packagename.gsub(/(\')/, "\\\1")}'`
				}
			end


			# Uninstalls the named package
			def uninstall(packagename)
				packagename.strip!()

				Cfruby.controller.attempt("Uninstalling \"#{packagename}\"", 'destructive', 'unknown') {
					`emerge unmerge '#{packagename.gsub(/(\')/, "\\\1")}'`
				}
			end


			# Returns a PackageList object that contains key value pairs for
			# every installed package where the key is the package name and
			# the value is the currently installed version.  See PackageList for
			# more information
			def installed_packages()
				packages = PackageList.new()
				packageregex = /^\s*([^\/]+)\/([^ ]+?)-([0-9][^ ]+)/

				list = `qpkg -I -v`
				list.each_line() { |line|
					match = packageregex.match(line)
					if(match != nil)
						packages[match[2]] = PackageInfo.new()
						packages[match[2]].name = match[2]
						packages[match[2]].version = match[3]
						packages[match[2]].category = match[1]
					end
				}
			end


			# Returns a PackageList object that contains key value pairs for
			# every package (installed or not) where the key is the package name and
			# the value is a PackageInfo object
			def packages()
				packages = PackageList.new()
				packageregex = /^\s*([^\/]+)\/([^ ]+?)-([0-9][^ ]+)/

				list = `qpkg -v`
				list.each_line() { |line|
					match = packageregex.match(line)
					if(match != nil)
						packages[match[2]] = PackageInfo.new()
						packages[match[2]].name = match[2]
						packages[match[2]].version = match[3]
						packages[match[2]].category = match[1]
					end
				}
			end

		end
		
	end
	
end
