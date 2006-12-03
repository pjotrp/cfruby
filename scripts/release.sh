#!/bin/sh

if [ ! -d test ]; then echo "Run from base directory!" ; exit ; fi

ruby ./scripts/cfruby.gemspec

# Create tar ball of sources
version=`cat ./bin/VERSION`
tar cvzf cfruby-$version.tgz --exclude *.svn* bin/* test/* documentation/* graphics/* lib/* 

