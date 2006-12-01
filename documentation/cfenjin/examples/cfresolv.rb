# Hard codes the resolver file if the machine is not in the dhcpclient
# class. Note the $resolv_ns1 value has to be set.
#
# This Cfruby script is used in production systems.

control:

	!dhcpclient::
	
		raise "Name server not defined in variable $resolv_ns1!" if !$resolv_ns1

editfiles:

	!dhcpclient::
 
		ef = EditFile.new "/etc/resolv.conf"
		ef.AutoCreate
		ef.EmptyEntireFilePlease
		ef.Warning
		ef.AppendIfNoSuchLine "domain #{$resolv_domain}"
		ef.AppendIfNoSuchLine "search #{$resolv_domain}"
		ef.AppendIfNoSuchLine "nameserver #{$resolv_ns1}"
		ef.AppendIfNoSuchLine "nameserver #{$resolv_ns2}" if $resolv_ns2
		ef.AppendIfNoSuchLine "nameserver #{$resolv_ns3}" if $resolv_ns3
		ef.write
