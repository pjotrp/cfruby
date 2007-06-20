# Sets the ntp package (network time protocoal), if installed.
#
# Assumes $timeserver has been set in site.rb
#
# This Cfruby script is used in production systems.

package 'ntp'

control:

	raise "$timeserver not set" if $timeserver == nil

editfiles:

	@ef = EditFile.new "/etc/ntp.conf"
	@ef.AutoCreate
	@ef.EmptyEntireFilePlease
	@ef.Warning
	@ef.AppendIfNoSuchLine "server #{$timeserver}"
	@ef.AppendIfNoSuchLine "driftfile /var/log/ntp.drift"
	@ef.AppendIfNoSuchLine "logfile /var/log/ntp.log"
	@ef.write

shellcommands:

	`/etc/init.d/ntp restart`
	
