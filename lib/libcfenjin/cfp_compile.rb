# This class compiles the Cfruby script code, catches errors etc.

require 'libcfenjin/cfp_translate'
require 'libcfenjin/cfrubyruntime'

module Cfruby

	class Cfp_Compile

		def initialize cf,parser=nil
			@cf = cf
			@parser = parser
		end

		# Takes a piece of +code+ and compiles it - after successful compilation
		# the code-snippet is ready for execution. When +do_eval+ is false the
		# actual evaluation is omitted (no error checking!)

		def do_compile code, do_eval=true
			@cf.cfp_logger.trace TRACE_ENGINE,"Compiling #{code.fn} action #{code.action}"
			begin
				# Translate Cfruby style code into plain Ruby
				translator = Cfp_Translate.new(@cf,@parser)
				# Translate conditional blocks
				lines = translator.conditionals(code)
				# Line by line translation, depending on function - i.e. control, files, tidy etc.
				translated_lines = []
				# code.each do | line,num |
				lines.each do | line |
					translated_lines.push translator.do_translate(code.action,line)
				end
				# Encapsulate teh code into a class object
				buf = code.encapsulate(translated_lines).join("\n")
				@cf.cfp_logger.trace TRACE_ALL,buf
				eval buf if do_eval
			rescue SyntaxError, RuntimeError
				msg = 'ERROR cfscript ',code.fn," line #{code.linenum} - #{$!}\n"
				code.dump
				@cf.cfp_logger.error LOG_CRIT,msg,'cfruby'
				raise
			end
			buf
		end

		# Dump parsed and compiled code (100% Ruby)
		def dump_compiled code
			buf = do_compile code,false
			print buf,"\n"
		end

	end

end
