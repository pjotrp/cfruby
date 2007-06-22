# This class executes the Cfruby script code
#
# Author:: Pjotr Prins
# Copyright:: July 2007
# License:: Ruby License

module Cfruby

	class Cfp_ExecuteClass
		attr_accessor :name,:initialised, :skip

		def initialize name
			@name = name
			@initialized = false
			@skip        = false
		end
	end
	
	class Cfp_Execute

		def initialize cf
			@cf = cf
			@executeclasslist = Hash.new
		end

		# Calls a method of a (pre-compiled) class. If the class does not exist
		# in the runtime space it gets initialised
		def do_execute code
			classname = code.classname
			method    = code.methodname
			return if method == 'initialize'
			# @cf.cfp_logger.trace TRACE_ENGINE,"Executing #{classname}.#{method}"
			# Make sure global and class level variables exist
			sourcepath = File.dirname(code.fn)
			homepath   = ENV['HOME']
			user       = ENV['USER']  # @@FIXME
			begin
				iname = '@'+instancename(classname)
				if !@executeclasslist[classname]
					# ---- Create new class and add into runtime space
					scode = "#{iname} = Cfp_Compile::#{classname}.new @cf,sourcepath,homepath,user"
					@cf.cfp_logger.trace TRACE_ENGINE,'Executing: '+scode
					eval scode
					@executeclasslist[classname] = Cfp_ExecuteClass.new(classname)
				end
				if !@executeclasslist[classname].skip
					scode = "#{iname}.#{method}"
					@cf.cfp_logger.trace TRACE_ENGINE,'Executing: '+scode
					eval scode
				end
			rescue CfrubyRuntime::PackageNotInstalledError, CfrubyRuntime::ExitScript
				@executeclasslist[classname].skip = true
			rescue
				msg = 'ERROR cfscript ',code.fn," line #{code.linenum} - #{$!}\n"
				code.dump
				@cf.cfp_logger.error LOG_CRIT,msg,'cfruby'
				raise
			end
		end

protected

		# Forms and instancename for +classname+ - currently prepends an i
		def instancename classname
			'i'+classname
		end
	end

end
