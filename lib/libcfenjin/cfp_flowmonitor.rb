module Cfruby


	class Cfp_FlowMonitor < FlowMonitor::Observer


		def initialize(logger)
			@logger = logger
			Cfruby.controller.register(self)
		end
	
		# Every message from any controller this observer is registered with is
		# passed through handle_message.  This is a simple implementation that 
		# logs every message, and 
		def handle_message(message)
			if(message.type == 'exception')
				@logger.error(LOG_ERR,message.message)
				return()
			end

			# If the message has a type of intention, then we have the chance to
			# basically say "NO" to the action.  In this case we are going to
			# say no to any intention that references the filename 'notouch'.  We could
			# in theory filter on any aspect of the message (the type, the tags, or
			# the content of the message itself), but in this case a simple regex hack
			# for example purposes will do nicely
			if(message.type == 'intention')

				# we can only really block intentions, so only bother checking
				# if the message is an intention

				@logger.notify(VERBOSE_MAJOR,message.message)
			elsif (message.type == 'info')
				if(message.message =~ /^search|lock|backup/)
					# overrule status of these
					@logger.notify(VERBOSE_MINOR,message.message)
				else
					@logger.notify(VERBOSE_CRITICAL,message.message)
				end
			elsif (message.type == 'verbose')
				@logger.notify(VERBOSE_MAJOR,message.message)
			elsif (message.type == 'debug')
				@logger.notify(VERBOSE_MINOR,message.message)
			else
				@logger.notify(VERBOSE_MINOR,message.message)
			end
			true
		end
	
	end

end

