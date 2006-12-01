# Example script for configuring ssh using Cfruby
#
# This Cfruby script is used in production systems.

package 'ssh','openssh'

control:

		if File.directory? '/etc/ssh'
			@ssh_etc = '/etc/ssh'
		else
			@ssh_etc = '/etc'
		end
	 
files:

		@ssh_etc+'/ssh_config' o=root m=0644
		@ssh_etc+'/sshd_config' o=root m=0600
		@ssh_etc+'/ssh_host_dsa_key' o=root m=0400
		@ssh_etc+'/ssh_host_rsa_key' o=root m=0400
		if File.exist? @ssh_etc+'/ssh_host_key'
			@ssh_etc+'/ssh_host_key' o=root m=0400
		end

editfiles:

		@ef = EditFile.new @ssh_etc+'/sshd_config'
		@ef.ReplaceAllAppend "UsePrivilegeSeparation [Nn].*","UsePrivilegeSeparation yes"
		@ef.ReplaceAllAppend "PermitRootLogin\s+[yY].*","PermitRootLogin no"
		@ef.ReplaceAllAppend "PermitEmptyPasswords[[:space:]]+[yY].*","PermitEmptyPasswords no"
		@ef.ReplaceAllAppend "X11Forwarding[[:space:]]+[nN].*","X11Forwarding yes"
		@ef.ReplaceAllAppend "^AllowGroups[[:space:]]+.*","AllowGroups #{$sshd_groups}" if $sshd_groups
		@ef.ReplaceAllAppend "^AllowUsers[[:space:]]+.*","AllowUsers #{$sshd_users}" if $sshd_users

    sshd_keysonly::
        @ef.ReplaceAllAppend "UsePAM[[:space:]]+[yY].*","UsePAM no"
    !sshd_keysonly::
        @ef.ReplaceAllAppend "UsePAM[[:space:]]+[nN].*","UsePAM yes"

    any::
		  @ef.write
			
shellcommands:

  if @ef.changed?
	  $stderr.print "Notice: You should restart the sshd service!\n"
  end

