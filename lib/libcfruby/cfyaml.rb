# Author:: David Powers
# Copyright:: August, 2005
# License:: Ruby License
#
# cfyaml is a simplified front end for the entire libcfruby set of modules.  It provides a
# very concise syntax for writing system configuration and maintenance scripts, while still
# giving the writer the ability to call on the full power of ruby if necessary.  cfyaml scripts
# are written in pure YAML, and have a very simple set of processing rules.  The script is loaded
# and is examined by the parser as an entire object.  If the object is an Array, then each item of
# the array is processed in order, if it is a Hash, then it is examined for a primary key (such as
# filename, eval, execute, delete, etc.).  The primary key of the Hash determines how the Hash as
# a whole is processed.  filename Hashes for instance, may manipulate files in a number of ways.
#
# In addition, each Hash may also have a conditions and change_mode key.  If change_mode is defined
# the Hash will only be processed if the immediately previous section made a change (assuming change_mode
# is set to true).  Conditions provides additional flexibility - it is evaluated as raw ruby code and
# the section runs if it returns a true value.
#
# A short example of a valid cfyaml script:
#   - install: exim
#   - filename: /usr/local/etc/exim
#     options:
#       recursive: true
#     user: mailnull
#     group: mail
#     mode: u=rwX,g=rX,o-rwx
#   - filename: /etc/rc.conf
#     set:
#       - [sendmail_enable, '"NONE"']
#       - [exim_enable, '"YES"']
#       - [exim_flags, '"-bd -q5m"']
# 


require 'libcfruby/libcfruby'
require 'yaml'

# A set of methods for loading and automatically executing highly-compressed cfrubyscript
# in yaml form
module CfYAML
	
	class CfYamlError < StandardError
	end
	
	class StructureError < StandardError
	end
	
	# Executes a YAML file by loading it and processing each array entry in it in turn recursively, depth first.
	# +changed+ is only used internally.
	def CfYAML.load(filename, changed=false)
		fp = filename
		if(!filename.kind_of?(IO))
			fp = File.open(filename, File::RDONLY)
		end
		
		cfyamlcode = YAML.load(fp)

		return(process(cfyamlcode, changed))
	end
	
	
	# Executes an object loaded from a YAML file.  +changed+ is only used internally.  Returns
	# true if a known change was made.  Specifically, it does the following (in order):
	#   1. Check for a +condition+ key.  If it exists, eval it as a ruby statement and stop processing if the
	#      result of the eval() is false or nil.
	#   2. Check for a +change_made+ key (which must be set to true or false).  This value is checked against
	#     whether or not a change was actually made by the *immediately previous* section.  If they do not match, then
	#     this section will stop processing.
	#   3. The section is searched for a primary key, which will then determine how the rest of the section is
	#     processed.  These are:
	#      * load
	#      * actions
	#      * eval
	#      * filename
	#      * install
	#      * delete
	#      * disable
	#      * execute
	def CfYAML.process(object, changed=false)
		if(object.kind_of?(Hash))
			begin
				# first check for condition
				if(object.has_key?('conditions'))
					conditions = object['conditions']
					if(!conditions.kind_of?(Array))
						conditions = Array.[](conditions)
					end
			
					conditions.each() { |c|
						if(!eval(c.to_s))
							return(false)
						end
					}
				end
				
				if(object.has_key?('change_made'))
					if(object['change_made'] != changed)
						return(false)
					end
				end

				# load has to be handled here because it should not change
				# the changed flag on its own.
				if(object.has_key?('load'))
					if(object['load'].kind_of?(Array))
						object['load'].each() { |s|
							changed = load(s, changed)
						}
					else
						changed = load(object['load'], changed)
					end
				end

				changed = false
		
				if(object.has_key?('actions'))
					changed = process(object['actions'], changed)
				elsif(object.has_key?('eval'))
					evaluate(object)
				elsif(object.has_key?('filename'))
					changed = configure_file(object)
				elsif(object.has_key?('install'))
					changed = install_packages(object)
				elsif(object.has_key?('delete'))
					changed = delete(object)
				elsif(object.has_key?('disable'))
					changed = disable(object)
				elsif(object.has_key?('execute'))
					execute(object)
				else
					raise(CfYamlError, "Unable to find primary key (actions, eval, filename, install, or execute)")
				end
			rescue
				raise(CfYamlError, "Error processing section:\n #{object.to_yaml}\n\n#{$!.to_s}\n\n")
			end
		elsif(object.kind_of?(Array))
			object.each() { |o|
				changed = process(o, changed)
			}
		end
		
		return(changed)
	end
	
	
	# Evaluates the code or Array of code in hash['eval']
	def CfYAML.evaluate(hash)
		commands = hash['eval']
		if(!commands.kind_of?(Array))
			commands = Array.[](commands)
		end
		commands.each() { |command|
			eval(command)
		}
	end


	# Deletes the file or Array of files in hash['delete'].  May take an optional
	# options: key that may contain any option suitable for passing to FileOps.delete
	def CfYAML.delete(hash)
		options = parse_options(structure['options'])
		return(Cfruby::FileOps.delete(hash['delete'], options))
	end


	# Disables the file or Array of files in hash['disable'].  May take an optional
	# options: key that may contain any option suitable for passing to FileOps.disable
	def CfYAML.disable(hash)
		options = parse_options(structure['options'])
		return(Cfruby::FileOps.disable(hash['disable'], options))
	end

	
	# Executes the command or Array of commands in hash['execute']
	# user:: Run the command(s) as user
	# useshell:: Run the commands in the default shell (not compatible with user)
	# arguments:: If useshell is given, then the arguments should be given as an Array in arguments
	def CfYAML.execute(hash)
		commands = hash['execute']
		if(!commands.kind_of?(Array))
			commands = Array.[](commands)
		end
		user = hash['user']
		commands.each() { |command|
			if(hash['useshell'])
			  arguments = hash['arguments'] | Array.new()
				Cfruby::Exec.shellexec(command, arguments)
			else
				Cfruby::Exec.exec(command, user)
			end
		}
	end
	
	
	# Installs the package or Array of packages in hash['install']
	def CfYAML.install_packages(hash)
		changemade = false
		
		os = Cfruby::OS::OSFactory.new.get_os()
		pkg_manager = os.get_package_manager()
		packages = hash['install']
		if(!packages.kind_of?(Array))
			packages = Array.[](packages)
		end
		packages.each() { |package|
			if(pkg_manager.install(package))
				changemade = true
			end
		}
		
		return(changemade)
	end
	
	
	# takes a structure loaded from yaml (a Hash or Array of Hash's) and
	# executes it as a series of cfrubyscript commands.  Each Hash must contain
	# a +filename+ key which dictates the file (or files) to be worked on.  The
	# following keys are then executed in order.  any subkey that takes options
	# may define them in an option hash, and then redefine the main variables in
	# a subkey using the same name as in:
	# set:
	#   options:
	#     whitespace: true
	#   set: ['variable', 'value' ]  
	# Options will cascade to the next item in the sequence.
	# mkdir:: If +filename+ does not exist, create it as a directory
	# touch:: If +filename+ does not exist, create it as an empty file
	# template:: If +filename+ is singular and doesn't exist, this file will be copied into its' place
	# user:: Executes a chown command with this user and group (or currently running group if group is not given)
	# group:: Executes a chmod command with this group and user (or currently running user if user is not given)
	# mode:: Executes a chmod with this mode
	# comment:: Comments the line or lines given
	# uncomment:: Uncomments the line or lines given
	# set:: Executes set passing name, value pairs as given
	# replace:: Executes the replace command passing regex, str pairs as given
	# must_not_contain:: Executes file_must_not_contain
	# must_contain:: Executes file_must_contain
	def CfYAML.configure_file(structure)
		changemade = false
		
		# If it is an Array iterate.  If a String, parse as yaml.  If IO, read and parse
		if(structure.kind_of?(Array))
			structure.each() { |s|
				configure_file(s)
			}
			return()
		end

		filename = structure['filename']
		
		options = parse_options(structure['options'])

		if(structure.has_key?('template'))
			if(Dir.glob(filename).length == 0)
				Cfruby::FileOps.copy(structure['template'], filename)
			end
		end

		if(structure.has_key?('mkdir'))
			if(Dir.glob(filename).length == 0)
				if(Cfruby::FileOps.mkdir(filename, :makeparent => true))
					changemade = true
				end
			end
		elsif(structure.has_key?('touch'))
			if(Dir.glob(filename).length == 0)
				if(Cfruby::FileOps.touch(filename))
					changemade = true
				end
			end
		end
		
		if(structure.has_key?('user') or structure.has_key?('group'))
			if(structure.has_key?('user'))
				user = structure['user']
			else
				user = Process.euid()
			end
			if(structure.has_key?('group'))
				group = structure['group']
			else
				group = Process.gid()
			end
			if(Cfruby::FileOps.chown(filename, user, group, options))
				changemade = true
			end
		end
		
		if(structure.has_key?('mode'))
			if(Cfruby::FileOps.chmod(filename, structure['mode'], options))
				changemade = true
			end
		end
		
		if(structure.has_key?('comment'))
			lines = Array.new()
			if(structure['comment'].kind_of?(Hash))
				options = parse_options(structure['comment']['options'])
				lines = structure['comment']['comment']
			else
				lines = structure['comment']
			end
			if(Cfruby::FileEdit.comment(filename, lines, options))
				changemade = true
			end
		end

		if(structure.has_key?('uncomment'))
			lines = Array.new()
			if(structure['comment'].kind_of?(Hash))
				options = parse_options(structure['uncomment']['options'])
				lines = structure['uncomment']['uncomment']
			else
				lines = structure['uncomment']
			end
			if(Cfruby::FileEdit.uncomment(filename, lines, options))
				changemade = true
			end
		end

		if(structure.has_key?('set'))
			variables = Array.new()
			if(structure['set'].kind_of?(Hash))
				options = parse_options(structure['set']['options'])
				variables = structure['set']['set']
			else
				variables = structure['set']
			end
			variables.each() { |s|
				if(Cfruby::FileEdit.set(filename, s[0], s[1], options))
					changemade = true
				end
			}
		end
		
		if(structure.has_key?('replace'))
			replacements = nil
			if(structure['replace'].kind_of?(Hash))
				options = parse_options(structure['replace']['options'])
				replacements = structure['replace']['replace']
			else
				replacements = structure['replace']
			end
			replacements.each() { |r|
				if(Cfruby::FileEdit.replace(filename, r[0], r[1], options))
					changemade = true
				end
			}
		end

		if(structure.has_key?('must_not_contain'))
			lines = nil
			if(structure['must_not_contain'].kind_of?(Hash))
				options = parse_options(structure['must_not_contain']['options'])
				lines = structure['must_not_contain']['must_not_contain']
			else
				lines = structure['must_not_contain']
			end
			if(Cfruby::FileEdit.file_must_not_contain(filename, lines, options))
				changemade = true
			end
		end

		if(structure.has_key?('must_contain'))
			lines = nil
			if(structure['must_contain'].kind_of?(Hash))
				options = parse_options(structure['must_contain']['options'])
				lines = structure['must_contain']['must_contain']
			else
				lines = structure['must_contain']
			end
			if(Cfruby::FileEdit.file_must_contain(filename, lines, options))
				changemade = true
			end
		end
		
		return(changemade)
	end
	
	private
	
	def CfYAML.parse_options(optionhash)
		if(!optionhash)
			return(Hash.new())
		end
		
		options = Hash.new()
		optionhash.each() { |key, value|
			options[key.to_sym] = value
		}
		
		return(options)
	end
end
