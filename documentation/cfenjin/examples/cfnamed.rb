# Checks the permissions of the named directory
#
# This Cfruby script is used on production systems.
#
# Author:: Pjotr Prins
# Copyright:: July 2007
# License:: Ruby License

package 'named','bind'

directories:

	/var/named m=0755
