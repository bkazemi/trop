#!/bin/sh

TROP_VERSION=\
'trop 1.2.1
last checked against: transmission-remote 2.84 (14307)'

usage ()
{
	cat <<EOF >&2
trop.sh - transmission-remote operations

usage: ${PROG_NAME} [-h host:port] [-a auth] [options]

options:
 -h   <host:port>          set host and port to connect to
      | <host> | <port>
 -a   <user:pw>            set authorization information

 -p                        pass flags directly to tr-remote

 -m   <base> [new-base]    replace the base in the location of any matching
                           torrents

 -dl                       show information about downloading torrents
 -ns                       list number of torrents actively seeding
 -si                       show information about seeding torrents
 -sul                      list seeding torrents and their upload rates

 -t    <torrent-id> <opt>  pass tr-remote option to torrent
 -ta   [tracker-alias]     add a tracker alias interactively
 -td   <torrent-id> <act>  have torrent perform action upon DL completion
 -terr                     show torrents that have errors
 -ts   <tracker-alias>     list seeding torrents by tracker
 -tt   <tracker-alias>     show total amount downloaded from tracker
 -tul  <tracker-alias>     list seeding torrents and their UL rates by tracker

 -startup                  setup defaults - intended to be used when logging in
 -q                        suppress all message output
 -V                        show version information
 -help                     show this output
EOF

	exit 0
}

hpc ()
{
	[ -n "$HOSTPORT" ] && printf -- "$HOSTPORT" || printf ""

	return 0
}

echo_wrap ()
{
	# in case echo is used to display anything to user
	[ $silent -eq 0 ] && echo "$@" >&2

	return 0
}

printf_wrap ()
{
	# in case printf is used to display anything to user
	[ $silent -eq 0 ] && printf "$@" >&2
}

trop_private ()
{
	## $1 - specify set{a,h} to set HOSTPORT or AUTH
	## $2 - the user-specified HOSTPORT/AUTH

	if [ -z "$1" ]; then
		local trout
		[ $PRIVATE -eq 1 ] || { . ${srcdir}/tropriv.sh ; PRIVATE=1 ;}
		trout=$(transmission-remote $(hpc) -n "$AUTH" -st 2>&1) || \
		{ [ -n "$trout" ] && echo_wrap "transmission-remote:" "${trout##*transmission-remote: }" ; die 3 ;}
		return 0
	fi

	[ $auser -eq 1 ] && [ $huser -eq 1 ] && return 0
	[ $PRIVATE -eq 1 ] || { . ${srcdir}/tropriv.sh ; PRIVATE=1 ;}

	if [ "$1" = 'seth' ] || [ "$1" = 'seta' ]; then
		. ${srcdir}/tropriv.sh "$@" ; return 0
	fi

	return 0
}

trop_seed_list ()
{
	transmission-remote $(hpc) -n "$AUTH" -l 2>/dev/null | awk '$9 == "Seeding"' || die 32

	return 0
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

	return 0
}

trop_seed_ulrate ()
{
	## $1 - alias

	trop_seed_info | pipe_check "trop_awk 'sul'" || die $?

	return 0
}

trop_seed_tracker_ul()
{
	## $1 - alias

	trop_seed_info | pipe_check "trop_awk 'tsul' $1" || die $?

	return 0
}

trop_seed_tracker ()
{
	## $1 - alias

	trop_seed_info | pipe_check "trop_awk 'tsi' $1" || die $?

	return 0
}

trop_make_file ()
{
	## $1 - type of file to create
	## $2 - `m' to create

	if [ "$1" = 'r' ]; then
		[ "$2" = 'm' ] && { printf "$(tmf_mkr)" && return 0 || return 1 ;}
		local prefix='regfile'
		tmf_mkr ()
		{
			touch "$(tmf_fname)" && \
			return 0 || return 1
		}
	elif [ "$1" = 'p' ]; then
		[ "$2" = 'm' ] && { printf "%s" "$(tmf_mkp)" && return 0 || return 1 ;}
		local prefix='np'
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
			printf `mktemp -qu ${prefix}_trop.XXXXX` && return 0
		done
	}

	printf "$(trop_make_file $1 m)" && return 0
}

trop_awk ()
{
	## $1 - AWK function to execute
	## $2 - options to pass to AWK function
	## $3 - sub-option

	local awkopt="awk -f ${srcdir}/trop.awk -v silent=${silent} -v progname=trop.awk func=${1}"
	case ${1} in
	ta)
		${awkopt} ${2} ${TROP_TRACKER} ${3} "${4}" || return 31
		;;
	tth)
		local thash=
		[ -n "$4" ] && thash="${srcdir}/.cache/${4}_thash"
		${awkopt} ${2} ${3} ${thash} || return 31
		;;
	t*)
		[ ! -f $TROP_TRACKER ] && return 4 # no tracker file
		[ -z $2 ] && return 41 # no alias
		awk -f ${srcdir}/trop.awk -v silent=${silent} -v progname="trop.awk" func=tm ${2} ${TROP_TRACKER} \
		|| return 42 # alias not found
		${awkopt} ${2} ${TROP_TRACKER} ${3} || return 31 # trop.awk failed
		;;
	*)
		${awkopt} || return 31
		;;
	esac

	return 0
}

trop_tracker_total ()
{
	## $1 - alias

	[ -z "$1" ] && die 41
	# check if alias is defined
	trop_awk 'tm' ${1} || die 42
	local t ta tt tta lst diff difftn diffu s
	t="$1" tt=1 diffu=0
	lst="$(trop_torrent l | awk '{ if ($1 !~ /Sum|ID/) print $1 }')" || die 24
	[ ! -e "${srcdir}/.cache" ] && \
		{ mkdir ${srcdir}/.cache || die 23 ;}
	[ ! -e "${srcdir}/.cache/"$1"_lstp" ] && \
		{ echo "$lst" > "${srcdir}/.cache/"${1}"_lstp" || die 23 ;} \
	|| diff="$(echo "$lst" | diff --unchanged-line-format='' --old-line-format='' ${srcdir}/.cache/"$1"_lstp -)"

	i=1 tac=0
	_ 'checking all torrent info...'
	if [ ! -e "${srcdir}/.cache/"$1"_tap" ]; then
		# first permanent cache
		_ 'caching all torrent info'
		ta="$(trop_torrent all i)"
		echo "$ta" > ${srcdir}/.cache/"$1"_tap && tac=1 && \
		echo "$ta" | trop_awk 'tth' 'add' > ${srcdir}/.cache/"$1"_thash || die 23
	fi

	if [ -n "$diff" ]; then
		tta=`cat ${srcdir}/.cache/"$1"_tap`
		difftn=$(echo "$diff" | wc -l)
		local i=1 h tid
		while [ $i -le $difftn ]; do
			tid=$(echo "$diff" | awk "NR==$i") \
			&& \
			h=$(trop_torrent ${tid} i | awk '{
				if ($1 ~ /Hash:/)
					print $2
			}') || die 23
			# if tth returns one, then torrent's idx was shifted
			trop_awk 'tth' 'check' $h ${1} || { : $((i += 1)) ; continue ;}
			# else it is a new torrent
			tta=`printf "%s\n%s" "$tta" "$(trop_torrent ${tid} i)"`
			: $((i += 1))
		done
		diffu=1
	fi

	_ "grabbing tracker details...\n"
	if [ $diffu -eq 1 ]; then
		s="$(echo "$tta" | trop_awk 'ttd' ${1})" || die $?
	else
		[ -e "${srcdir}/.cache/"$1"_ttotal" ] && { \
			printf "Total downloaded: %s\n" "$(cat "${srcdir}/.cache/"$1"_ttotal")" || die 42 ; exit 0 ;}
		s="$(cat ${srcdir}/.cache/"$1"_tap | trop_awk 'ttd' ${1})"
	fi
	local d="$(echo "$s" | awk \
	          '{ if ($1 ~ /Downloaded/) print $2 $3 }')"
	echo "$d" | trop_awk 'tt' $1 ${srcdir}/.cache/${1}_ttotal || die $?

	return 0
}

trop_torrent ()
{
	## $1 - torrent ID or single opt
	## $2 - option paired with torrent ID

	[ -z "$1" ] && usage
	local opt
	if [ -n "$1" ] && [ -z "$2" ]; then
		# if there are 3 or more chars then it is a long option
		[ ${#1} -gt 2 ] && opt="--${1}" || opt="-${1}"
		transmission-remote $(hpc) -n "$AUTH" ${opt} || die 1
		return 0
	fi

	[ ${#2} -gt 2 ] && opt="--${2}" || opt="-${2}"
	transmission-remote $(hpc) -n "$AUTH" -t $1 $opt || die 1

	return 0
}

trop_torrent_done ()
{
	## $1 - torrent ID
	## $2..$n - action to perform when torrent finishes

	# commands are formatted to be passed as arguments
	# to trop_torrent()

	[ ! -e ${srcdir}/.cache          ] && mkdir ${srcdir}/.cache
	[ ! -e ${srcdir}/.cache/tdscript ] && touch ${srcdir}/.cache/tdscript
	if [ -n "$1" ]; then
		[ -z "$2" ] && die 51
		cat ${srcdir}/.cache/tdscript | while read tid; do
			[ "${tid%% *}" = "$1" ] && die 28
		done
		case $2 in
		rm)
			[ "$3" = 'hard' ] && rmcmd='remove-and-delete' || rmcmd='r'
			echo "$1" ${rmcmd} >> ${srcdir}/.cache/tdscript
			;;
		stop)
			echo "$1" 'S' >> ${srcdir}/.cache/tdscript
			;;
		*)
			die 29
			;;
		esac
		return 0
	fi
	local nr=0 tid
	cat ${srcdir}/.cache/tdscript | while read id_and_cmd; do
		: $((nr += 1))
		tid=$(echo $id_and_cmd | cut -f1 -d' ')
		[ "$(trop_torrent $tid i | awk '$1 ~ /^Percent/ { print $3 }')" = "100%" ] && \
		eval trop_torrent $id_and_cmd || ldie 27 $tid
		_l "successfully processed command on torrent ${tid}, removing ..."
		sed -e "${nr}d" -I '' ${srcdir}/.cache/tdscript
	done

	return 0
}

trop_tracker_add()
{
	## $1 - alias to add

	[ -n "$1" ] && a=$1 || \
	{ printf 'enter alias to use > ' ; read a ;}
	printf 'enter primary tracker > '         ; read pt
	printf 'add secondary tracker(s)? y/n > ' ; read ast
	[ ${#ast} -gt 1 ] && ast=$(echo $ast | tr '[:upper:]' '[:lower:]')
	while :; do
		case $ast in
		[Yy]|yes)
			printf 'how many trackers would you like to add? > ' ; read numt
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
			break
			;;
		[Nn]|no) break ;;
		*)
			printf 'please answer yes or no > ' ; read ast
			[ ${#ast} -gt 1 ] && ast=$(echo $ast | tr '[:upper:]' '[:lower:]')
			;;
		esac
	done
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

	return 0
}

trop_tracker_mv_location()
{
	## $1 - dir prefix to replace
	## $2 - replacement prefix

	local tid newloc numt=0
	trop_torrent all i | awk -v prefix="${1}" -v newprefix="${2}" \
	'
		BEGIN {
			if (newprefix && newprefix !~ /\/$/)
				newprefix = newprefix"/"
		}
		$1 == "Id:" { id = $2 }
		$1 == "Location:" {
			if ($2 ~ "^"prefix"/?") {
				loc = $2
				# append rest of path in case it
				# contains spaces
				for (i = 3; i <= NF; i++)
					loc=loc" "$i # space is FS
				sub("^"prefix"/?", newprefix, loc)
				printf "%d %s\n", id, loc
			}
		}
	' | while read tmp; do
	      tid=${tmp%% *} newloc=$(echo $tmp | sed -E 's/^[^ ]+ //')
	      eval ${tmptrop} -p -t ${tid} --move ${newloc} >/dev/null \
	      && : $((numt += 1)) \
	      && printf_wrap "successfully moved ${numt} torrents\r"
	    done \
	|| die 200 ${tid}
	echo # newline

	return 0
}

pipe_check ()
{
	## $1 - shell commands

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

trop_errors ()
{
	## $1 - error code

	case ${1} in
	1)
		_ "transmission-remote error"
		;;
## FUNC GENERAL ERRORS ##
	2)
		_ 'trop_seed_list() failed'
		;;
	21)
		_ 'trop_make_file(): file not recognized'
		;;
	22)
		_ 'pipe_check(): nothing on stdin,'\
		  'probably nothing currently seeding'
		;;
	23)
		_ 'trop_tracker_total(): caching error'
		;;
	24)
		_ "trop_tracker_total(): failed getting torrent IDs"
		;;
	25)
		_ 'no tracker errors detected.'
		;;
	26)
		_ "WARNING: trop detected a tracker error. Use the \`-terr' switch to show more info."
		;;
	27)
		_ 'trop_tracker_done(): failed to perform requested action on torrent' "$2"
		;;
	28)
		_ 'trop_tracker_done(): torrent already scheduled for action'
		;;
	29)
		_ "trop_tracker_done(): unknown action -- actions include:\n" \
		  " rm [hard] - Remove torrent when done. Adding \`hard' will remove files as well.\n"\
		  " stop - Stop the torrent when done. This will halt seeding of the torrent."
		;;
	200)
		_ 'trop_tracker_mv_location(): failed to move torrent `' "$2" "'"
		;;
## FUNC ERR END $$
	3)
		_ "couldn't connect to transmisson session"
		;;
	31)
		_ 'trop.awk failed'
		;;
	32)
		_ 'awk failed'
		;;
## TRACKER ERROR ##
	4)
		_ 'tracker file not found!'
		;;
	41)
		_ 'no alias specified'
		;;
	42)
		_ 'alias not found'
		;;
## TRACKER ERR END $$
	5)
		_ "can't find transmission-remote in PATH!"
		;;
	51)
		_ 'insufficient arguments' "$2"
		;;
	52)
		_ 'bad format' "$2"

		;;
	53)
		_ 'no futher options should be supplied after' "$2"
		;;
	54)
		_ 'tr-remote set to run --torrent-done-script,' \
		  'but your configuration has the option disabled. Bailing.'
		;;
	*)
		_ 'error'
		;;
	esac

	return 0
}

die ()
{
	## $1 - error code

	[ -n "$1" ] && [ $silent -eq 0 ] && trop_errors $1 "$2"
	kill -6 $toppid
}

ldie ()
{
	## $1 - error code

	[ -n "$1" ] && [ $silent -eq 0 ] && \
	trop_errors $1 "$2" 2>>${TROP_LOG_PATH}
	kill -6 $toppid
}

check_tracker_errors ()
{
	## $1 - silence warning

	trop_private
	trop_torrent l | awk '
		BEGIN { ret = 0 }
		$1 ~ /\*/ {
			if (!ret)
				ret=1
		}
		END { exit ret }
	' && return 1 || { [ -z "$1" ] && _e 26 ;}

	return 0
}

show_tracker_errors ()
{
	check_tracker_errors 1 || die 25
	trop_torrent l | awk '
		$1 ~ /\*/ {
			print $1
		}
	' | tr -d \* | while read id; do
		trop_torrent ${id} i
	done | trop_awk 'ste'

	return 0
}

_ ()
{
	## $@ - strings to echo

	[ $silent -eq 0 ] && \
	echo -e ${PROG_NAME}":" "$@" >&2

	return 0
}

_e ()
{
	## $1 - error code

	trop_errors $1 "$2"

	return 0
}

_l ()
{
	## $@ - strings to log

	[ "$TROP_LOG" = 'yes' ] && \
	_ "$@" 2>>${TROP_LOG_PATH}

	return 0
}

# --------------- main --------------- #
unset _
PROG_NAME=${0##*/}
[ $# -eq 0 ] && usage
LC_ALL=POSIX
toppid=$$
silent=0
trap 'exit 1' 6
hash transmission-remote 2>/dev/null || die 5

# check if file used to call the script is a link or the script file itself
# hard links will fail, so stick to sym links
file -hb $0 | grep -q '^POSIX shell' && \
	{	                                            \
		{ eval "echo ${0} | grep -qEx '^\./{1}'" && \
		  srcdir="." ;}                             \
		||                                          \
		{ eval "echo ${0} | grep -qEx '[^/]+'" &&   \
		  srcdir="." ;}                             \
		||                                          \
		srcdir=${0%/*}                              \
	;}	                                            \
|| \
srcdir="$(echo $(file -hb $0) | sed -E -e "s/^symbolic link to //i;s/\/+[^\/]+$//")"

TROP_TRACKER=${srcdir}/trackers
auser=0 huser=0 PRIVATE=0 cte=1
. ${srcdir}/trop.conf # various user options
[ "$TROP_LOG" = 'yes' ] && : ${TROP_LOG_PATH:=${srcdir}/trop.log}
[ "$TROP_LOG" = 'no'  ] && TROP_LOG_PATH=/dev/null

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
	-terr|-ta|-td|tdauto|-startup)
		cte=0 ;;
	esac
done

while :; do
	case $1 in
	-h)
		test -z "$2" && die 51 "for \`-h'"
		# regex checks for bad format in host, eg: awd:123g4 -- bad port
		echo $2 | grep -qE '^-|([[:alnum:]]*:.*[^0-9].*)|(:$)' && die 52 "for \`-h'"
		trop_private "seth" "$2" ; huser=1
		shift 2
		;;
	-a)
		test -z "$2" && die 51 "for \`-a'"
		echo $2 | grep -qE '^-' && die 52 "for \`-a'"
		trop_private "seta" "$2" ; auser=1
		shift 2
		;;
	*) break ;;
	esac
done

[ "$CHECK_TRACKER_ERRORS" = 'yes' ] && [ $silent -eq 0 ] \
&& [ $cte -eq 1 ] && check_tracker_errors

while [ $1 ]; do
	case $1 in
	-terr)
		show_tracker_errors ; exit 0
		;;
	-dl)
		trop_private
		trop_torrent all i | trop_awk 'dli' || die 31
		shift
		;;
	-m)
		[ -z "$2" ] && die 51 "for \`-m'"
		two=${2}
		echo $2 | grep -qE '/$' && two=${2%*/}
		trop_private
		tmptrop="${srcdir}/trop.sh $(hpc) -a '$AUTH'"
		trop_tracker_mv_location "$two" "$3"
		unset two
		test -n "$3" && shift 3 || shift 2
		;;
	-ns)
		trop_private
		trop_num_seed
		shift
		;;
	-si)
		trop_private
		trop_seed_info
		shift
		;;
	-sul)
		trop_private
		trop_seed_ulrate
		shift
		;;
	-s)
		_ "options include \`-si' or \`-sul'" ; exit 0
		;;
	-ta)
		trop_tracker_add $2
		exit 0
		;;
	-td|tdauto)
		[ "$1" = 'tdauto' ] && \
		{ [ "$ADD_TORRENT_DONE" = 'yes' ] || ldie 54 ;} \
		&& trop_private 2>>${TROP_LOG_PATH}
		trop_torrent_done "$2" "$3" "$4"
		exit 0
		;;
	-ts)
		trop_private
		trop_seed_tracker $2
		shift 2
		;;
	-tul)
		trop_private
		trop_seed_tracker_ul $2
		shift 2
		;;
	-tt)
		trop_private
		trop_tracker_total $2
		shift 2
		;;
	-t|-t[0-9]*)
		trop_private
		if [ ${#1} -gt 2 ]; then
			[ ! "$2" ] && die 51 "for \`-t'"
			one=${1#-t}
			echo ${one} | grep -qE '[^0-9,-]' && die 52 "for \`-t'"
			shift ; savenextopts="$@"
			eval set -- ${one} "$savenextopts"
			unset one savenextopts
		else
			shift
		fi
		trop_torrent $1 $2
		# over-shifting produces garbage
		test -n "$2" && shift 2 || shift
		;;
	-p)
		test -z "$2" && die 51 "for \`-p'"
		trop_private
		shift
		trout=$(transmission-remote $(hpc) -n "$AUTH" "$@" 2>&1) || \
		{ [ -n "$trout" ] && echo_wrap "transmission-remote:" "${trout##*transmission-remote: }" ; die 1 ;}
		[ -n "$trout" ] && echo "$trout"
		echo "$@" | grep -qE '^(-a)|(-add)' && [ "$ADD_TORRENT_DONE" = 'yes' ] && \
		tid=$(trop_torrent l | awk '$1 !~ /(ID)|(Sum)/{print $1}' | sort -rn | sed 1q)
		[ -n "$tid" ] && trop_torrent_done ${tid} ${ADD_TORRENT_DONE_ACT:-rm}
		exit 0
		;;
	-startup)
		_l 'attempting startup...'
		trop_private 2>>${TROP_LOG_PATH}
		[ "$ADD_TORRENT_DONE" = 'yes' ] && \
		{ transmission-remote $(hpc) -n "$AUTH" --torrent-done-script ${srcdir}/trop_torrent_done.sh 2>>${TROP_LOG_PATH} && \
		_l 'set tr-remote --torrent-done-script successfully -' "$(date)" \
		|| _l 'failed to set tr-remote --torrent-done-script' ;}
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
