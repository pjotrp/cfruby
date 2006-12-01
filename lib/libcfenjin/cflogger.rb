# Author:: David Powers
# Copyright:: January, 2005
# License:: Ruby License
#
# A singleton implementation of the logger interface that by default logs nothing.  It is used in all
# Cfruby library modules as a placeholder for a user-provided logger

module Cfruby
	
	class CfrubyLogger

		attr_reader :dry_run      # only logging
		attr_reader :quiet_mode   # no logging

		private_class_method :new
		
		@@logger = nil
		
		
		# Returns the current logger instance (either self which serves only
		# as a dummy placeholder, or a user-set logger)
		def CfrubyLogger.instance()
			if(@@logger == nil)
				@@logger = new()
			else
				return(@@logger)
			end
		end
		
		
		# Sets the singleton logger object to the passed in logger.  Logger is
		# expected to conform to the standard logger interface
		def CfrubyLogger.set_logger(logger)
			@@logger = logger
		end

		# stub functions for improved logging - for a full implementation 
		# see +Cfp_logger+.

		def help(msg,action='unknown')
			self
		end

		def status(msg=nil)
		end

		def testing(msg=nil)
		end

		def acting(msg=nil)
			yield if !dry_run
		end

		# stub functions to implement a logger that doesn't log - see 
		# +FileCopy.fcopy+ for a code example

		def info(level,msg,progname=nil)
		end
		
		
		def change(level,msg,progname=nil)
		end
		
		
		def debug(level,msg,progname=nil)
		end
		
		
		def warn(level,msg,progname=nil)
		end
		
		
		def error(level,msg,progname=nil)
		end
		
		
		def fatal(level,msg,progname=nil)
		end
		
	end
	
end
