
require 'libcfenjin/cfp_liblogger'

module Cfruby

	TRACE_ON      = 1
	TRACE_LIBRARY = 1
	TRACE_ENGINE  = 2
	TRACE_ALL     = 3

	LOG_EMERG     = 1
	LOG_ALERT     = 2
	LOG_CRIT      = 3
	LOG_ERR       = 4
	LOG_WARNING   = 5
	LOG_NOTICE    = 6
	LOG_INFO      = 7
	LOG_DEBUG     = 8

	VERBOSE_MINOR    = 3
	VERBOSE_MAJOR    = 2
	VERBOSE_CRITICAL = 1

	# Handles full logging logic from Cfruby - +Cfp_liblogger+ calls into this

	class Cfp_Logger

		attr_reader :dry_run
		attr_reader :quiet_mode
		attr_reader :tracelevel, :verbose

		def initialize cf,verbose,trace,dry_run,quiet_mode
			@cf               = cf
			@verbose          = verbose
			@tracelevel       = trace
			@dry_run          = dry_run
			@quiet_mode       = quiet_mode
		end


		# Raise exception when +level+ is LOG_CRIT or less, showing error level 
		# (see also +warn+)
		#
		# LOG_EMERG	  (1)  A panic condition.  This is normally broadcast to all
		#                  users.
		# LOG_ALERT	  (2)  A condition that should be corrected immediately, such as a
		#                  corrupted system database.
		# LOG_CRIT	  (3)  Critical conditions, e.g., hard device errors.
		#
		# LOG_ERR	    (4)  Errors.
		#
		# LOG_WARNING (5)  Warning messages.
		#
		# LOG_NOTICE	(6)  Conditions that are not error conditions, but should possi-
		#                  bly be handled specially.
		#
		# LOG_INFO	  (7)  Informational messages.
		#
		# LOG_DEBUG	  (8)  Messages that contain information normally of use only when
		#                  debugging a program.

		def error level, msg, progname=nil
			raise "unknown value for level #{level}" if level<LOG_EMERG or level>LOG_DEBUG
			if level > LOG_CRIT
				print mkmsg('error',level,msg,progname)
			else
				raise mkmsg('fatal error',level,msg,progname)
			end
		end

		# Show trace - using levels:
		#
		#   TRACE_LIBRARY    (1)   Library (scripting) level
		#   TRACE_ENGINE     (2)   Engine level
		#   TRACE_ALL	       (3)   Trace all

		def trace level, msg, progname=nil
			raise "unknown value for level #{level}" if level<TRACE_LIBRARY or level>TRACE_ALL
			print mkmsg('trace',level,msg,progname) if level <= @tracelevel
		end

		# Show activity messages based on verbosity level. Activities
		# do not imply a change to the system
		#
		#   VERBOSE_CRITICAL (1)   Critical notification
		#   VERBOSE_MAJOR    (2)   Major notification
		#   VERBOSE_MINOR    (3)   Minor notification

		def notify level,msg,progname=nil
			raise "unknown value for level #{level}" if level>VERBOSE_MINOR or level<VERBOSE_CRITICAL
			print mkmsg('info',level,msg,progname) if !@quiet_mode and level <= @verbose
		end

		# Alias for +notify+

		def warn level,msg,progname=nil
			notify level,msg,progname
		end

		# Show change notification message based on verbosity level. 
		# Use this logger only when a change happens to the system.
		#
		# See +notify+ for verbosity levels

		def change level, msg, progname=nil
			raise "unknown value for level #{level}" if level>VERBOSE_MINOR or level<VERBOSE_CRITICAL
			print mkmsg('changed',level,msg,progname) if !@quiet_mode and level <= @verbose
		end

		# Records the +msg+ and +action+ which are used later in a method
		# when it calls +test+, +status+ or +act+. Returns a pointer to 
		# +self+

		def help(msg,action='unknown')
			@msg = msg
			@action = action
			self
		end

		# Log testing activity using the message set with +help+ 

		def testing msg=nil
			msg = @msg if !msg
			notify(3,"test #{@action} #{msg}")
		end

		# Log testing status using the message set with +help+ 

		def status msg=nil
			msg = @msg if !msg
			notify(2,"status #{@action} #{msg}")
		end

		# Log change activity using the message set with +help+ 

		def acting msg=nil
			msg = @msg if !msg
			notify(1,"#{@action}ing #{msg}")
			yield if !dry_run
		end


protected

		def mkmsg type,level,msg,progname
			progname = 'cfruby' if !progname
			return "#{progname} #{type} [#{level}] #{msg}\n"
		end

	end

end
