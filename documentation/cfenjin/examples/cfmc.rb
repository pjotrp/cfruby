# If the 'mc' package is installed sets the internal editor to 
# the one set in the shell (EDITOR).
#
# This Cfruby script is used in production systems.
#
# Author:: Pjotr Prins
# Copyright:: July 2007
# License:: Ruby License

package 'mc'

editfiles:

	ef = EditFile.new "#{@home}/.mc/ini" 
	ef.ReplaceAll "^use_internal_edit=1","use_internal_edit=0"
	ef.write
