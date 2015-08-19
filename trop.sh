#!/bin/sh
#
# TODO: implement mass location change
#       condense to AWK

TROP_VERSION=\
'trop 0.2.2
last checked against: transmission-remote 2.84 (14307)'

usage ()
{
	cat <<EOF >&2
trop.sh - transmission-remote text operations

usage: ${PROG_NAME} [-b host:port] [-a auth] [options]

options:
 -b                       set host and port to connect to
 -a                       set authorization information
 -p                       pass flags directly to tr-remote
 -ns                      list number of torrents actively seeding
 -si                      list information about active torrents
 -sul                     list active torrents and their upload rates
 -tul <tracker-alias>     list active torrents and their upload rates by tracker
 -ts  <tracker-alias>     list active torrents by tracker
 -t   <torrent-id> <opts> pass tr-remote option to torrent
 -V                       show version information
 -h                       show this output
EOF

	exit 0
}

uhc ()
{
	if [ -n "$USERHOST" ]; then printf "%s" "$USERHOST"; else printf ""; fi
}

trop_private ()
{
	if [ -z "$1" ]; then
		. ${scrdir}/tropriv.sh
		transmission-remote $(uhc) -n "$AUTH" -st >&- 2<&- || die 3
		return 0
	fi
	if [ "$auser" = 1 ] && [ "$huser" = 1 ]; then
		return 0
	fi 
	. ${scrdir}/tropriv.sh

	if [ "$1" = 'seth' ]; then
		. ${scrdir}/tropriv.sh "$@" ; return 0
	fi
	if [ "$1" = 'seta' ]; then
		. ${scrdir}/tropriv.sh "$@" ; return 0
	fi

	return 0
}

trop_seed_list ()
{
	transmission-remote $(uhc) -n "$AUTH" -l 2>/dev/null | awk '$9 == "Seeding"' || die 1
}

trop_num_seed ()
{
	trop_seed_list | pipe_check "wc -l | tr -d '[:blank:]'" || die $?
	return 0
}

trop_seed_info ()
{
	trop_seed_list | awk '{if ($1 !~ /ID|Sum/) print $1}' \
	| pipe_check \
	'while read l; do
		trop_torrent ${l} i
		echo ----
	done' || die $?
}

trop_seed_ulrate ()
{
	trop_seed_info | pipe_check "trop_awk 'sul'" || die $?
	return 0
}

trop_seed_tracker_ul()
{
	trop_seed_info | pipe_check "trop_awk 'tsul' $1" || die $?
	return 0
}

trop_seed_tracker ()
{
	trop_seed_info | pipe_check "trop_awk 'tsi' $1" || die $?
	return 0
}

trop_make_file ()
{
	if [ "$1" = 'r' ]; then
		if [ "$2" = 'm' ]; then printf "$(tmf_mkr)" && return 0 || return 1; fi
		tmf_prefix="regfile"
		tmf_mkr ()
		{
			touch "$(tmf_fname)" && \
			return 0 || return 1
		}
	elif [ "$1" = 'p' ]; then
		if [ "$2" = 'm' ]; then printf "%s" "$(tmf_mkp)" && return 0 || return 1; fi
		tmf_prefix="np"
		tmf_mkp ()
		{
			mkfifo "$(tmf_fname)" && \
			return 0 || return 1
		}
	else
		 die 21 # unknown filetype
	fi
	tmf_fname ()
	{
		while :; do
			printf `mktemp -qu ${tmf_prefix}_trop.XXXXX` && return 0
		done
	}

	printf "$(trop_make_file $1 m)" && return 0
}

trop_awk ()
{
	$(echo "$1" | grep -qE '^t') && {
		if [ ! -f $TROP_TRACKER ]; then
			return 4 # no tracker file
		fi
		if [ "$1" = 'tsi' ] || [ "$1" = 'tsul' ] && [ -z $2 ]; then
			return 41 # no alias
		fi
		if [ "$1" = 'tt' ]; then
			awk -f ${scrdir}/trop.awk func=${1} ${2} ${TROP_TRACKER} ${3}\
			|| return 31
			return 0
		fi
		awk -f ${scrdir}/trop.awk func=${1} ${2} ${TROP_TRACKER}\
		|| return 31 # awk failed
		return 0 \
	;}
	awk -f ${scrdir}/trop.awk func=${1} || return 31 # awk failed
	return 0
}

trop_tracker_total ()
{
	if [ -z "$1" ]; then
		die 41
	fi
	local t ta tt lst diff diffa diffl difftn diffu ltmp s
	t="$1" tt=1
	lst="$(trop_torrent l | awk '{ if ($1 !~ /Sum|ID/) print $1 }')" || die
	if [ ! -e "${scrdir}/.cache" ]; then
		mkdir ${scrdir}/.cache
	fi
	if [ ! -e "${scrdir}/.cache/"$1"_lstp" ]; then
		echo "$lst" > "${scrdir}/.cache/"${1}"_lstp" || die
	else
		diff="$(echo "$lst" | diff --unchanged-line-format='' - $scrdir/.cache/"$1"_lstp)"
	fi

	i=1 tac=0
	echo checking all torrent info...
	if [ ! -e "$scrdir/.cache/"$1"_tap" ]; then
		# first permanent cache
		echo 'caching all torrent info'
		ta="$(trop_torrent all i)"
		echo "$ta" > $scrdir/.cache/"$1"_tap && tac=1 || die
	fi

	if [ -n "$diff" ]; then
		tta=`cat ${scrdir}/.cache/"$1"_tap`
		difftn=$(echo "$diff" | wc -l)
		local i=0
		while [ $i -lt $difftn ]; do
			tta=`printf "%s\n%s" "$ta" "$(trop_torrent $(echo "$diff" | awk NR==$i) i)"`
			: $((i += 1))
		done
		diffu=1
	fi

	echo -e "grabbing tracker details...\n"
	if [ "$diffu" = 1 ]; then
		s="$(echo "$ta" | grep "$t" -A 14 | grep Downloaded -A 2 | cut -b 2-)"
	else
		if [ -e "$scrdir/.cache/"$1"_ttotal" ]; then
			printf "total downloaded: " ; cat "$scrdir/.cache/"$1"_ttotal" || die
			exit 0
		fi
		s="$(echo "$(cat $scrdir/.cache/"$1"_tap)" | grep "$t" -A 14 | grep Downloaded -A 2 | cut -b 2-)"
	fi
	local d="$(echo "$s" | awk\
	          '{ if ($1 ~ /Downloaded/) print $2 $3 }')"

	echo "$d" | trop_awk 'tt' $1 ${scrdir}/.cache/${1}_ttotal || die $?
	return 0
}

trop_torrent ()
{
	if [ -n "$1" ] && [ -z "$2" ]; then
		transmission-remote $(uhc) -n "$AUTH" -$1 || die 1
		return 0
	fi
	if [ -z "$1" ]; then
		usage
	fi
	transmission-remote $(uhc) -n "$AUTH" -t $1 -$2 || die 1
}

args_look_ahead ()
{
	return 0
}

pipe_check ()
{
	{ \
	local inp="$(cat /dev/stdin)"
	if [ -n "$inp" ]; then
		# pass along...
		echo "$inp" | eval "$1" || return $?
		return 0
	fi
	return 22 \
	;}
}

die ()
{
	if [ -n "$1" ]; then
		case ${1} in
			1)
			_ "\ntransmission-remote error\n"\
			  "-OR-\n"\
			  'command line pipe error'
			break
			;;
## FUNC GENERAL ERRORS ##
			2)
			_ 'trop_seed_list() failed'
			break
			;;
			21)
			_ 'trop_make_file(): file not recognized'
			break
			;;
			22)
			_ 'pipe_check(): nothing on stdin,'\
			  'probably nothing currently seeding'
			break
			;;
## FUNC ERR END $$
			3)
			_ 'bad host/auth'
			;;
			31)
			_ 'trop.awk failed'
			break
			;;
## TRACKER ERROR ##
			4)
			_ 'tracker file not found!'
			break
			;;
			41)
			_ 'no alias specified'
			break
			;;
## TRACKER ERR END $$
			5)
			_ 'multiple options not currently allowed'
			break
			;;
			*)
			_ 'error'
			;;
		esac
	fi
	kill -6 $toppid
}

_ ()
{
	# XXX figure out what to do about
	# double err output
	echo -e ${PROG_NAME}":" "$@"
}

# ---------- main -------------
unset _
PROG_NAME=${0##*/}
: ${@:?"$(printf "%s" "$(usage)")"}
hash transmission-remote 2>/dev/null || \
{ _ "can't find transmission-remote in PATH!" ; exit 1 ;}
LC_ALL=C
toppid=$$
trap 'set -e ; exit 1' 6

# check if file used to call the script is a link or the script file itself
# hard links will fail, so stick to sym links
eval "echo ${0} | grep -qEx '.*\.sh$'" && \
	{ \
		{ eval "echo ${0} | grep -qEx '^\./{1}'" && \
	  	  scrdir="." ;} \
		  || \
		{ eval "echo ${0} | grep -qEx '[^/]+'" && \
	  	  scrdir="." ;} \
		  || \
		scrdir="$(echo ${0} | sed -E 's/\/+[^\/]+$//')" \
	;} \
|| \
scrdir="$(echo "$(file -hb $0)" | sed -E -e "s/^symbolic link to //i;s/\/+[^\/]+$//")"

TROP_TRACKER=${scrdir}/trackers
auser=0 huser=0

skip=0
for i; do
	if [ $skip -eq 1 ]; then skip=0 ; continue; fi
	case $i in
		-p) 
			skip=1 ; continue ;;
		-h)
			usage ;;
		-V)
			echo "$TROP_VERSION" ; exit 0 ;;
	esac
done
unset skip

while [ $1 ]; do
case $1 in
	-a)
		shift
		trop_private "seta" "$1" ; auser=1
		shift
		;;
	-b)
		shift
		trop_private "seth" "$1" ; huser=1
		shift
		;;
	-ns)
		shift
		trop_private
		trop_num_seed
		;;
	-si)
		shift
		trop_private
		trop_seed_info
		;;
	-sul)
		shift
		trop_private
		trop_seed_ulrate
		;;
	-s)
		_ "options include \`-si' or \`-sul'" && exit 0
		;;
	-ts)
		trop_private
		shift
		trop_seed_tracker $1
		shift
		;;
	-tul)
		trop_private
		shift
		trop_seed_tracker_ul $1
		shift
		;;
	-tt)
		trop_private
		shift
		trop_tracker_total $1
		shift
		;;
	-t)
		trop_private
		shift
		if [ -n "$4" ]; then 
			die 5
		fi
		if [ "$1" = 'dl' ]; then
			trop_torrent l | awk '$9 == "Downloading" || $9 == "Up & Down"'
			shift
		else
			trop_torrent $1 $2
			# over-shifting produces garbage
			test $2 && shift 2 || shift
		fi
		;;
	-p)
		trop_private
		shift
		transmission-remote $(uhc) -n "$AUTH" ${1} || die 1
		shift
		;;
	-*)
		_ 'bad option `'${1}"'" && usage
		;;
	*)
		_ 'unrecognized input' && usage
		;;
esac
done

exit 0
