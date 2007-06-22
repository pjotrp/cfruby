# This class maintains the state of the Cfruby engine at runtime - i.e.
# it holds a pointer to the logger etc.
#
# Author:: Pjotr Prins
# Copyright:: July 2007
# License:: Ruby License

require 'libcfruby/cfruby'
require 'libcfruby/os'
require 'libcfruby/fileops'
require 'libcfenjin/cfp_logger'
require 'libcfenjin/cfp_flowmonitor'
require 'libcfenjin/cfp_classes'

module Cfruby

	# +Cfp_Stat+ holds the state of the Cfruby engine at runtime. With
	# +Cfruby+ engine classes it needs to be passed during class 
	# initialisation. Scripts can access state through the local
	# +@cfp+ variable. 

	class Cfp_Stat

		attr_reader		:os, :cfp_logger, :cfp_liblogger, :packagelist
		attr_reader   :usermanager, :classlist
		attr_accessor :dry_run, :sitepath, :strict, :site

		include Cfp_ClassAccessor

		def initialize verbose=0, trace=0, dry_run=true, quiet_mode=false, strict=false, defines=[], undefines=[]
			@dry_run      = dry_run
			@strict       = strict
			@site         = Hash.new
			# Set up the main logger
			@cfp_logger	= Cfp_Logger.new self,verbose,trace,dry_run,quiet_mode
			# Set up the library logger (if not unit testing)
			@cfp_liblogger = Cfp_LibLogger.new @cfp_logger
			# ---- Set up flow monitor
			@logger = @cfp_logger
			# Only initialize flow monitor when not unit testing
			begin
				Test::Unit.class
			rescue NameError
				@cfp_controller = Cfp_FlowMonitor.new(@cfp_logger)
				@cfp_logger.trace TRACE_ALL,'Initialized engine state (Cfp_Stat)'
			end
			# ---- Get OS info
			@os           = OS::OSFactory.new.get_os
			# ---- Get package list
			if packagemanager = @os.get_package_manager()
				@packagelist = packagemanager.packages()
			end
			# ---- Get user list
			if usermanager = @os.get_user_manager()
				@usermanager = usermanager
			end
			@classlist = Cfp_ClassList.new defines,undefines
		end

		def hostname
			@os.hostname
		end

		def osname
			@os['name']
		end

		def distribution
			@os['distribution']
		end

		def showtrace
			 @logger.trace TRACE_ON,"Trace=#{@logger.tracelevel}"
			 @logger.trace TRACE_ENGINE,"Verbose=#{@logger.verbose}"
			 @logger.trace TRACE_ENGINE,'Hostname='+hostname
		end

	end

end
