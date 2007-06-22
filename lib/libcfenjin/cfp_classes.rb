#  Classes for Cfruby (basically a list of attributes) - with the accessor module
#
# Author:: Pjotr Prins
# Copyright:: July 2007
# License:: Ruby License

module Cfruby

	# Module containing a number of useful methods available at runtime
	# for the scripts being interpreted.

	module Cfp_ClassAccessor

		def init_classlist
			# if @cf.classlist == nil
			#	@cf.classlist = Cfp_ClassList.new    # ---- FIXME: global variable - should be singleton
			# end
		end

		# Assign +a+ to class +name+
		def assign name, a = nil
			init_classlist
			if a == nil
				a = name 
				name = a.shift  # drop name from list
			end
			@cf.classlist.add(name,a)
		end

		# Synonym for assign
		def cfgroup name, a = nil
			assign name,a
		end
		
		# If the host is not a member of class +classname+ it
		# is added to the class
		def isa classname
			init_classlist
			if !isa? classname
				@cf.classlist.add(classname,@hostname)
			end
		end
		
		# Is the host a member of class +classname+ 
		def isa? classname
			init_classlist
			@cf.classlist.isa? classname
		end

		def dump_classlist
			@cf.classlist.dump
		end

	end

	# List of Cfruby classes

	class Cfp_ClassList < Hash

		include Cfp_ClassAccessor

		# Class list with hostname added automatically
		def initialize defines, undefines
      @undefines = undefines
			os = Cfruby::OS.get_os()
			@hostname = os.hostname
			# init_classlist --- don't do this, it is a circular        
			add('any',@hostname)
			add(os['name'].downcase,@hostname) if os['name']
			add(os['distribution'].downcase,@hostname) if os['distribution']
			usermanager = os.get_user_manager()
			add(usermanager.get_name(Process.euid()),@hostname)
			add(usermanager.get_group(Process.egid()),@hostname)
      # ---- add classes passed through command line
      defines.each do | d |
        add(d,@hostname)
      end
		end

		def findclass name
			self[name]
		end

		def addclass name
      if !@undefines.include? name
        cl = Cfp_Class.new(name)
        self[name] = cl
      end
		end

		def add clname, name
			if clname == nil
				logger.notify(VERBOSE_CRITICAL,"Trying to add nil class with #{name}")
			end
      if !@undefines.include? clname
        cl = findclass(clname)
        cl = addclass(clname) if !cl
        cl.add(name)    
      end
		end

		def expand clname
			a = []
			if self[clname]
				self[clname].each do | item, value |
					if self[item]
						# ---- FIXME: recursion - no check for circular references
						item = expand item
					end
					a.push item
				end
			end
			a.flatten
		end

		def isa? clname
			# ---- Quick check where hostname is actually checked against
			return true if clname == @hostname
			# ---- Check whether the hostname of the machine is in the (expanded) list
			# print "Expanding #{clname} to "
			a = expand clname
			# p a
			a.include? @hostname
		end

		def dump logger=nil
			classes = []
			each do | item, value |
			  # p [ item,value ]
				classes.push(item) if isa? item
			end
			# p classes
			msg = 'Computer "'+@hostname+'" belongs to classes "'+classes.sort.join(', ')+'"'
			if logger
				logger.notify(VERBOSE_CRITICAL,msg)
			else
				print msg
			end
		end

	end


	# A Cfruby class contains a list of attributes - i.e a class 'firewall'
	# may contain a number of hostnames

	class Cfp_Class < Array

		attr_reader :name

		# Create a class with +name+
		def initialize name
			@name = name
		end

		# Add an attribute - allows adding strings and arrays
		def add name
			if name.class == 'String'
				push name
			else
				name.each do | n |
					push n
				end
			end
		end

	end


end
