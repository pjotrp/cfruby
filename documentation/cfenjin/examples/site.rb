# Example of a site specific file. 
#
# Warning: DO NOT USE THIS - it will overwrite your settings.
#
# Author:: Pjotr Prins
# Copyright:: July 2007
# License:: Ruby License

# Force dry run

@cf.dry_run = true
@cf.cfp_logger.notify VERBOSE_MINOR,'Example of cfruby run (dry_run only)'

# ---- Fake resolver settings
$resolv_domain    = 'yourdomain'
$resolv_ns1       = '10.0.0.2'

# ---- Fake time server settings
$timeserver       = '10.0.0.2'

groups:

	myworkstation = ( hostname1 hostname2 )
	myserver      = ( hostname3 )
