#!/usr/bin/env ruby
# Unit Test runner for cfruby
require 'optparse'
require 'ostruct'

$: << File.dirname(__FILE__) + '/../lib'

options = OpenStruct.new()
opts = OptionParser.new() { |opts|
	opts.on_tail("-h", "--help", "Print this message") {
		print(opts)
		exit()
	}

	opts.on("-c", "--create", "create data for regression tests") {
			options.create = true
	}

	opts.on("-C", "--coverage", "Generate test coverage information (requires coverage gem)") { 
		require 'rubygems'
		require 'coverage'
	}

	opts.on("-p", "--parser-ony", "Only run Cfenjin parser tests") {
		options.parser_only = true
	}
}
opts.parse(ARGV)

# Remove these, otherwise the unit test handler balks...
ARGV.delete('--coverage')
ARGV.delete('-C')
ARGV.delete('--create')
ARGV.delete('-c')
ARGV.delete('-p')
ARGV.delete('--parser-only')


require 'test/unit'


if(Process.euid != 0)
	print("Some tests require root privileges to run, those tests will be skipped silently\n")
end

print "Use the -c switch to create new regression tests\n"

# ---- this should be fixed...
if !File.directory? 'libcfruby'
	raise 'Only run from within ./test directory'
end

if (!options.parser_only)
	# require everything in the lib directories explicitely
	Dir.glob("#{File.dirname(__FILE__)}/../lib/libcfruby/*.rb").each() { |filename|
		require("libcfruby/#{filename[/\/([^\/]*)\.rb$/,1]}")
	}

	# disable the default logger from cfrubyscript
	Cfruby.controller.unregister_all()

	Dir.glob("#{File.dirname(__FILE__)}/../lib/libcfenjin/*.rb").each() { |filename|
		require("libcfenjin/#{filename[/\/([^\/]*)\.rb$/,1]}")
	}

	Dir.glob("#{File.dirname(__FILE__)}/libcfruby/test_*.rb").each() { |filename|
		require(filename)
	}

	# Dir.glob("#{File.dirname(__FILE__)}/librcs/test_*.rb").each() { |filename|
	# 	require(filename)
	# }
end

require 'libcfenjin/test/regression'
Cfruby.regressiontest_create(options.create)

Dir.glob("#{File.dirname(__FILE__)}/cfenjin/test_*.rb").each() { |filename|
	require(filename)
}


