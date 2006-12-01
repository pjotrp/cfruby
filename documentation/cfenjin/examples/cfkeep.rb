# Copy some configuration files into a backup directory - in fact you can use
# this strategy for files that are edited (by hand) at system installation or
# prove to be not so handy to maintain in Cfruby like CRON, /etc/modules,
# network configuration, /etc/fstab etc.
#
# These files get copied by hostname into the configuration tree -
# so you still have a historic record.
#
# Assumes $sitepath has been set in site.rb
#
# This Cfruby script is used in production systems.

control:

	raise 'Variable archive has not been defined' if $archive==nil
	@realuser = @user
	@realuser = ENV['SUDO_USER'] if ENV['SUDO_USER'] != nil
	@destdir = $archive
	@hostspec = @destdir+'/'+@hostname+'_'

directories:

	@destdir m=700 o=@realuser

files:

	@destdir m=700 o=@realuser act=fixdirs rec=inf
	@destdir m=600 o=@realuser act=fixplain rec=inf
	
copy:

	/etc/fstab dest=@hostspec+'fstab' m=600 backup=false
	/etc/lilo.conf dest=@hostspec+'lilo.conf' m=600 backup=false
	/boot/grub/menu.lst dest=@hostspec+'grub_menu.lst' m=600 backup=false
	/boot/courier/imapd.cnf dest=@hostspec+'courier_imapd.cnf' m=600 backup=false
	/etc/cups/printers.conf dest=@hostspec+'printers.conf' m=600 backup=false
	/etc/X11/XF86Config dest=@hostspec+'XF86Config' m=600 backup=false
	/etc/X11/XF86Config-4 dest=@hostspec+'XF86Config-4' m=600 backup=false
	/var/spool/cron/crontabs/root dest=@hostspec+'crontab_root' m=600 backup=false
	/etc/wlan/wlan.conf dest=@hostspec+'wlan.conf' m=600 backup=false

	linux.apple_computer::

	  /etc/pbbuttonsd.conf dest=@hostspec+'pbbuttonsd.conf' m=600 backup=false
		
	debianlinux::
	
		/etc/modules dest=@hostspec+'modules' m=600 backup=false
		/etc/network/interfaces dest=@hostspec+'interfaces' m=600 backup=false

