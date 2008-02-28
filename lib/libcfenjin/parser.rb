# Offers direct running of Cfruby commands
#
# Author:: Pjotr Prins
# Copyright:: July 2007
# License:: Ruby License

require 'libcfenjin/cfrubyruntime'
require 'libcfenjin/cfp_classes'
require 'libcfenjin/cfp_parserlogic'

module Cfruby

	class Parser

		include CfrubyRuntime
		include Cfp_ClassAccessor
		include Cfp_ParserLogic

		# Optionally pass in +Cfp_Stat+ object
		def initialize cf=nil
			@global_names = Array.new
			if @cf != nil and cf != nil
			  # print "PROBLEM\n"
				raise '@cf is already assigned in Parser!'
			end
			@cf = cf if cf != nil
			if @cf == nil
				# ---- Dummy assignment
				@cf = Cfp_Stat.new 
			end
		end

		# +run+ sends an action directly to the CfrubyRuntime mixed in
		# module.
		def run action,*args
			# print "Running #{action}"
			# p args
			send action,*args
		end

		# Just return the straight Ruby conversion
		def form action, *args
			send 'form_'+action,*args
		end

    def dump
      Cfp_parser::dump
    end

		# Run a links command using Cfruby style syntax - generalised by the
		# method_missing method:
		#
		# def links line
		#  eval(form_links(line))
		# end

		def method_missing methId,line
			raise "Can not find method '#{methId}'" if methId.to_s =~ /^form_/
			Cfruby.controller.inform('verbose', "Calling user defined action form_#{methId}")
			eval(send('form_'+methId.to_s,line))
		end

	end

end
