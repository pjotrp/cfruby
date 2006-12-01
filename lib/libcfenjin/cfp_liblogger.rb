
module Cfruby

	# Implementation of the CfrubyLogger class which handles the 
	# Cfruby-engine type logging from the library - this class 
	# calls into +Cfp_Logger+

	class Cfp_LibLogger

		def initialize logger
			@cfp_logger = logger
		end

		def help(msg,action='unknown')
			@cfp_logger.help(msg,action)
		end

		def status(msg=nil)
			@cfp_logger.status(msg)
		end

		def testing(msg=nil)
			@cfp_logger.testing(msg)
		end

		def acting(msg=nil)
			@cfp_logger.acting(msg)
		end

		def info(level,msg,progname=nil)
			@cfp_logger.notify level,msg,progname
		end
		
		def change(level,msg,progname=nil)
			@cfp_logger.change level,msg,progname
		end
		
		def debug(level,msg,progname=nil)
			@cfp_logger.trace level,msg,progname
		end
				
		def warn(level,msg,progname=nil)
			@cfp_logger.warn level,msg,progname
		end
		
		def error(level,msg,progname=nil)
			@cfp_logger.error level,msg,progname
		end
		
		def fatal(level,msg,progname=nil)
			@cfp_logger.error level,msg,progname
			raise 'Forcing program exit due to fatal condition'
		end
		
	end

end
