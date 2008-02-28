# This module contains methods that can be accessed directly from the
# script environment - facilitating a simple syntax
#
# This module gets mixed in by the Parser class and requires a definition
# of +@cf+ pointing to a +Cfp_Stat+ class (which can be passed into
# the parser class at initialisation)
#
# Author:: Pjotr Prins
# Copyright:: July 2007
# License:: Ruby License

require 'libcfruby/fileops'
require 'libcfenjin/cfp_editfilecached'
require 'libcfenjin/cfp_parserlogic'
require 'libcfenjin/cfp_classes'
require 'libcfenjin/cfp_mapoptions'

module CfrubyRuntime

	include Cfruby::Cfp_ParserLogic
	include Cfruby::Cfp_ClassAccessor
	include Cfruby::Cfp_MapOptions

	class VersionError < Cfruby::CfrubyError
	end
	
	class PackageNotInstalledError < Cfruby::CfrubyError
	end
	
	class ExitScript < Cfruby::CfrubyError
	end
				
	# Make class available for runtime
	class EditFile < Cfruby::Cfp_EditFileCached
	end

	def exit_script msg=''
		raise ExitScript,'exit_script '+msg
	end

  def cfenjin_version version, dev_version=nil
    if (version > @cf.version) or (version == @cf.version and dev_version > @cf.dev_version)
  		raise VersionError,"Cfenjin version #{version}-dev#{dev_version} required!"
    end  
  end

	# This method is called from Cfruby script to make sure a package has
	# been installed. If it is not on the system the rest of the script should
	# not be executed.
	# 
	def package *args
		args.each do | name |
			return if haspackage? name
		end
		@cf.cfp_logger.notify VERBOSE_MAJOR,"Skipping - package #{args.join(',')} not installed"
		raise PackageNotInstalledError.new('Package '+args.join(",")+' not installed')
	end

	# This method checks whether a package is installed - if not it will
	# try and install it (nyi) FIXME
	def needpackage *args
		package *args
	end

	# Checks for a package (non-disruptive)
	def haspackage? pkgname
		if @cf.packagelist
			return @cf.packagelist[pkgname]
		end
		# ---- check for direct name of binary using the path
		`which #{pkgname}` =~ /#{pkgname}/
	end

	# Checks for a user
	def hasuser? username
		@cf.usermanager.user? username		
	end

	# Create a symbolic link from +linkname+ to +fn+
	def link fn,linkname
		if File.symlink?(linkname) and !Cfruby::FileOps::SymlinkHandler.points_to?(linkname,fn)
			Cfruby.controller.inform('verbose', "Existing #{linkname} is not pointing to #{fn}")
			print "Existing #{linkname} is not pointing to #{fn}\n"
			Cfruby::FileOps.delete linkname
		end
		if @cf.strict
			Cfruby::FileOps.link fn,linkname
		else
			begin
				Cfruby::FileOps.link fn,linkname
			rescue
				Cfruby.controller.inform('verbose', "Problem linking #{linkname} -> #{fn}")
			end
		end
	end

	def directories dirname,attrib={}
		if has_attrib? dirname 
			eval(send('form_directories',dirname))
		else
			Cfruby::FileOps.mkdir dirname,map('directories',attrib)
		end
	end

	# The mother of 'files' in Cfruby
	def files filename,attrib={}
		if has_attrib? filename 
			eval(send('form_files',filename))
		else
			options = map('files',check_pattern(attrib,filename))
			(owner,group,mode) = pop_options(options,:owner,:group,:mode)
			begin
					# p [filename,owner,group,mode,options]
          if options[:shell]
				  	Cfruby::FileOps.shell_chown_mod filename,owner,group,mode,options
          else
					  Cfruby::FileOps.chown_mod filename,owner,group,mode,options
          end
          options[:shell] = nil
			rescue Cfruby::FileFind::FileExistError
				Cfruby.controller.inform('verbose', "Can not chmod on non-existing file #{filename}")
			end
		end
	end

	def copy src,dest=nil,attrib={}
		if has_attrib? src
			eval(send('form_copy',src))
		else
			if dest.is_a? Hash
				# Move dest from attrib to string 'dest'
				d = dest['dest']
				attrib = dest
				attrib.delete('dest')
				dest = d
			end
			if File.exist? src
				# p sprintf("1 %o\n",File.stat(dest).mode)
				# p (File.stat(dest).mode&0200)
				# p (File.stat(dest).mode&0400)
			
				if (File.exist?(dest) && ((File.stat(dest).mode & 0200)!=0200))
					# ---- File in place disallows writing
					File.chmod((0200|File.stat(dest).mode),dest)
				end
				Cfruby::FileOps.copy src,dest,map('copy',attrib)
			else
				Cfruby.controller.inform('info', "Failed to copy non-existing file #{src}")
				raise "Failed to copy #{src}" if @cf.strict
			end
		end
	end

	def tidy target, attrib={}
		if has_attrib? target
			eval(send('form_tidy',target))
		else
			options = map('tidy',check_pattern(attrib,target))
			Cfruby::FileOps.delete target,options
		end
	end

end
