#!/usr/bin/env ruby

# This is an example of the flow monitor infrastructure

$: << '..'

require '../libcfruby'
require 'logger'


# The first step in using the flow monitor is to create an observer class that
# will then see all messages (and get a chance to respond).  The observer class
# should override the handle_message method to implement its behavior
class FlowObserver < FlowMonitor::Observer

	def initialize()
		# create a log using logger
		@log = Logger.new('flowmonitorexample.log', 10, 1024000)
	end
	
	# Every message from any controller this observer is registered with is
	# passed through handle_message.  This is a simple implementation that 
	# logs every message, and 
	def handle_message(message)
		if(message.type == 'exception')
			@log.error(message.message)
			return()
		end

		# If the message has a type of intention, then we have the chance to
		# basically say "NO" to the action.  In this case we are going to
		# say no to any intention that references the filename 'notouch'.  We could
		# in theory filter on any aspect of the message (the type, the tags, or
		# the content of the message itself), but in this case a simple regex hack
		# for example purposes will do nicely
		if(message.type == 'intention')
			# we can only really block intentions, so only bother checking if the message
			# is an intention
			if(message.message =~ /notouch/)
				@log.warn("Canceled - #{message.message}")
				return(false)
			else
				@log.info(message.message)
				return(true)
			end
		else
			@log.info(message.message)
		end
	end
	
end


# once you have an observer it can be registered with one or more controllers.  Each
# controller will then send all control messages through its observers (in registered order)
# for review.  In this case we will be registering with the main controller used by the
# cfruby library like so:
observer = FlowObserver.new()
Cfruby.controller.register(observer)


# Now we need to write some code that does something with the flow controller...
# In this case we'll do something simple.  We will create a temporary file, then
# we will move it twice using the fileoperations cfruby library

# first - basic logging, we will create and move a file twice, then delete it
# This will create two entries in our log file
Cfruby::FileOperations.create('footest')
Cfruby::FileOperations.move('footest', 'bartest')
Cfruby::FileOperations.move('bartest', 'baztest')
Cfruby::FileOps.delete('./', :glob => '*test')

# second, we will do the same thing, but we will instead block the moves by returning
# false from handle_message.  Since attempt messages are sent before the action they are
# attempting, a return of false from handle_message causes the associated action to
# be canceled
Cfruby::FileOperations.create('notouchtest')
Cfruby::FileOperations.move('notouchtest', 'notouchfootest')
Cfruby::FileOperations.move('notouchfootest', 'notouchbaztest')
Cfruby::FileOps.delete('./', :glob => '*test')

