#!/bin/sh
#
# TODO: implement mass location change
#       real tracker checking
#       condense to AWK

TROP_VERSION=\
'trop 0.2.1
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

trop_common ()
{
	export trsi="$(trop_seed_info)" || die 'trop_common() failed'
	return 0
}

trop_private ()
{
	if [ "$auser" = 1 ] && [ "$huser" = 1 ]; then return 0; fi

	. $scrdir/tropriv.sh

	if [ "$1" = 'seth' ]; then
		. $scrdir/tropriv.sh "$@" && return 0 || die 'bad user/host'
	fi
	if [ "$1" = 'seta' ]; then
		. $scrdir/tropriv.sh "$@" && return 0 || die 'bad auth'
	fi

	return 0
}

trop_num_seed ()
{
	trop_seed_list | wc -l || die 'tns() error'
	exit 0
}

trop_seed_info ()
{
	local trsl trsltmp i itmp

	trsl="$(trop_seed_list)"
	trsltmp="$(echo "$trsl" | cut -b2-4 | tr -d '[:blank:]')"

	i=1 itmp=1

	checki () { if [ "$itmp" = `expr $i - 1` ]; then return 0; else return 1; fi }
	# XXX: needs work
	if [ "$trsltmp" = '' ]; then { _ 'trsl error' ; exit 1 ;} fi ; while [ $i -le $(echo "$trsltmp" | wc -l) ]; do
	    trop_torrent $(echo "$trsltmp" | awk NR==$i) i && echo ----- && itmp=$i && : $((i += 1)) && checki || i=1000 ; done \
	    ; if [ $i = 1000 ] && [ ! $? ]; then die 'trt error'; fi ; exit 0

	# trt error handling -
	# if itmp is i-1 then trt was successful, so ret true
	# else it wasn't return false
}

trop_seed_list ()
{
	transmission-remote $(uhc) -n "$AUTH" -l | awk '$9 == "Seeding"' || die 'tsl() failed'
}

trop_seed_ulrate ()
{
	trop_common
	local i a b ll nl tmp tmpn tmpo

	if [ -n "$1" ]; then
		trop_seed_tracker_stats "$1"
	fi
	trop_seed_info | trop_awk 'sul'
	return 0
}

trop_seed_tracker_stats ()
{
	exit 0; # add tracker stuff
	local a b ll nl

	a=$(echo "$trsi" | grep "$t" -B3 | grep Name | cut -b3-) || die
	b=$(echo "$trsi" | grep "$t" -A8 | grep '^  Upload Speed')
	ll=$(($(echo "$a" | wc -L) + 1))
	nl=$(echo "$a" | wc -l)
}

trop_seed_tracker ()
{
	trop_common
	trop_seed_info | trop_awk 'tsi' $1
}

trop_make_file ()
{
	if [ "$1" = 'r' ]; then
		if [ "$2" = 'm' ]; then printf "$(tmf_mkr)" && return 0 || return 1; fi
		tmf_prefix="regfile"
		tmf_mkr ()
		{
			tmf_mkreg=`touch "$(tmf_fname)"` && \
			 return 0 || return 1
		}
	elif [ "$1" = 'p' ]; then
		if [ "$2" = 'm' ]; then printf "%s" "$(tmf_mkp)" && return 0 || return 1; fi
		tmf_prefix="np"
		tmf_mkp ()
		{
			tmf_mkfifo=`mkfifo "$(tmf_fname)"` && \
			return 0 || return 1
		}
	else
		 die 'trop_make_file(): file not recognized'
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
	if [ ! $(echo "$1" | grep -qEx '^t') ]; then
		if [ ! -f $TROP_TRACKER ]; then
			die 'tracker file not found!'
		fi
		if [ "$1" = 'tsi' ] && [ -z $2 ]; then
			die 'no alias specified'
		fi
		awk -f ${scrdir}/trop.awk func=${1} ${2} ${TROP_TRACKER} || die 'trop.awk failed'
		return 0
	fi
	awk -f ${scrdir}/trop.awk func=${1} || die 'trop.awk failed'
	return 0
}

trop_tracker_total ()
{
	# add tracker stuff
	#trop_tracker_get $1
	local ttt_t ttt_ta ttt_tt ttt_lst ttt_diff ttt_diffa ttt_diffl ttt_difftn ttt_diffu ttt_ltmp ttt_s
	ttt_t="$1" ttt_tt=1
	if [ ! -e "${scrdir}/.cache/ttt_"$1"_lstp" ]; then
		touch ${scrdir}/.cache/ttt_"$1"_lstp
		ttt_lst="$(trop_torrent l| grep -v '^Sum'| grep -v '^ID')" && echo "$ttt_lst" > "${scrdir}/.cache/ttt_"$1"_lstp" || die
	else
		ttt_lst="$(echo "$(trop_torrent l) grep -v '^Sum'| grep -v '^ID'")" || die
	fi
	if [ -n "$(ttt_diff="$(echo "$ttt_lst" | diff --unchanged-line-format='' - $scrdir/.cache/ttt_"$1"_lstp)")" ]; then
		ttt_diffl="$(echo "$ttt_diff" | cut -b 2 | cut -f1 -d ' '| tr -d '[:blank:]')" || exit 2
	fi

	ttt_i=1 ttt_tac=0

	echo checking all torrent info...
	if [ ! -e "$scrdir/.cache/ttt_"$1"_tap" ]; then # first permanent cache only should run once ever
		echo 'caching all torrent info'
		ttt_ta="$(trop_torrent all i)"
		echo "$ttt_ta" > $scrdir/.cache/ttt_"$1"_tap && ttt_tac=1 || die
	fi

	if [ -n "$ttt_diffl" ]; then
		ttt_tta=`cat ${scrdir}/.cache/ttt_"$1"_tap`
		ttt_difftn=$(echo "$diffl" | wc -l)
		local i=0
		while [ $i -lt $ttt_difftn ]; do
			#ttt_tta=`printf "%s\n%s" "$ttt_ta" "$(trop_torrent "`echo "$ttt_diffl" | awk NR==$i`" i)"`
			: $((i += 1))
		done
		ttt_diffu=1
	fi

	echo grabbing tracker details...;echo
	# a="$(echo "$ttt_ta" | grep "$ttt_t" -B 3 | grep Name | cut -b3-)"
	# b="$(echo "$ttt_ta" | grep "$ttt_t" -A 8 | grep Name | cut -b3-)"

	if [ "$ttt_diffu" = 1 ]; then
		ttt_s="$(echo "$ttt_ta" | grep "$ttt_t" -A 14 | grep Downloaded -A 2 | cut -b 2-)"
	else
		if [ -e "$scrdir/.cache/ttt_"$1"_ttotal" ]; then
			printf "total downloaded: " ; cat "$scrdir/.cache/ttt_"$1"_ttotal" || die
			exit 0
		fi
		ttt_s="$(echo "$(cat $scrdir/.cache/ttt_"$1"_tap)" grep "$ttt_t" -A 14 | grep Downloaded -A 2 | cut -b 2-)"
	fi
	local ttt_d="$(echo "$ttt_s" | grep Downloaded | tr -d '[:blank:]' | cut -b 12-)"
	local ttt_tdn=0

	local ttt_np=`trop_make_file p`

	grep PATH /etc/profile > "$ttt_np" &

	# total dl as seen by tracker (does not include freeleech downloads)
	echo "$ttt_d" > "$ttt_np" &
	while read -r l; do
		if [ -n "$(echo "$l" | grep PATH)" ]; then continue; fi

		if [ "$l" = 'None' ]; then
			continue
		elif [ -n "$(echo "$l" | grep GB)" ]; then
			ttt_tdn=`echo "scale=2; $ttt_tdn + $(echo "$l" | tr -d '[:alpha:]')" | bc`
		elif [ -n "$(echo "$l" | grep MB)" ]; then
			ttt_ltmp=`echo "$l" | tr -d '[:alpha:]'`
			ttt_tdn=`echo "scale=2; $ttt_tdn + ( $ttt_ltmp / 1000 )" | bc`
		elif [ -n "$(echo "$1" | grep KB)" ]; then
			ttt_ltmp=`echo "$l" | tr -d '[:alpha:]'`
			ttt_tdn=`echo "scale=2; $ttt_tdn + ( $ttt_ltmp / 1000000 )" | bc`
		fi
	done < "$ttt_np" # use prefix in loop because env is exported to it

	echo "total downloaded: $(echo "$ttt_tdn" | sed -E 's/0*$//') GB" && rm "$ttt_np" &&
	printf "%s GB\n" "$(echo "$ttt_tdn")" > $scrdir/.cache/ttt_"$1"_ttotal || die 'error printing dl info'

	exit 0
}

trop_torrent ()
{
	if [ -n "$1" ] && [ -z "$2" ]; then
		transmission-remote $(uhc) -n "$AUTH" -$1 || die 'transmission-remote error'
		return 0
	fi
	if [ -z "$1" ]; then
		usage
	fi
	transmission-remote $(uhc) -n "$AUTH" -t $1 -$2 || die 'transmission-remote error'
}

args_look_ahead ()
{
	local i=2
	while [ $i -lt $# ]; do
		res="$(echo "$i" | grep '^-' -q)" && \
		unset res && return 1;
		: $((i += 1))
	done;
	unset res;
	return 0;
}

die ()
{
	if [ -n "$@" ]; then
		_ "$@" >&2
	fi
	kill -SIGABRT $toppid
}

_ ()
{
	echo ${PROG_NAME}":" "$@"
}

# ---------- main -------------
unset _
PROG_NAME=${0##*/}
: ${@:?"$(printf "%s" "$(usage)")"}
hash transmission-remote 2>/dev/null || \
{ _ "can't find transmission-remote in PATH!" ; exit 1 ;}
LC_ALL=C
toppid=$$

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
		trop_seed_ulrate $1
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
			die 'multi opt not allowed'
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
		transmission-remote $(uhc) -n "$AUTH" ${1} || die 'transmission-remote error'
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
