#!/bin/sh
set -e

# Be sure to be in the trop directory!

err () { echo "install.sh stopped - error:" "$@" ; exit 1 ;}

: ${HOME:=~}
: ${PREFIX:=${HOME}/.trop}

[ -e "${PREFIX}" ] && { [ -f "${PREFIX}" ] && err 'PREFIX is a file' || \
err 'PREFIX path already exists. To be safe, manually remove this directory and restart install.sh' ;}
eval $(stat -qs ${PREFIX%/*})
[ -z "$st_uid" ] && err 'bad path for PREFIX'
[ $(id -u) -ne $st_uid ] && err "please login to \`$(id -un $st_uid)' to install trop"

: ${TROP_LN_FILE:=/usr/local/bin/trop}
# install.sh will not install intermediate directories.
[ ! -e ${TROP_LN_FILE%/*} ] && err 'invalid path for TROP_LN_FILE'

[ -d "$PREFIX" ] || mkdir "${PREFIX}"
[ -e ${TROP_LN_FILE} ] && { echo "removing ${TROP_LN_FILE} to link trop.sh" ; rm -f ${TROP_LN_FILE} ;}

install -p -m 0550 trop.sh trop.awk        ${PREFIX} && \
install -p -m 0640 README LICENSE trackers ${PREFIX} && \
install -p -m 0770 tropriv.sh              ${PREFIX} || err 'failed to install files'

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
	ln -fs ${PREFIX}/trop.sh ${TROP_LN_FILE} || exit 1
	" || err 'failed to install man page or to link trop.sh'
fi

echo "trop installed to \`${PREFIX}' successfully"
exit 0
