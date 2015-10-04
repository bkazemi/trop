#!/bin/sh
set -e

# Be sure to be in the trop directory!

err () { echo "install.sh stopped - error:" "$@" ; exit 1 ;}

: ${PREFIX:=${HOME}/.trop}

[ -e "${PREFIX}" ] && { [ -f "${PREFIX}" ] && err 'PREFIX is a file' || \
err 'PREFIX path already exists. To be safe, manually remove this directory and restart install.sh' ;}
eval $(stat -qs ${PREFIX%/*})
[ -z "$st_uid" ] && err 'bad path for PREFIX'
[ $(id -u) -ne $st_uid ] && err "please login to \`$(id -un $st_uid)' to install trop"

: ${TROP_LN_FILE:=/usr/local/bin/trop}
# install.sh will not create intermediate directories.
[ ! -e ${TROP_LN_FILE%/*} ] && err 'invalid path for TROP_LN_FILE'
[ -e ${TROP_LN_FILE}      ] && err 'TROP_LN_FILE file already exists'

mkdir ${PREFIX}
install -p -m 0550 trop.sh trop.awk trop_torrent_done.sh ${PREFIX} && \
install -p -m 0640 README LICENSE trackers               ${PREFIX} && \
install -p -m 0770 tropriv.sh trop.conf                  ${PREFIX} || err 'failed to install files'

if [ $st_uid -eq 0 ]; then
	install -g 0 -o 0 -m 0640 trop.1 /usr/local/man/man1/ && gzip /usr/local/man/man1/trop.1 \
	|| err "couldn't install man page"
	ln -s ${PREFIX}/trop.sh ${TROP_LN_FILE} || err "couldn't link trop.sh"
else
	echo 'Enter root credentials'
	su -m root -c \
	"
	install -g 0 -o 0 -m 0640 trop.1 /usr/local/man/man1/ && gzip /usr/local/man/man1/trop.1 \
	|| exit 1
	ln -s ${PREFIX}/trop.sh ${TROP_LN_FILE} || exit 1
	" || err 'failed to install man page or link trop.sh'
fi

echo "trop installed to \`${PREFIX}' successfully"
exit 0
