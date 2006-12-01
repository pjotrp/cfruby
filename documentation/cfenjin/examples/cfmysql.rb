# An example for mysql configuration using Cfruby

package 'mysql'

exit_script if !hasuser?('mysql')

directories:

	/var/opt/mysql o=mysql g=mysql m=750
