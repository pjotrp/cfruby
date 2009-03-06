# This example maintains the sudo package. All members of the Array
# $admin_users are allowed to run 'sudo bash' (with password) and
# 'sudo (u)mount' without a password.
#
# This Cfruby script is used on production systems.
#
# Author:: Pjotr Prins
# Copyright:: July 2007
# License:: Ruby License

needpackage 'sudo'

control:

	@wheel = $admin_users.join(',')
  @timeout = $admin_sudo_timeout

editfiles:

	any::

	ef = EditFile.new '/etc/sudoers'
	ef.AutoCreate
	ef.EmptyEntireFilePlease
	ef.Warning
	ef.AppendIfNoSuchLine "Defaults timestamp_timeout="+@timeout if @timeout
	ef.AppendIfNoSuchLine "# User alias specification "
	ef.AppendIfNoSuchLine "User_Alias WHEEL="+@wheel if $admin_users
	ef.AppendIfNoSuchLine ""
	ef.AppendIfNoSuchLine "# Cmnd alias specification"
	ef.AppendIfNoSuchLine "Cmnd_Alias BASH=/bin/bash"
	ef.AppendIfNoSuchLine ""
	ef.AppendIfNoSuchLine "# User privilege specification"
	ef.AppendIfNoSuchLine "root    ALL=(ALL) ALL"
	ef.AppendIfNoSuchLine "WHEEL   ALL=BASH"

	usermount::

		ef.AppendIfNoSuchLine "WHEEL   ALL= NOPASSWD: /bin/mount, /bin/umount"

	any::

		ef.write

files:

	!debianlinux::
 
		/etc/sudoers m=0640 o=root g=root

	debianlinux::
	
		# ---- The Ruby way (native syntax)
		files '/etc/sudoers',{ 'm'=>0440, 'o'=>'root', 'g'=>'root' }
