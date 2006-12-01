# One example of bulk editwriting of network configuration scripts.
# 
# NOTE: This is one implementation - a better can be found in cfnetwork1.rb!
#
# NOTE: This example needs modification.

editfiles:

	s01::

		@ef = EditFile.new '/etc/sysconfig/network/ifcfg-eth-id-00:0e:0c:30:b5:fb'
	@ef.ReplaceAllAppend "^STARTMODE=.*","STARTMODE=\'manual\'"
		@ef.write

	s05::

		@ef = EditFile.new '/etc/sysconfig/network/ifcfg-eth-id-00:07:e9:24:d8:f1'
	@ef.ReplaceAllAppend "^STARTMODE=.*","STARTMODE=\'manual\'"
		@ef.write

	s06::

		@ef = EditFile.new '/etc/sysconfig/network/ifcfg-eth-id-00:07:e9:24:cf:85'
	@ef.ReplaceAllAppend "^STARTMODE=.*","STARTMODE=\'manual\'"
		@ef.write

	s07::

		@ef = EditFile.new '/etc/sysconfig/network/ifcfg-eth-id-00:07:e9:24:d9:1d'
	@ef.ReplaceAllAppend "^STARTMODE=.*","STARTMODE=\'manual\'"
		@ef.write

	s08::

		@ef = EditFile.new '/etc/sysconfig/network/ifcfg-eth-id-00:07:e9:24:df:9d'
	@ef.ReplaceAllAppend "^STARTMODE=.*","STARTMODE=\'manual\'"
		@ef.write

	s09::

		@ef = EditFile.new '/etc/sysconfig/network/ifcfg-eth-id-00:07:e9:05:84:e9'
	@ef.ReplaceAllAppend "^STARTMODE=.*","STARTMODE=\'manual\'"
		@ef.write

	s10::

		@ef = EditFile.new '/etc/sysconfig/network/ifcfg-eth-id-00:07:e9:24:df:65'
			@ef.ReplaceAllAppend "^STARTMODE=.*","STARTMODE=\'manual\'"
		@ef.write

shellcommands:

	eth1down::

		docommand 'rcnetwork stop eth1'
