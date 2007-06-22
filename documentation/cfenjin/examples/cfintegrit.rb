# If integrit is installed sets up directories and copies a standard
# configuration file from the masterfiles directory
#
# This Cfruby script is used in production systems.
#
# Author:: Pjotr Prins
# Copyright:: July 2007
# License:: Ruby License

package 'integrit'

directories:

	/etc/integrit o=root g=root m=0700
	/var/lib/integrit o=root g=root m=0700

copy:

	@sourcepath+'/masterfiles/integrit.conf' dest=/etc/integrit/integrit.conf
