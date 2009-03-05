# Set tcp wrapper configuration to the minimum (deny all), except
# for the hosts listed in String $sshd_hosts
#
# This Cfruby script is used on production systems.
#
# Author:: Pjotr Prins
# Copyright:: July 2007
# License:: Ruby License

package 'tcpd','tcp_wrappers'

control:

  raise 'Allow hosts for sshd not defined sshd_hosts' if $sshd_hosts == nil or $sshd_hosts == ''

editfiles:

	EditFile.edit '/etc/hosts.deny' do | f |
		f.AutoCreate
		f.EmptyEntireFilePlease
		f.Warning
		f.AppendIfNoSuchLine 'ALL: ALL'
	end

	EditFile.edit '/etc/hosts.allow' do | f |
		f.AutoCreate
		f.EmptyEntireFilePlease
		f.Warning
		f.AppendIfNoSuchLine "sshd: #{$sshd_hosts}" if $sshd_hosts != nil
	end
