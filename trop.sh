#!/bin/sh
#
# TODO: implement mass location change

TROP_VERSION=\
'trop 1.0.0
last checked against: transmission-remote 2.84 (14307)'

usage ()
{
	cat <<EOF >&2
trop.sh - transmission-remote operations

usage: ${PROG_NAME} [-h host:port] [-a auth] [options]

options:
 -h                       set host and port to connect to
 -a                       set authorization information
 -p                       pass flags directly to tr-remote
 -dl                      show information about downloading torrents
 -ns                      list number of torrents actively seeding
 -si                      show information about seeding torrents
 -sul                     list seeding torrents and their upload rates
 -ta  [tracker-alias]     add a tracker alias interactively
 -tul <tracker-alias>     list seeding torrents and their UL rates by tracker
 -tt  <tracker-alias>     show total amount downloaded from tracker
 -ts  <tracker-alias>     list seeding torrents by tracker
 -t   <torrent-id> <opts> pass tr-remote option to torrent
 -q                       suppress all message output
 -V                       show version information
 -help                    show this output
EOF

	exit 0
}

uhc ()
{
	[ -n "$USERHOST" ] && printf "$USERHOST" || printf ""
}

echo_wrap ()
{
	# in case echo is used to display anything to user
	[ $silent -eq 0 ] && echo "$@"
}

trop_private ()
{
	if [ -z "$1" ]; then
		[ $PRIVATE -eq 1 ] || { . ${scrdir}/tropriv.sh ; PRIVATE=1 ;}
		transmission-remote $(uhc) -n "$AUTH" -st >&- 2<&- || die 3
		return 0
	fi

	[ $auser -eq 1 ] && [ $huser -eq 1 ] && return 0
	[ $PRIVATE -eq 1 ] || { . ${scrdir}/tropriv.sh ; PRIVATE=1 ;}

	[ "$1" = 'seth' ] && \
		. ${scrdir}/tropriv.sh "$@" ; return 0
	[ "$1" = 'seta' ] && \
		. ${scrdir}/tropriv.sh "$@" ; return 0

	return 0
}

trop_seed_list ()
{
	transmission-remote $(uhc) -n "$AUTH" -l 2>/dev/null | awk '$9 == "Seeding"' || die 32
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
		[ "$2" = 'm' ] && { printf "$(tmf_mkr)" && return 0 || return 1 ;}
		tmf_prefix="regfile"
		tmf_mkr ()
		{
			touch "$(tmf_fname)" && \
			return 0 || return 1
		}
	elif [ "$1" = 'p' ]; then
		[ "$2" = 'm' ] && { printf "%s" "$(tmf_mkp)" && return 0 || return 1 ;}
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
	local awkopt="awk -f ${scrdir}/trop.awk -v silent=${silent} -v progname=trop.awk func=${1}"
	case ${1} in
		ta)
			${awkopt} ${2} ${TROP_TRACKER} ${3} "${4}" || return 31
			;;
		tth)
			${awkopt} ${2} || return 31
			;;
		t*)
			[ ! -f $TROP_TRACKER ] && return 4 # no tracker file
			[ -z $2 ] && return 41 # no alias
			awk -f ${scrdir}/trop.awk -v silent=${silent} -v progname="trop.awk" func=tm ${2} ${TROP_TRACKER} \
			|| return 42 # alias not found
			${awkopt} ${2} ${TROP_TRACKER} ${3:-} || return 31 # trop.awk failed
			;;
		*)
			${awkopt} || return 31
			;;
	esac

	return 0
}

trop_tracker_total ()
{
	[ -z "$1" ] && die 41
	# check if alias is defined
	trop_awk 'tm' ${1} || die 42
	local t ta tt tta lst diff difftn diffu s
	t="$1" tt=1 diffu=0
	lst="$(trop_torrent l | awk '{ if ($1 !~ /Sum|ID/) print $1 }')" || die 24
	[ ! -e "${scrdir}/.cache" ] && \
		{ mkdir ${scrdir}/.cache || die 23 ;}
	[ ! -e "${scrdir}/.cache/"$1"_lstp" ] && \
		{ echo "$lst" > "${scrdir}/.cache/"${1}"_lstp" || die 23 ;} \
	|| diff="$(echo "$lst" | diff --unchanged-line-format='' - ${scrdir}/.cache/"$1"_lstp)"

	i=1 tac=0
	_ 'checking all torrent info...'
	if [ ! -e "${scrdir}/.cache/"$1"_tap" ]; then
		# first permanent cache
		_ 'caching all torrent info'
		ta="$(trop_torrent all i)"
		echo "$ta" > ${scrdir}/.cache/"$1"_tap && tac=1 || die 23
		echo "$ta" | trop_awk 'tth' 'add' > ${scrdir}/.cache/"$1"_thash || die 23
	fi

	if [ -n "$diff" ]; then
		tta=`cat ${scrdir}/.cache/"$1"_tap`
		difftn=$(echo "$diff" | wc -l)
		local i=1 h
		while [ $i -le $difftn ]; do
			h=$(trop_torrent ${i} i | awk '{
				if ($1 ~ /Hash:/)
					print $2
			}')
			# if tth returns one, then torrent's idx was shifted
			trop_awk 'tth' 'check' $h || continue
			# else it is a new torrent
			tta=`printf "%s\n%s" "$tta" "$(trop_torrent $(echo "$diff" | awk NR==${i}) i)"`
			: $((i += 1))
		done
		diffu=1
	fi

	_ "grabbing tracker details...\n"
	if [ $diffu -eq 1 ]; then
		s="$(echo "$tta" | trop_awk 'ttd' ${1})" || die $?
	else
		[ -e "${scrdir}/.cache/"$1"_ttotal" ] && { \
			printf "Total downloaded: %s\n" "$(cat "${scrdir}/.cache/"$1"_ttotal")" || die 42 ; exit 0 ;}
		s="$(cat ${scrdir}/.cache/"$1"_tap | trop_awk 'ttd' ${1})"
	fi
	local d="$(echo "$s" | awk \
	          '{ if ($1 ~ /Downloaded/) print $2 $3 }')"
	echo "$d" | trop_awk 'tt' $1 ${scrdir}/.cache/${1}_ttotal || die $?

	return 0
}

trop_torrent ()
{
	[ -z "$1" ] && usage

	if [ -n "$1" ] && [ -z "$2" ]; then
		transmission-remote $(uhc) -n "$AUTH" -$1 || die 1
		return 0
	fi
	
	transmission-remote $(uhc) -n "$AUTH" -t $1 -$2 || die 1
}

trop_tracker_add()
{
	[ -n "$1" ] && a=$1 || \
	{ printf 'enter alias to use > ' ; read a ;}
	printf 'enter primary tracker > '
	read pt
	printf 'add secondary tracker(s)? y/n > '
	read ast
	ast=$(echo $ast | tr '[:upper:]' '[:lower:]')
	while [ "$ast" != 'y' ] && [ "$ast" != 'n' ] \
          && [ "$ast" != 'yes' ] && [ "$ast" != 'no' ]; do
		printf 'please answer yes or no > '
		read ast
		ast=$(echo $ast | tr '[:upper:]' '[:lower:]')
	done
	if [ "$ast" = 'yes' ] || [ "$ast" = 'y' ]; then
		printf 'how many trackers would you like to add? > '
		read numt
		local numtlen=${#numt}
		numt=$(echo $numt | tr -Cd '[:digit:]')
		# if numt != numtlen, then numt
		# was stripped and thus invalid
		while [ ! $numt ] || [ $numt -le 0 ] || [ ${#numt} -ne $numtlen ]; do
			printf "enter a valid number > "
			read numt
			numtlen=${#numt}
			numt=$(echo $numt | tr -Cd '[:digit:]')
		done
	fi
	[ ! $numt ] && numt=0 st='NULL'
	local i=1
	while [ $i -le $numt ]; do
		printf "enter tracker #%d > " "$i"
		read tmp
		[ "$st" ] && st="$st ""$tmp" ||\
		st="$tmp"
		: $((i += 1))
	done
	trop_awk 'ta' $a $pt "$st" || die $?
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
	[ -n "$1" ] && [ $silent -eq 0 ] && \
		case ${1} in
			1)
			_ "transmission-remote error"
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
			23)
			_ 'trop_tracker_total(): caching error'
			;;
			24)
			_ "trop_tracker_total(): failed getting torrent IDs"
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
			32)
			_ 'awk failed'
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
			42)
			_ 'alias not found'
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
	kill -6 $toppid
}

_ ()
{
	[ $silent -eq 0 ] && \
	echo -e ${PROG_NAME}":" "$@"
}

# ---------- main -------------
unset _
PROG_NAME=${0##*/}
[ $# -eq 0 ] && usage
hash transmission-remote 2>/dev/null || \
{ _ "can't find transmission-remote in PATH!" ; exit 1 ;}
LC_ALL=POSIX
toppid=$$
silent=0
trap 'set -e ; exit 1' 6

# check if file used to call the script is a link or the script file itself
# hard links will fail, so stick to sym links
file -hb $0 | grep -q '^POSIX shell' && \
	{ \
		{ eval "echo ${0} | grep -qEx '^\./{1}'" && \
	  	  scrdir="." ;} \
		  || \
		{ eval "echo ${0} | grep -qEx '[^/]+'" && \
	  	  scrdir="." ;} \
		  || \
		scrdir=${0%/*} \
	;} \
|| \
scrdir="$(echo $(file -hb $0) | sed -E -e "s/^symbolic link to //i;s/\/+[^\/]+$//")"

TROP_TRACKER=${scrdir}/trackers
auser=0 huser=0 PRIVATE=0

for i; do
	case $i in
		-p) 
			break ;;
		-help)
			usage ;;
		-q)
			silent=1 ;;
		-V)
			echo "$TROP_VERSION" ; exit 0 ;;
	esac
done

while [ $1 ]; do
case $1 in
	-a)
		shift
		trop_private "seta" "$1" ; auser=1
		shift
		;;
	-h)
		shift
		trop_private "seth" "$1" ; huser=1
		shift
		;;
	-dl)
		trop_private	
		trop_torrent all i | trop_awk 'dli' || die 31
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
	-ta)
		shift
		trop_tracker_add $1
		exit 0
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
	-t|-t[0-9]*)
		trop_private
		if [ ${#1} -gt 2 ]; then 
			one=${1}
			tmp=${1##*[!0-9]}
			tmp2=`echo $1 | cut -b3-`
			shift ; savenextopts="$@"
			[ ${#tmp} -lt ${#tmp2} ] && \
			{ _ 'bad option `'${one}"'" ; usage ;} || \
			set -- $tmp "$savenextopts"
			unset one tmp tmp2 savenextopts
		else
			shift
		fi
		trop_torrent $1 $2
		# over-shifting produces garbage
		test -n "$2" && shift 2 || shift
		;;
	-p)
		trop_private
		shift
		transmission-remote $(uhc) -n "$AUTH" "$@" || die 1
		exit 0
		;;
	-q) 
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
