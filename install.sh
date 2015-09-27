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
	install -p -m 0550 trop.sh trop.awk ${PREFIX}        && \
	install -p -m 0640 README LICENSE trackers ${PREFIX} && \
	install -p -m 0770 tropriv.sh ${PREFIX}              || err 'failed to install files'
	install -g 0 -o 0 -m 0644 trop.1 /usr/local/man/man1/ && gzip /usr/local/man/man1/trop.1 \
	err \"couldn't install man page\"
	ln -s ${PREFIX}/trop.sh ${TROP_LN_FILE} || err \"couldn't link trop.sh\"
	"
else
    [ -d "$PREFIX" ] || mkdir "${PREFIX}"
    [ $tlnf -eq 1 ] && { echo "removing ${TROP_LN_FILE} to link trop.sh" ; rm -f ${TROP_LN_FILE} \
                                || err "failed to remove \`${TROP_LN_FILE}\"" ;}
    install -p -m 0550 trop.sh trop.awk ${PREFIX}        && \
	install -p -m 0640 README LICENSE trackers ${PREFIX} && \
	install -p -m 0770 tropriv.sh ${PREFIX}              || err 'failed to install files'
	echo 'Enter root credentials'
	su -m root -c \
	" 
	install -g 0 -o 0 -m 0640 trop.1 /usr/local/man/man1/ && gzip /usr/local/man/man1/trop.1 \
	|| err \"couldn't install man page\"
	"
    ln -s ${PREFIX}/trop.sh ${TROP_LN_FILE} || err "couldn't link trop.sh"
fi

exit 0
