# Checks the permissions for inetd.conf and disables a number of
# unsafe services by default
#
# This Cfruby script is used on production systems.
#
# Author:: Pjotr Prins
# Copyright:: July 2007
# License:: Ruby License

files:

	/etc/inetd.conf m=444

editfiles:

	@ed = EditFile.new '/etc/inetd.conf'

	@ed.HashCommentLinesContaining "finger"
	@ed.HashCommentLinesContaining "ftp\s"
	@ed.HashCommentLinesContaining "talk"
	@ed.HashCommentLinesContaining "rsync"
	@ed.HashCommentLinesContaining "telnet\s"
	@ed.HashCommentLinesContaining "ident"
	@ed.HashCommentLinesContaining "pop\s"
	@ed.HashCommentLinesContaining "swat"
	@ed.HashCommentLinesContaining "daytime"
	@ed.HashCommentLinesContaining "time\s"

	@ed.write

shellcommands:

	# restart 'inetd' if @ed.changed?
