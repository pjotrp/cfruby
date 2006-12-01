# Checks the permissions of the named directory
#
# This Cfruby script is used on production systems.

package 'named','bind'

directories:

	/var/named m=0755
