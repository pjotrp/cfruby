# Translation class converts Cfengine-style syntax to plain (100%)
# Ruby These methods are called from the compile step - and therefore
# do not execute.

require 'libcfenjin/parser'

class Cfp_Translate

	def initialize cf,parser=nil
		@cf = cf
		@parser = parser
		@parser = Cfruby::Parser.new(@cf) if @parser == nil
	end

	# Each executable Cfruby line comes through this method for parsing - returns the
	# translated version - as related to the action

	def do_translate action,line
		if action != 'initialize'
			send(action,line)
		else
			line
		end
	end

	def groups line
		@parser.form_groups line
	end

	def control line
		@parser.form_control line
	end

	def files line
		@parser.form_files line
	end

	def links line
		@parser.form_links line
	end

	def copy line
		@parser.form_copy line
	end

	def tidy line
		@parser.form_tidy line
	end

	def editfiles line
		@parser.form_editfiles line
	end

	def directories line
		@parser.form_directories line
	end

	def shellcommands line
		# Cfruby.controller.inform('debug', "shell command: #{line}") if line.strip != ''
		@parser.form_shellcommands line
	end

	def conditionals code
		r = []
		blocklist = []  # ---- Tracks blocks for inserting 'end'
		code.each do | line, num |
			if @parser.conditional? line
				blocklist.push [ r.size, line.strip ] # ---- note position for end of block
				line = @parser.form_conditional line
			end
			r.push line
		end

		# ---- Insert block ends
		relpos = 0
		if blocklist.size > 0
			tmp,first = blocklist.shift # --- Shift off first block start
			blocklist.each do | num, s |
				r.insert(num+relpos,'  end # ---- '+s)
				relpos += 1
			end
			r.push 'end # ---- '+first
		end
		r
	end

	# This method is reached when an action does not exist (e.g. 
	# myshellcommands) - in this implementation it sends out a 
	# warning and comments out the code - so it will compile
	def method_missing(methId,line)
		 Cfruby.controller.inform('verbose', "Warning: undefined user action #{methId} - #{line}") if line.strip != ''
		'# Not recognised: '+line
	end
end
