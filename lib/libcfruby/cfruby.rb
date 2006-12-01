# Author:: David Powers
# Copyright:: November, 2004
# License:: Ruby License
#

require 'libcfruby/flowmonitor'

# Base module for all Cfruby library modules
module Cfruby # :nodoc:[all]

	# base class for all Cfruby Exceptions
	class CfrubyError < StandardError
		def initialize(msg=nil)
			super(msg)
			Cfruby.controller.exception(message())
		end
	end

	@controller = FlowMonitor::Controller.new()

	def Cfruby.controller
		return(@controller)
	end

end
