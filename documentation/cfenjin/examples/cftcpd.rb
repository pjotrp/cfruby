# Set tcp wrapper configuration to the minimum (deny all), except
# for the hosts listed in String $sshd_hosts
#
# This Cfruby script is used on production systems.

package 'tcpd','tcp_wrappers'

# exit_script if $sshd_hosts == nil

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

