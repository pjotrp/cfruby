# Manager class for the Cfruby engine loads all the scripts, parses
# them into code snippets, compiles and executes. Normally invocation
# happens in that order - see bin/cfruby for an example.
#
# Author:: Pjotr Prins
# Copyright:: July 2007
# License:: Ruby License

require 'libcfenjin/cfp_codetree'
require 'libcfenjin/cfp_parser'
require 'libcfenjin/cfp_compile'
require 'libcfenjin/cfp_execute'
require 'libcfenjin/parser'

module Cfruby

	class Cfp_Manager

		# attr_reader   :codetree

		def initialize cf
			@cf = cf
			@codetree = Cfp_Codetree.new cf
			@cfp_parser = Cfp_Parser.new cf,@codetree
			@parser   = Parser.new cf
		end

		# Parse +site+ and +filelist+ into +codetree+

		def parse site,filelist=[]
			@cfp_parser.do_parse site
			filelist.each do | fn |
				@cfp_parser.do_parse fn
			end
		end

		# Compile all code in +sourcetree+
		def compile
			compile = Cfp_Compile.new @cf,@parser
			@codetree.each do | code |
				compile.do_compile code
			end
		end

		# Execute all code in +sourcetree+ - see +Cfp_code.dump+
		def execute
			exec = Cfp_Execute.new @cf
			@codetree.each_exec do | code |
				exec.do_execute code
			end
			@cf.classlist.dump @cf.cfp_logger
		end

		# Dumps code-snippets tree
		def dump
			@cfp_parser.dump
		end

		# Dumps compiled snippets - see +Cfp_code.dump_compiled+
		def dump_compiled
			compile = Cfp_Compile.new @cf
			@codetree.each do | code |
				compile.dump_compiled code
			end
		end

	end

end
