#! /bin/sh

if [ ! -d './scripts' ]; then
	echo "Only execute this script from the source root"
	exit 1
fi
cd ./lib/libcfruby
rdoc -a -p -W 'http://rubyforge.org/viewvc/lib/libcfruby/%s?root=cfruby&view=markup' -o ../../documentation/website/cfrubylib
