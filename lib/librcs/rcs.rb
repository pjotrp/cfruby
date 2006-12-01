# Author:: David Powers
# Copyright:: November, 2005
# License:: Ruby License
#
# The RCS module provides a loose object wrapper for accessing files in
# any revision control system

require 'pathname'
require 'fileutils'

module RCS
	
	class RCSError < StandardError
	end
	
	class NoSuchFileError < RCSError
	end
	
	
	# Provides an interface for revision control wrappers
	class RCSBase
		
		def initialize(options = Hash.new())
		end
		
		
		# Adds +file+ to +location+ in the repository.  If the
		# file already exists, a new version will be added.  Minimally
		# options must take :changelog as the name of the patch.
		def add(filename, location, options = Hash.new())
		end
		
		
		# Retrieves the file stored at +location+ from the
		# repository, with optional revision markers appropriate
		# to the type of repository being accessed.  Returns the
		# file's full path.
		def get(location, options = Hash.new)
		end
		
		
		# Removes the file stored at +location+ from the repository,
		# preserving the file's history.  Minimally
		# options must take :changelog as the name of the patch.
		def delete(location, options=Hash.new())
		end
	end
	
	
	# Abstract representation of a location in a repository.  This
	# should be subclassed to provide real functionality.
	class Location
		
		def initialize(path)
			@path = path.to_s
		end
		
		
		# turns the abstract Location into a path based in the root
		# of the repository
		def to_path()
			return(@path)
		end
		
		
		# returns a human-readable version of the Location
		def to_s()
			return(@path)
		end
		
		
		# should return an RHTML form appropriate for uploading to
		# location of this type.  Will be rendered with render :inline
		def Location.rhtml_form()
			form = <<FORM
			<%= text_field 'layout', 'path'  %>
FORM
		end
		
	end
	
	
	# Represents a location defined by a type, optional subtype, and name as
	# in mail, smtp, configuration
	class TypeLocation < Location

		def initialize(options = Hash.new)
			optionhash = options
			if(options[:location] != nil)
				optionhash = options[:location]
			end
			
			@type = optionhash[:type]
			@subtype = optionhash[:subtype]
			@name = optionhash[:name]
			
			if(!@type)
				raise(ArgumentError, ":type must be supplied to a TypeLocation")
			end
			
			if(!@name)
				raise(ArgumentError, ":name must be supplied to a TypeLocation")
			end
		end


		# turns the abstract Location into a path based in the root
		# of the repository
		def to_path()
			if(@subtype)
				return("#{@type}/#{@subtype}/#{@name}")
			else
				return("#{@type}/#{@name}")
			end
		end


		# returns a human-readable version of the Location
		def to_s()
			return("type: #{@type}\nsubtype: #{@subtype}\nname: #{@name}")
		end


		# should return an RHTML form appropriate for uploading to
		# location of this type.  Will be rendered with render :inline
		def TypeLocation.rhtml_form()
			form = <<FORM
	<table>
		<tr>
			<td>
				Type:
			</td>
			<td>
			 	<%= text_field 'location', 'type'  %>
			</td>
		</tr>
		<tr>
			<td>
				Subtype:
			</td>
			<td>
				<%= text_field 'location', 'subtype'  %>
			</td>
		</tr>
		<tr>
			<td>
				Name:
			</td>
			<td>
				<%= text_field 'location', 'name'  %>
			</td>
		</tr>
	</table>
FORM
		end

	end
	
	
	
	class DarcsRCS < RCSBase
		
		# expects :location => 'path to darcs repository'.  May also take :darcspath
		# to point to the darcs executable
		def initialize(options = Hash.new())
			@path = Pathname.new(File.expand_path(options[:location].to_s)).realpath.to_s
			if(!@path or !File.directory?(@path + "/_darcs"))
				raise(RCSError, "Could not access darcs repository at #{@path}")
			end
			
			@darcspath = 'darcs'
			if(options[:darcspath])
				@darcspath = options[:darcspath]
			end
		end
		
		
		# Takes :changelog => "patch name" as an option
		def add(filename, location, options = Hash.new())
			FileUtils.mkdir_p(File.dirname(@path + "/" + location.to_path))
			FileUtils.cp(filename, @path + "/" + location.to_path)

			name = options[:changelog].to_s
			if(!name)
				name = "Unknown"
			end

			FileUtils.chdir(@path)
			addeddirs = split_path(location.to_path, @path)
			addeddirs.each() { |d|
				`#{@darcspath} add '#{slash(d)}'`
			}
			FileUtils.chdir(@path)
			`#{@darcspath} add '#{slash(location.to_path)}'`
			`#{@darcspath} record -a -m '#{slash(name)}' #{addeddirs.map() { |d| slash(d) }.join(" ")}  '#{slash(location.to_path)}'`
		end
		
		
		def get(location, options=Hash.new())
			fullpath = Pathname.new(@path + "/" + location.to_path).realpath
			if(!File.exists?(fullpath))
				raise(NoSuchFileError, "\"#{location.to_s}\" could not be found in the repository")
			end
			
			return(fullpath)
		end
		
		
		def delete(location, options=Hash.new())
			name = options[:changelog].to_s
			if(!name)
				name = "Unknown"
			end
			FileUtils.chdir(@path)
			FileUtils.rm_f(location.to_path)
			`#{@darcspath} record -a -m '#{slash(name)}' '#{slash(location.to_path)}'`
		end
		
		private
		
		# slashes a string for inclusion in the commandline
		def slash(str)
			return str.gsub(/'/) { "\\'" }
		end
		
		
		# returns each component of a path past a base directory
		def split_path(path, basedir="/")
			fullbase = Pathname.new(File.expand_path(basedir.to_s)).realpath.to_s
			fullpath = Pathname.new(File.expand_path(fullbase + "/" + path)).realpath.to_s
			levels = Array.new()
			while(fullpath != fullbase)
				curdir = File.dirname(fullpath)
				levels << fullpath[/^#{Regexp.escape(curdir)}\/?(.*)$/,1]
				fullpath = curdir
			end
			
			dirs = Array.new()
			current = ""
			levels.reverse.each() { |l|
				current = current + "#{l}/"
				dirs << current.sub(/\/$/, '')
			}
			
			return(dirs)
		end
	end
	
end