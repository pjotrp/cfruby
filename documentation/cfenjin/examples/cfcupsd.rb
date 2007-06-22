# Configure cups, if it is installed
#
# This Cfruby script is used in production systems.
#
# Author:: Pjotr Prins
# Copyright:: July 2007
# License:: Ruby License

package 'cupsys', 'cups'

links:

	/usr/bin/lpr -> /usr/bin/lpr_cups

control:

@cups_root = " \
Order Deny,Allow \
Deny From All \
@cups_root \
"

@cups_admin = " \
# \
# You definitely will want to limit access to the administration functions. \
# The default configuration requires a local connection from a user who \
# is a member of the system group to do any admin tasks.  You can change \
# the group name using the SystemGroup directive. \
# \
\
AuthType Basic \
AuthClass System \
\
## Restrict access to local domain \
Order Deny,Allow \
Deny From All \
\
#Encryption Required \
"

	$cups_allow = '127.0.0.1' if !$cups_allow
	$cups_admin = '127.0.0.1' if !$cups_admin
	$cups_allow.each do | netw |
		@cups_root += "Allow From #{netw}\n"
	end
	$cups_admin.each do | netw |
		@cups_admin += "Allow From #{netw}\n"
	end

editfiles:

	@ed = EditFile.new '/etc/cups/cupsd.conf'
	@ed.ReplaceSection '\<Location\ \/\>', '\</Location\>', @cups_root
	@ed.ReplaceSection '\<Location\ \/admin\>', '\</Location\>', @cups_admin		
	@ed.write

tidy:

  /var/spool/cups pattern=* age=14 recurse=inf rmdirs=true
	
shell:

	# ---- planned feature:  @@FIXME
	# restart 'cups' if @ed.changed?
