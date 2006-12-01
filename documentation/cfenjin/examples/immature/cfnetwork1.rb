# Some machines with dual network interfaces have both interfaces 
# configured, but only the first one connected. The second interface
# is already configured so it can be easily activated if necessary.
# However if the unconnected interface is active, this can cause 
# network problems. Therefore we turn it actively off.
#
# This is just an example of a Cfruby script using more advanced
# configuration concepts.
#
# NOTE: this script needs to be modified for later cfenjin editions

@addr = Hash.new
@addr['s01'] = '00:0e:0c:30:b5:fb'
@addr['s05'] = '00:07:e9:24:d8:f1'
@addr['s06'] = '00:07:e9:24:cf:85'
@addr['s07'] = '00:07:e9:24:d9:1d'
@addr['s08'] = '00:07:e9:24:df:9d'
@addr['s09'] = '00:07:e9:05:84:e9'
@addr['s10'] = '00:07:e9:24:df:65'

editfiles:

	# --- Here we add a function into the 'editfiles' block:
	def edit addr
		ef = EditFile.new '/etc/sysconfig/network/ifcfg-eth-id-'+addr
		ef.ReplaceAllAppend "^STARTMODE=.*","STARTMODE=\'manual\'"
		ef.write
	end

	@addr.each do | host, addr |
		edit(addr) if isa?(host)
	end

shellcommands:

	eth1down::

		stop 'network','','eth1'
