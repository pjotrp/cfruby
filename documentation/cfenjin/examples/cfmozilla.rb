# Check the permissions of the Mozilla installation
#
# This Cfruby script is used in production systems.

package 'mozilla'

files:

  # ---- Make sure sites can not add malicious code
  /usr/lib/mozilla/chrome o=root g=root m=555 rec=inf act=fixdirs
  /usr/lib/mozilla/chrome o=root g=root m=444 rec=inf act=fixplain
  /usr/lib/mozilla/components o=root g=root m=555 rec=inf act=fixdirs
  /usr/lib/mozilla/components o=root g=root m=444 rec=inf act=fixplain
