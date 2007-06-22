# Sets up the squid package if it has been installed. Also downloads
# the adzapper package (@@FIXME).
#
# This Cfruby script is used in production systems.
#
# Author:: Pjotr Prins
# Copyright:: July 2007
# License:: Ruby License

package 'squid'

exit_script if !hasuser?('proxy')

directories:

		/var/spool/squid o=proxy g=root m=0750
		/var/log/squid   o=proxy g=root m=0750

copy:

	adzapper::
	
		http://adzapper.sourceforge.net/scripts/squid_redirect dest=/etc/squid/squid_redirect o=proxy g=root m=555

files:

	any::

		/etc/squid/squid.conf o=proxy g=root m=400

	adzapper::
	
		/etc/squid/squid_redirect o=proxy g=root m=500

editfiles:

	any::
	
		@ef = EditFile.new "/etc/squid/squid.conf"
		@ef.Warning
		@ef.ReplaceAll "^(\#\s?)?http_port.*","http_port 8080"
		@ef.ReplaceAll "^(\#\s?)?cache_mgr.*","cache_mgr #{$webmaster_email}" if $webmaster_email
		if $lan_ip
			@ef.ReplaceAll "^(\#\s?)?acl our_networks src.*", "acl our_networks src #{$lan_ip}/#{$lan_netmask}" 
			@ef.ReplaceAll "^(\#\s?)?http_access allow our_networks","http_access allow our_networks"
		end

		@ef.ReplaceAll "^(\#\s+TAG:\s)?visible_hostname.*","visible_hostname #{@hostname}"
			 
	adzapper::
		
		@ef.ReplaceAll "^(\#\s+TAG:\s)?redirect_program.*","redirect_program /etc/squid/squid_redirect"
		
		# ---- The alternative is to introduce a deny list:
		# ef.AppendIfNoSuchLine "acl webads dstdom_regex \"/etc/squid/webads.dst\""
		# ef.AppendIfNoSuchLine "http_access deny webads"

	any::
		
		@ef.write

shellcommands:

	if @ef.changed?
		`/etc/init.d/squid stop`
		`/etc/init.d/squid start`
	end
