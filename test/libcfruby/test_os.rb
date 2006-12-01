#!/usr/bin/env ruby
# Unit Tests for filedit module

$: << File.dirname(__FILE__) + '/../../lib'

require 'test/unit'
require 'libcfruby/os'



# Tests the Checksum::Checksum class
class TC_OS < Test::Unit::TestCase

	def setup()
	end
	
	
	def teardown()
	end
	
	
	def get_os()
		factory = Cfruby::OS::OSFactory.new()
		return(factory.get_os())
	end
	
	
	def test_get_os()
		os = nil
		assert_nothing_raised("Expected an OS object to be returned - raised an Exception instead") {
			os = get_os()
		}
		
		assert_not_nil(os, "OS should be set to a real OS object")
	end
	
	
	def test_os_get_os()
		os = nil
		assert_nothing_raised("Expected an OS object to be returned - raised an Exception instead") {
			os = Cfruby::OS.get_os()
		}
		
		assert_not_equal(Cfruby::OS::OS, os.class())
		assert_equal(true, os.kind_of?(Cfruby::OS::OS))		
	end
	
	def test_to_s()
		assert_nothing_raised("to_s raised an exception") {
			get_os.to_s()
		}
	end
	
	
	def test_get_user_manager()
		usermanager = nil
		assert_nothing_raised("Error getting a UserManger") {
			usermanager = get_os.get_user_manager()
		}
		
		# a very simple test to prove that the user manager can list some users
		assert_not_nil(usermanager, "UserManager should have been returned by OS object")
		assert_not_equal(0, usermanager.users().length, "The list of users returned by the usermanager was empty")
	end
	
	
	def test_get_package_manager()
		packagemanager = nil
		assert_nothing_raised("Error getting a PackageManger") {
			packagemanager = get_os.get_package_manager()
		}
		
		# a very simple test to prove that the user manager can list some packages
		assert_not_nil(packagemanager, "PackageManager should have been returned by OS object")
		assert_not_equal(0, packagemanager.packages().length, "The list of packages returned by the packagemanager was empty")
	end
	
	
	def test_get_process_manager()
		processmanager = nil
		assert_nothing_raised("Error getting a ProcessManger") {
			processmanager = get_os.get_process_manager()
		}
		
		# a very simple test to prove that the user manager can list some processes
		assert_not_nil(processmanager, "ProcessManager should have been returned by OS object")
		assert_not_equal(0, processmanager.processes().length, "The list of processes returned by the processmanager was empty")
	end
	
end
