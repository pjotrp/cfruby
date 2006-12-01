# This is a test script which executes Cfruby commands by the interpreter.
# It should not make permanent changes to the system, can run on its own 
# and shows the state of the Cfruby interpreter.
#
# Run it as:
#
# ruby bin/cfruby documentation/examples/cftest.rb
#
# You can try the following switches:
#
#   --trace 1 (or 2 or 3)
#   --verbose 1 (or 2 or 3)

control:

	# Show we can run standard Ruby commands in a control block:
	# Make sure we are running from the source directory
	raise 'Run from source directory only!' if !File.exist? './bin/cfenjin'

control:

	# Show we can create a second control block and use a variable
	# specific to the location of the imported source file:
	raise 'Problem with local parameter @sourcepath' if !File.exist?(@sourcepath+'/cftest.rb')

groups:

	# Add a class - tell Cfruby that all machines run sshd
	sshd = ( any )

control:

	# Initiate a class level variable (that is local to this file)
	sshd.any::

		@masterfiles = @sourcepath+'/masterfiles'
		@playground = '/tmp/test/playground'
		@testln = @playground+'/testlink'
		@testln2 = @playground+'/testlink2'
		@tmpdir = @playground+'/tmp'
	
directories:

	@tmpdir m=777
	
links:

	# Call direct into the library
	link @sourcepath+'/masterfiles/cftest.txt',@testln

	# Use the Cfruby syntax
	@testln2 -> @sourcepath+'/masterfiles/cftest.txt'

	/tmp/testcfruby -> /tmp
	
control:

	# Cleanup using a straight Ruby command
	File.delete @testln

	# Cleanup using a cfrubylib command (with logging etc.)
	FileOps.delete @testln2
	FileOps.delete @testln2
	FileOps.delete '/tmp/testcfruby'

tidy:

	# Cleanup using Cfruby tidy
	@testln2

copy:

	# Call directly into the library
	copy "#{@masterfiles}/cftest.txt",@playground+"/cftest1.txt",{'m'=>0644}
	
	# With the Cfruby syntax
	@masterfiles+'/cftest.txt' dest=@playground+"/cftest2.txt" m=644 backup=false
	@masterfiles+'/cftest.txt' dest=@playground+"/cftest2.txt" m=644
	

editfiles:

	EditFile.edit @playground+'/cftest1.txt' do | f |
		f.Warning
		f.AppendIfNoSuchLine 'This is a test'
	end

files:

	@playground+'/cftest1.txt' m=660
	# non existing file
	/tmp/cftest1.txt m=640

tidy:

	@playground+'/cftest1.txt*'
	@playground+'/cftest2.txt*'
	@playground+'/cftest3.txt'
	@tmpdir rec=inf
	# non existing file
	/tmp/cftest1.txt

