# The Parser loads a Cfruby script and converts the Cfengine-style
# syntax to plain Ruby. Futhermore it stores all the code pieces
# into the +codetree+.

require 'libcfenjin/cfrubyruntime'
require 'libcfenjin/cfp_editfilecached'

module Cfruby

class Cfp_Parser

	def initialize cf,codetree
		@cf = cf
		@codetree = codetree
	end

	# Parse the Cfruby code of a single +fn+ and add to the source tree - also add
	# the standard class initalisation method
	def do_parse fn
		@cf.cfp_logger.trace TRACE_ENGINE,"Parsing #{fn}"
		# ---- Create standard initilisation method
		@codetree.add fn,nil,'initialize',['cf','sourcepath','homepath','user'],0,[ '
			@cf=cf
			@hostname=@cf.hostname
			@sourcepath=sourcepath
			@home=homepath
			@user=user
		' ]
		
		# ---- Store source file into buffer
		f = File.new fn
		buf = []
		f.each_line do | line |
			buf.push line
		end
		# ---- Parse buffer
		action = 'control'  # default action
		num = 0
		blockstartline = 0
		linenum = 0
		snippet = Array.new
		buf.each do | line |
			linenum += 1
			l = line.chomp
			# @cf.cfp_logger.trace TRACE_ALL,l
			# ---- Parse for action: style syntax - but skip double colons
			if l.strip =~  /^(\S+[^:]):$/
				newaction = $1
				@codetree.add fn,num,action,nil,blockstartline,snippet
				blockstartline = linenum
				action = newaction
				num += 1
				snippet = Array.new
				next
			end
			snippet.push l
		end
		@codetree.add fn,num,action,nil,blockstartline,snippet
	end

	# See +Cfp_Code.dump+

	def dump
		@codetree.dump
	end

end


end
