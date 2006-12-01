# The Codetree class stores all Cfruby script snippets ordered by
# filename, actionnumber and action name (e.g. 'site.rb',0,'control')

require 'libcfenjin/cfp_code'

module Cfruby

class Cfp_Codetree

	def initialize cf
		@cf = cf
		@clist = Array.new
	end

	# Add a node to the codetree
	def add fn,num,action,args,linenum,sourcecode
		@cf.cfp_logger.trace TRACE_ENGINE,"Adding #{fn} action #{action}"
		@clist.push Cfp_Code.new(fn,num,action,args,linenum,sourcecode)
	end

	# Return the actual code snippet
	def each
		@clist.each do | code |
			yield code
		end
	end

	# Return the code snippets in execution order
	def each_exec
		@clist.each do | code |
			yield code
		end
	end

	# See +Cfp_Code.dump+
	def dump
		@clist.each do | code |
			code.dump
		end
	end

protected

	# ---- Create a classname from the +fn+ path
	# targetname = File.dirname fn
	# servicename = File.basename(fn).gsub(/\./,"_")
	# classname = mkclassname(targetname,servicename)
	# @cf.cfp_logger.trace TRACE_ENGINE,"Using unique classname #{classname}"

	# Create a unique Ruby classname from the path + filename (belongs in parser)
	#  	def mkclassname path,fn
	#  		relname=File.basename(path)
	#  		relname.capitalize+fn.capitalize
	#  	end

end

end
