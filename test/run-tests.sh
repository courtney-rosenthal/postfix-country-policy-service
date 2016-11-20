#!/bin/sh

# Uncomment for debug output.
#VFLAG='-v'

/usr/sbin/postmap ../access-country.example

for file in *.req ; do
	echo ""
	echo "*** $file ***"
	perl ../pcps.pl $VFLAG -t -M ../access-country.example.db < $file
done
