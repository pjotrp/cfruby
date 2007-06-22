# Stores a code snippet
#
# Author:: Pjotr Prins
# Copyright:: July 2007
# License:: Ruby License

require 'libcfenjin/cfrubyruntime'

module Cfruby

class Cfp_Code

	attr_reader :fn, :num, :action, :linenum, :code, :args

	# Code snipped in +fn+, block num +num+, block +action+ 
	# starting at +linenum+ containing +code+
	def initialize fn,num,action,argsp,linenum,code
		@fn      = fn
		@num     = num
		@action  = action
		@args    = argsp
		@args    = [] if !@args
		@linenum = linenum
		@code    = code
	end

	# Return each line with a line number
	def each
		num = 1
		@code.each do | line |
			yield line, @linenum+num
			num += 1
		end
	end

	# Return an array of (transated) source code lines encapsulated in a
	# class and method

	def encapsulate tlines
		a = []
		a.push "\tclass "+classname
		a.push "\tinclude CfrubyRuntime"
		a.push "\t\tdef "+methodname+"(#{@args.join(',')})"
		tlines.each do | line |
			a.push "\t\t\t"+line
		end
		a.push "\t\tend"
		a.push "\tend"
		a
	end

	# Dumps to source code of a snippet to stderr - when there is a
	# problem (for example # a syntax error during the compile
	# phase). When unit tests are running output is disabled.
	#
	# Output to stderr can be overridden by passing a file handle

	def dump handle=nil
		begin
			Test::Unit.class
			# if unit testing do nothing
		rescue NameError
			# if not unit testing
			handle = $stderr if handle == nil
			handle.print "\n==== Snippet #{@fn}-#{@action}-#{@num}(#{@args.join(',')}) ====\n"
			each do | line, num |
				handle.print "#{num.to_s.rjust(3)}: ",line,"\n"
			end
		end
	end

	def classname
		@fn.gsub(/\/|\./,'').capitalize
	end

	def methodname
		@action+@num.to_s
	end
end

end
