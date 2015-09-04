#!/bin/sh
set -e

# Be sure to be in the trop directory!

: ${PREFIX:=~/.trop}
[ -d "$PREFIX" ] || mkdir "${PREFIX}"

cp -p README LICENSE trop.sh trop.awk tropriv.sh trackers ${PREFIX} || { echo 'failed to copy files' ; exit 1 ;}

[ "$(id -u)" != '0' ] && { echo "Enter root credentials" ; su -m root -c \
"ln -s ${PWD}/trop.sh /usr/local/bin/trop" ;} || { echo "couldn't link trop.sh" ; exit 1 ;}
|| { ln -s ${PWD}/trop.sh /usr/local/bin/trop || { echo "couldn't link trop.sh" ; exit 1 ;} ;}

exit 0
