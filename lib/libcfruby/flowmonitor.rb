#!/usr/bin/ruby
# FlowController module and related classes
#
# Author:: David Powers
# Copyright:: May, 2005
# License:: Ruby License

require 'thread'

module FlowMonitor


	# base exception for all FlowMonitor specific exceptions
	class FlowMonitorError < Exception
	end
	
	# raised when a passed in object does not implement a minimally required interface
	class FlowMonitorInterfaceError < FlowMonitorError
	end
	
	
	# The Controller class provides an encapsulation and message passing mechanism that
	# can be used to add fine-grained flow control and logging facilities to a library.
	# For general use a library defines one or more Controller objects that calling programs
	# register Observer (interface) objects to.  The observers are called in order of
	# registration and are told, via Message objects, what the library intends to do at
	# a given point, as well as given a chance to override the action.
	class Controller

		def initialize()
			# Array to hold registered observers
			@observers = Array.new()
			
			# simple mutex for handling multi-threaded access.  NOTE: the mutex is
			# currently only used to handle registering and unregistering observers.
			# To avoid overhead messages are sent without the aid of the mutex.  This
			# could mean that an unregistered observer *could* get an extra message or
			# two from another thread during the unregistering process.
			@mutex = Mutex.new()
		end
		
		
		# registers the observer with this Controller.  observer is expected to implement
		# the Observer interface.
		def register(observer)
			if(!observer.respond_to?(:handle_message))
				raise(FlowControllerInterfaceError, "observer does not implement a message_handler method")
			end
			
			@mutex.synchronize {
				@observers << observer
			}
		end
		
		
		# Unregisters a listening observer
		def unregister(observer)
			@mutex.synchronize {
				@observers.each_index() { |i|
					if(@observers[i] === observer)
						@observers.delete_at(i)
					end
				}
			}
		end
		
		
		# Clears all listening observers
		def unregister_all()
			@mutex.synchronize() {
				@observers = Array.new()
			}
		end
		
		
		# attempt is called with an intention str, a list of tags, and a code block
		# which, if run, would carry out the intention.  The intention and the tags are
		# bundled into a Message object and passed, in order, to any listening Observer
		# objects, which may then abort the block.  If all the listening Observers allow,
		# the block is run and is assumed successful unless an Exception is raised.
		# Exceptions raised are first passed as a message to the Observer and are then allowed
		# to bubble up through their normal paths.
		def attempt(intention, *tags, &block)
			tags.flatten!
			if(!tags.kind_of?(Array))
				tags = Array.[](tags)
			end

			# build the message object
			if(send_message(build_message('intention', "#{intention} - attempt", tags)))
				done = false
				reason = catch(:attemptabort) {
					begin
						yield(block)
					rescue Exception
						exception("Error handling attempt \"#{intention}\" - #{$!.to_s}", ['error', 'attempt'])
						# we've passed it on, re-raise it
						raise($!)
					end
					tags << 'attempt'
					tags << 'attemptdone'
					inform('info', "#{intention} - done", tags)
					done = true
				}

				# if we bailed we should send a message explaining why
				if(!done)
					if(!reason)
						reason = "no reason given"
					end
					tags << 'attempt'
					tags << 'attemptabort'
					inform('debug', "#{intention} - aborted - #{reason}", tags)
				end
			else
				tags << 'attempt'
				tags << 'attemptpreempt'
				inform('verbose', "#{intention} - pre-empted", tags)
			end
		end


		# helper method to make it easier to understand the attempt flow control.  Causes an
		# attempt to preemptively return with an optional message.  May do unpredicatable and
		# unpleasant things if called outside of an +attempt+ block.
		def attempt_abort(reason="no reason given")
			throw(:attemptabort, reason)
		end
		
		
		# A helper function to send a simple informative message with a named level
		def inform(level, message, *tags)
			tags.flatten!
			send_message(build_message(level.to_s, message, tags))
		end
		
		
		# A helper function to send an exception message
		def exception(message, *tags)
			tags.flatten!
			if(!tags.include?('error'))
				tags << 'error'
			end
			send_message(build_message('exception', message, tags))
		end
		
		
		# builds a message object from the given components
		def build_message(type, message, *tags)
			tags.flatten!
			message = Message.new(type, message)
			tags.each() { |t|
				message.add_tag(t)
			}
			
			return(message)
		end
		
		
		# sends a message to all the registered observers until one of them returns false or
		# all of them have been sent.  Returns false if any observer returns false or true if
		# it sends the message to all of them without receiving a false in return.
		def send_message(message)
			@observers.each() { |observer|
				if(observer.handle_message(message) == false)
					return(false)
				end
			}
			
			return(true)
		end
	end
	
	
	# The Observer class serves only as an in-code description of the Observer interface.  It can be
	# subclassed, but the methods do nothing useful
	class Observer
		
		# Called whenever any message is passed from the controller.  Useful for simple
		# logging or alternate collection of event messages.  The return value may be used
		# by the controller depending on the context the message was sent in.
		def handle_message(message)
		end
		
	end
	
	
	# Encapsulates a controller message.
	class Message
		attr_reader :type, :message, :tags, :caller
		
		# Build a message. +type+'s used by the library are 'exception',
		# 'intention'
		def initialize(type, message)
			@type = type.to_s()
			@message = message.to_s()
			@tags = Hash.new()
			@caller = Kernel.caller()
		end
		
		
		# adds a tag to the message
		def add_tag(tag, value=true)
			@tags[tag.to_s()] = value
		end

		
		# helper function to print message as a string
		def to_s()
			return("#{type} - #{message}")
		end
	
	end

end

