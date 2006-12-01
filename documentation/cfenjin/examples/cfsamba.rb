# Example of copying a samba configuration file from the masterfiles
# directory, and setting permissions

package 'samba'

copy:

	samba::

		copy "#{$masterfiles}/#{@hostname}_smb.conf","/etc/smb.conf",{'m'=>0444}

files:

	/etc/private m=0500
	/etc/private/smbpasswd m=0600
	/etc/private/secrets.tdb m=0600

tidy:

  /var/log/samba pattern=* age=14 recurse=inf rmdirs=true links=traverse
	
