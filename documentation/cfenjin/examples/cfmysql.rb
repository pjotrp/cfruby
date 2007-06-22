# An example for mysql configuration using Cfruby
#
# Author:: Pjotr Prins
# Copyright:: July 2007
# License:: Ruby License

package 'mysql'

exit_script if !hasuser?('mysql')

directories:

	/var/opt/mysql o=mysql g=mysql m=750
