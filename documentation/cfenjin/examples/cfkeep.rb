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
#
# Author:: Pjotr Prins
# Copyright:: July 2007
# License:: Ruby License

control:

  raise 'Variable archive has not been defined' if $archive==nil
  @realuser = @user
  @realuser = ENV['SUDO_USER'] if ENV['SUDO_USER'] != nil
  @destdir = $archive
  @hostspec = @destdir+'/'+@hostname+'_'

directories:

  @destdir o=@realuser m=700 o=@realuser

files:

  @destdir o=@realuser m=700 o=@realuser act=fixdirs rec=inf
  @destdir o=@realuser m=600 o=@realuser act=fixplain rec=inf shell=true
  
copy:

  /etc/fstab dest=@hostspec+'fstab' o=@realuser m=600 backup=false
  /etc/lilo.conf dest=@hostspec+'lilo.conf' o=@realuser m=600 backup=false
  /boot/grub/menu.lst dest=@hostspec+'grub_menu.lst' o=@realuser m=600 backup=false
  /boot/courier/imapd.cnf dest=@hostspec+'courier_imapd.cnf' o=@realuser m=600 backup=false
  /etc/cups/printers.conf dest=@hostspec+'printers.conf' o=@realuser m=600 backup=false
  /etc/X11/XF86Config dest=@hostspec+'XF86Config' o=@realuser m=600 backup=false
  /etc/X11/XF86Config-4 dest=@hostspec+'XF86Config-4' o=@realuser m=600 backup=false
  /etc/X11/xorg.conf dest=@hostspec+'xorg.conf' o=@realuser m=600 backup=false
  /var/spool/cron/crontabs/root dest=@hostspec+'crontab_root' o=@realuser m=600 backup=false
  /etc/wlan/wlan.conf dest=@hostspec+'wlan.conf' o=@realuser m=600 backup=false

  debianlinux::

    /etc/modprobe.d/blacklist dest=@hostspec+'modprobe_blacklist' o=@realuser m=600 backup=false
    /etc/rc.local dest=@hostspec+'rc.local' o=@realuser m=600 backup=false

  linux.apple_computer::

    /etc/pbbuttonsd.conf dest=@hostspec+'pbbuttonsd.conf' o=@realuser m=600 backup=false
    
  debianlinux::
  
    /etc/modules dest=@hostspec+'modules' o=@realuser m=600 backup=false
    /etc/network/interfaces dest=@hostspec+'interfaces' o=@realuser m=600 backup=false
