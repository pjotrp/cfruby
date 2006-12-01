#!/usr/bin/env ruby
# Unit Tests for filedit module

$: << File.dirname(__FILE__) + '/../../lib'

require 'test/unit'
require 'libcfruby/flowmonitor'


class TestObserver < FlowMonitor::Observer
	
	attr_reader :lastmessage
	
	def initialize()
		@lastmessage = nil
	end
	
	
	def handle_message(message)
		@lastmessage = message
	end
	
end


class TestObserverBlocker < TestObserver
	
	def handle_message(message)
		return(false)
	end
end


# Tests the Checksum::Checksum class
class TC_FlowMonitor < Test::Unit::TestCase

	def setup()
		# create a controller and an observer object
		@controller = FlowMonitor::Controller.new()
		@observer = TestObserver.new()
	end
	
	# register observers with a controller
	def test_register()
		assert_nothing_raised("Error registering observer with controller") { 
			@controller.register(@observer)
		}
		
		# ship a message through to test if it is truely registered
		@controller.send_message(FlowMonitor::Message.new('test', 'This is a test message'))
		assert_equal('test', @observer.lastmessage.type, "Message was not properly received by supposedly registered observerr")
		assert_equal('This is a test message', @observer.lastmessage.message, "Message was not properly received by supposedly registered observerr")
		
		# register several more
		observers = Array.new()
		0.upto(9) { |i|
			observers[i] = TestObserver.new()
			assert_nothing_raised("Error registering observer with controller") {
				@controller.register(observers[i])
			}
		}
		@controller.send_message(FlowMonitor::Message.new('multipletest', 'This is a multiple test message'))
		
		assert_equal('multipletest', @observer.lastmessage.type, "Message was not properly received by supposedly registered observerr")
		assert_equal('This is a multiple test message', @observer.lastmessage.message, "Message was not properly received by supposedly registered observerr")
		observers.each() { |observer|
			assert_equal('multipletest', observer.lastmessage.type, "Message was not properly received by supposedly registered observerr")
			assert_equal('This is a multiple test message', observer.lastmessage.message, "Message was not properly received by supposedly registered observerr")
		}
	end
	
	
	def test_unregister()
		assert_nothing_raised("Error registering observer with controller") { 
			@controller.register(@observer)
		}
		
		# ship a message through to test if it is truely registered
		@controller.send_message(FlowMonitor::Message.new('test', 'This is a test message'))
		assert_equal('test', @observer.lastmessage.type, "Message was not properly received by supposedly registered observerr")
		assert_equal('This is a test message', @observer.lastmessage.message, "Message was not properly received by supposedly registered observerr")
		
		# now register several more
		observers = Array.new()
		0.upto(9) { |i|
			observers[i] = TestObserver.new()
			assert_nothing_raised("Error registering observer with controller") {
				@controller.register(observers[i])
			}
		}
		
		# then unregister the original @observer
		@controller.unregister(@observer)
		
		# send another message
		@controller.send_message(FlowMonitor::Message.new('multipletest', 'This is a multiple test message'))
		
		# the original @observer should still see the original message
		assert_equal('test', @observer.lastmessage.type, "Message was not properly received by supposedly registered observerr")
		assert_equal('This is a test message', @observer.lastmessage.message, "Message was not properly received by supposedly registered observerr")
		
		# while the new ones should all see the new message
		observers.each() { |observer|
			assert_equal('multipletest', observer.lastmessage.type, "Message was not properly received by supposedly registered observerr")
			assert_equal('This is a multiple test message', observer.lastmessage.message, "Message was not properly received by supposedly registered observerr")
		}
		
		# now unregister one in the middle
		@controller.unregister(observers[5])
		
		# send another message
		@controller.send_message(FlowMonitor::Message.new('multipletest2', 'This is a multiple test(2) message'))
		
		# every observer except 5 should have the new message
		observers.each_index() { |i|
			if(i != 5)
				assert_equal('multipletest2', observers[i].lastmessage.type, "Message was not properly received by supposedly registered observer")
				assert_equal('This is a multiple test(2) message', observers[i].lastmessage.message, "Message was not properly received by supposedly registered observer")
			end
		}
		assert_equal('multipletest', observers[5].lastmessage.type, "Message was not properly received by supposedly registered observer")
		assert_equal('This is a multiple test message', observers[5].lastmessage.message, "Message was not properly received by supposedly registered observer")
	end
	
	
	def test_basic_message()
		assert_nothing_raised("Error registering observer with controller") { 
			@controller.register(@observer)
		}
		
		message = FlowMonitor::Message.new('test', 'A test message')
		message.add_tag('one')
		message.add_tag('two', 'a value')
		
		@controller.send_message(message)
		assert_equal('test', @observer.lastmessage.type, "Message was not properly received by supposedly registered observerr")
		assert_equal('A test message', @observer.lastmessage.message, "Message was not properly received by supposedly registered observer")
		assert_equal(true, @observer.lastmessage.tags['one'], "Message was not properly received by supposedly registered observerr")
		assert_equal('a value', @observer.lastmessage.tags['two'], "Message was not properly received by supposedly registered observer")
	end
	
	
	def test_attempt()
		
		# test with no registered observers
		foovalue = 10
		assert_nothing_raised() {
			@controller.attempt('change the value of foovalue', 'destructive', 'reversable') {
				foovalue = 20
			}
		}
		assert_equal(20, foovalue, "foovalue was not set properly by the attempt")
		
		# test with a single non-blocking observer
		foovalue = 10
		assert_nothing_raised("Error registering observer with controller") { 
			@controller.register(@observer)
		}
		assert_nothing_raised() {
			@controller.attempt('change the value of foovalue', 'destructive', 'reversable') {
				foovalue = 30
			}
		}
		assert_equal(30, foovalue, "foovalue was not set properly by the attempt")
		
		# add a blocking observer - test for proper blocking
		foovalue = 10
		assert_nothing_raised("Error registering observer with controller") { 
			@controller.register(@observer)
			@controller.register(TestObserverBlocker.new())
		}
		assert_nothing_raised() {
			@controller.attempt('change the value of foovalue', 'destructive', 'reversable') {
				foovalue = 40
			}
		}
		assert_equal(10, foovalue, "foovalue was set by the attempt when it should have been blocked")
	end


	# test an attempt that is aborted with a throw
	def test_attempt_noop()
		# test with a single non-blocking observer
		foovalue = 25
		assert_nothing_raised("Error registering observer with controller") { 
			@controller.register(@observer)
		}

		assert_nothing_raised() {
			@controller.attempt('change the value of foovalue', 'destructive', 'reversable') {
				@controller.attempt_abort("I hate changing things")
				foovalue = 30
			}
		}
		assert_equal(25, foovalue, "foovalue was set properly by the attempt - should have been aborted")
		assert_equal('debug', @observer.lastmessage.type, "Message was not properly received by supposedly registered observer")	
		assert_equal("change the value of foovalue - aborted - I hate changing things", @observer.lastmessage.message)
	end

end
