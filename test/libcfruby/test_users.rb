#!/usr/bin/env ruby
# Unit Tests for filedit module

$: << File.dirname(__FILE__) + '/../../lib'

require 'test/unit'
require 'libcfruby/os'
require 'libcfruby/users'



# Tests the Checksum::Checksum class
class TC_OS < Test::Unit::TestCase

	def setup()
		@manager = get_os.get_user_manager()
	end
	
	
	def teardown()
	end
	
	
	def get_os()
		factory = Cfruby::OS::OSFactory.new()
		return(factory.get_os())
	end
	
	
	def test_users()
		userlist = nil
		assert_nothing_raised("Error raised when getting the user list") {
			userlist = @manager.users()
		}
		assert_not_nil(userlist)
		assert_not_equal(0, userlist.length, "Userlist contains no users")
		rootuser = userlist['root']
		assert_not_nil(rootuser)
		assert_equal(0, rootuser.uid, "Root users uid not = 0")
	end
	
	
	def test_groups()
		grouplist = nil
		assert_nothing_raised("Error raised when getting the group list") {
			grouplist = @manager.groups()
		}
		assert_not_nil(grouplist)
	end
	
	
	def test_user?()
		assert_equal(true, @manager.user?('root'), "user root was not found")
		assert_equal(false, @manager.user?('vsjha;ejlkjfuia'))
	end
	
	
	def test_group?()
		assert_equal(true, @manager.group?('bin'))
		assert_equal(false, @manager.group?('vsjha;ejlkjfuia'))
	end
	
	
	def test_get_uid()
		assert_equal(0, @manager.get_uid('root'))
	end


	def test_get_gid()
		if(get_os['name'] =~ /linux/i)
			assert_equal(0, @manager.get_gid('root'))
		else
			assert_equal(0, @manager.get_gid('wheel'))
		end
	end
	
	
	def test_addremove_user()
		if(Process.euid == 0)
			assert_nothing_raised("Error adding user") {
				@manager.add_user("lijygrdwa", "tyhnmjdu37465232")
			}
			assert_equal(true, @manager.user?("lijygrdwa"), "Error adding user - user could not be found in userlist after add")
			
			assert_nothing_raised("Error deleting user") {
				@manager.delete_user("lijygrdwa")
			}
			assert_equal(false, @manager.user?("lijygrdwa"), "Error deleting user - user could still be found in userlist after delete")
		end
	end

end
