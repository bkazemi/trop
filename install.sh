#!/bin/sh
set -e

# Be sure to be in the trop directory!

: ${HOME:=~}
: ${PREFIX:=${HOME}/.trop}
: ${TROP_LN_FILE:=/usr/local/bin/trop}
tlnf=0
[ -e ${TROP_LN_FILE} ] && eval tlnf=1 $(stat -s ${TROP_LN_FILE}) \
|| eval $(stat -s ${TROP_LN_FILE%/*})

err () { echo "$@" ; exit 1 ;}

if [ $st_uid -eq 0 ] && [ $(id -u) -ne 0 ]; then
	echo 'Enter root credentials'
	su -m root -c \
	"
	[ -d \"$PREFIX\" ] || mkdir \"${PREFIX}\"
	[ $tlnf -eq 1 ] && { echo \"removing ${TROP_LN_FILE} to link trop.sh\" ; rm -f ${TROP_LN_FILE} \
                                || err \"failed to remove \\\`${TROP_LN_FILE}\\\"\" ;}
	cp -p README LICENSE trop.sh trop.awk tropriv.sh trackers ${PREFIX} || err 'failed to copy files'
	ln -s ${PREFIX}/trop.sh ${TROP_LN_FILE} || err \"couldn't link trop.sh\"
	"
else
    [ -d "$PREFIX" ] || mkdir "${PREFIX}"
    [ $tlnf -eq 1 ] && { echo "removing ${TROP_LN_FILE} to link trop.sh" ; rm -f ${TROP_LN_FILE} \
                                || err "failed to remove \`${TROP_LN_FILE}\"" ;}
    cp -p README LICENSE trop.sh trop.awk tropriv.sh trackers ${PREFIX} || err 'failed to copy files'
    ln -s ${PREFIX}/trop.sh ${TROP_LN_FILE} || err "couldn't link trop.sh"
fi

exit 0
