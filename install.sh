#!/bin/sh
set -e

# Be sure to be in the trop directory!

err ()
{
	if [ $force -eq 1 ]; then
		set +e
		echo -e "error (ignored):" "$@"
		return 0
	fi
	[ -n "$tmpfile" ] && rm ${tmpfile}
	echo -e "install.sh stopped - error:" "$@" ; exit 1
}

trap 'echo ; err "caught signal"' SIGINT
: ${PREFIX:=${HOME}/.trop}
force=0

if [ -n "$1" ]; then
	usage='usage: install.sh [-f] [up]|[update]'
	notupdate=0
	case $1 in
	up|update) break ;;
	-f) force=1
		if [ -z "$2" ]; then
			notupdate=1 ; break
		elif [ "$2" != 'up' ] && [ "$2" != 'update' ]; then
			echo $usage ; exit 1
		fi
		;;
	*) echo $usage ; exit 1 ;;
	esac
	[ $notupdate -eq 1 ] && break # -f was used for install
	[ ! -e ${PREFIX} ] && err "\`$PREFIX' doesn't exist"
	[ ! -d ${PREFIX} ] && err "PREFIX \`$PREFIX' is not a directory!"
	[ ! -e ${PREFIX}/.is_trop_dir ] && \
	err "\`$PREFIX' doesn't look like a trop directory\n"\
	    "\b(if it is, add \`.is_trop_dir' to the directory and restart update)"
	for file in trop.sh trop.awk trop_torrent_done.sh README LICENSE; do
		if ! `diff -q "$file" "${PREFIX}/${file}" >/dev/null`; then
			echo "${file} changed, replacing..."
			case "$file" in
			trop*)
				install -p -m 0550 "$file" "$PREFIX" ;;
			README|LICENSE)
				install -p -m 0640 "$file" "$PREFIX" ;;
			esac
		fi
	done
	# don't edit!
	CUR_TROPCONF_SHA256='04f877405429de2dbe7734cb82d3eec4ff4b521f0fb161477ed266cabf5c7cd9'
	CUR_TROPRIV_SHA256='04e95cfc0391674f0591a5e7f7a2ca995a5d16afffc811ac09747d511cd00549'
	hash sha256 2>/dev/null || err 'need sha256 to check trop.conf and tropriv.sh'
	tropconf_sha256=`sha256 -q trop.conf`
	tropriv_sha256=`sha256 -q tropriv.sh`
	[ "$tropconf_sha256" != "$CUR_TROPCONF_SHA256" ] && err 'trop.conf changed, cannot check for updates'
	[ "$tropriv_sha256" != "$CUR_TROPRIV_SHA256" ] && err 'tropriv.sh changed, cannot check for updates'
	[ ! -e ${PREFIX}/.cache ] && mkdir ${PREFIX}/.cache
	[ ! -e ${PREFIX}/.cache/conf_chksum ] && echo "$tropconf_sha256" > ${PREFIX}/.cache/conf_chksum
	[ ! -e ${PREFIX}/.cache/priv_chksum ] && echo "$tropriv_sha256" > ${PREFIX}/.cache/priv_chksum
	[ "$(cat ${PREFIX}/.cache/conf_chksum)" != "$tropconf_sha256" ] && echo 'trop.conf changed, please update this file manually' \
	&& echo "$tropconf_sha256" > ${PREFIX}/.cache/conf_chksum
	[ "$(cat ${PREFIX}/.cache/priv_chksum)" != "$tropriv_sha256" ] && echo 'tropriv.sh changed, please update this file manually' \
	&& echo "$tropriv_sha256" > ${PREFIX}/.cache/priv_chksum
	hash gzcat 2>/dev/null || err 'need gzcat to check manpage'
	hash mktemp 2>/dev/null || err 'need mktemp to check manpage'
	tmpfile=`mktemp`
	touch $tmpfile || err "couldn't create a temporary file"
	gzcat /usr/local/man/man1/trop.1 >${tmpfile}
	if ! `diff -q ${tmpfile} trop.1 >/dev/null`; then
		echo 'The man page has changed. Enter root credentials'
		su -m root -c \
		"
		install -g 0 -o 0 -m 0640 trop.1 /usr/local/man/man1/ && gzip /usr/local/man/man1/trop.1 \
		|| exit 1
		" || err "couldn't update manpage"
	fi
	exit 0
fi

[ -e "${PREFIX}" ] && { [ ! -d "${PREFIX}" ] && err "PREFIX \`${PREFIX}' is not a directory!" || \
err 'PREFIX path already exists. To be safe, manually remove this directory and restart install.sh' ;}
eval $(stat -qs ${PREFIX%/*})
[ -z "$st_uid" ] && err 'bad path for PREFIX'
[ $(id -u) -ne $st_uid ] && err "please login to \`$(id -un $st_uid)' to install trop"

: ${TROP_LN_FILE:=/usr/local/bin/trop}
TROPLNCMD="ln -fs ${PREFIX}/trop.sh ${TROP_LN_FILE}"

# install.sh will not create intermediate directories.
[ ! -e ${TROP_LN_FILE%/*} ] && err 'invalid path for TROP_LN_FILE'
if [ -L ${TROP_LN_FILE} ] || [ -e ${TROP_LN_FILE} ]; then
	printf 'TROP_LN_FILE file already exists. Remove? (y/n) y > '
	read choice
	while :; do
		case $choice in [Yy]|'') break                       ;;
		                [Nn]) TROPLNCMD='' ; break           ;;
		                *) printf '(y/n) y > ' ; read choice ;;
		esac
	done
fi

mkdir ${PREFIX}
touch ${PREFIX}/.is_trop_dir
install -p -m 0550 trop.sh trop.awk trop_torrent_done.sh ${PREFIX} && \
install -p -m 0640 README LICENSE trackers               ${PREFIX} && \
install -p -m 0770 tropriv.sh trop.conf                  ${PREFIX} || err 'failed to install files'

hash gzip 2>/dev/null || err 'need gzip to install manpage'
if [ $st_uid -eq 0 ]; then
	install -g 0 -o 0 -m 0640 trop.1 /usr/local/man/man1/ && gzip /usr/local/man/man1/trop.1 \
	|| err "couldn't install man page"
	eval ${TROPLNCMD} || err "couldn't link trop.sh"
else
	echo 'Enter root credentials'
	su -m root -c \
	"
	install -g 0 -o 0 -m 0640 trop.1 /usr/local/man/man1/ && gzip /usr/local/man/man1/trop.1 \
	|| exit 1
	eval ${TROPLNCMD} || exit 1
	" || err 'failed to install man page or link trop.sh'
fi

echo "trop installed to \`${PREFIX}' successfully"
exit 0
# vim: ft=sh:ts=4:sw=4
