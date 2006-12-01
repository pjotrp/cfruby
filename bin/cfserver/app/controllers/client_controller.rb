require 'yaml'

class ClientController < ApplicationController
	
	# takes a posting of client information, parses it, generates a
	# list of actions/scripts and returns it as the body
	def connect()
		# slurp it in via yaml
		@clientdata = YAML.load(params['clientdata'])
	end
	
end
