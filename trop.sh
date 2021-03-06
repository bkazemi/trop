#!/bin/sh

TROP_VERSION=\
'trop 1.7.9
last checked against: transmission-remote 2.84 (14307)'

# TODO
#  - check if file has POSIX specs

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
 -tm  <tr-alias> <b> [nb]  same as -m, but for torrents under tracker-alias

 -dl                       show information about downloading torrents
 -ns                       list number of torrents actively seeding
 -si                       show information about seeding torrents
 -sul                      list seeding torrents and their upload rates

 -t    <torrent-id> <opt>  pass tr-remote option to torrent
 -ta   [tracker-alias]     add a tracker alias interactively
 -td   <torrent-id> <act>  have torrent perform action upon DL completion
 -notd                     stop torrent from being added to the torrent-done
                           queue if torrents are automatically being added
 -terr                     show torrents that have errors
 -tdel <tracker-alias>     remove tracker-alias from trackers file
 -tdl  <tracker-alias>     show info about downloading torrents by tracker
 -tl   [tracker-alias]     show tracker URLs that are binded to tracker-alias
 -tns  <tracker-alias>     list number of torrents actively seeding by tracker
 -ts   <tracker-alias>     list seeding torrents by tracker
 -tt   <tracker-alias>     show total amount downloaded from tracker
 -tul  <tracker-alias>     list seeding torrents and their UL rates by tracker

 -startup                  setup defaults - intended to be used when logging in
 -q                        suppress all message output
 -V, -version              show version information
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
	[ $silent -eq 0 ] && printf -- "$@" >&2

	return 0
}

trop_private ()
{
	## $1 - specify set{a,h} to set HOSTPORT or AUTH
	## $2 - the user-specified HOSTPORT/AUTH

	if [ -z "$1" ]; then
		[ $PRIVATE -eq 1 ] || { . ${srcdir}/tropriv.sh ; PRIVATE=1 ;}
		local trout=$(transmission-remote $(hpc) -n "$AUTH" -st 2>&1) || \
		{ [ -n "$trout" ] &&                      \
		  printf_wrap "transmission-remote: %s\n" \
		              "${trout##*transmission-remote: }"
		  die $ERR_TR_CONNECT ;}
		return 0
	fi

	[ $auser -eq 1 ] && [ $huser -eq 1 ] && return 0
	[ $PRIVATE -eq 1 ] || { . ${srcdir}/tropriv.sh ; PRIVATE=1 ;}

	if [ "$1" = 'sethp' ] || [ "$1" = 'seta' ]; then
		. ${srcdir}/tropriv.sh "$@" ; return 0
	fi

	return 0
}

trop_seed_list ()
{
	transmission-remote $(hpc) -n "$AUTH" -l 2>/dev/null \
	| awk                                                \
	'
		$9 == "Seeding"

	' || die $ERR_TSL_FAIL

	return 0
}

trop_num_seed ()
{
	trop_seed_list | pipe_check "wc -l | tr -d '[:blank:]'" || die $?

	return 0
}

trop_num_seed_tracker ()
{
	## $1 - alias

	trop_seed_info | pipe_check "trop_awk 'tns' $1" || die $?

	return 0
}

trop_seed_info ()
{

	trop_seed_list \
	| awk          \
	'
		$1 !~ /(ID)|(Sum)/ { print $1 }

	' | pipe_check \
	'
	 while read tid; do
		trop_torrent ${tid} i
		echo ----
	 done
	' || die $?

	return 0
}

trop_seed_info_tracker ()
{
	## $1 - alias

	trop_seed_info | pipe_check "trop_awk 'tsi' $1" || die $?

	return 0
}


trop_seed_ulrate ()
{

	trop_seed_list | pipe_check "trop_awk 'sul'" || die $?

	return 0
}

trop_seed_ulrate_tracker()
{
	## $1 - alias

	trop_seed_info | pipe_check "trop_awk 'tsul' $1" || die $?

	return 0
}

trop_make_file ()
{
	## $1 - type of file to create
	## $2 - `m' to create

	if [ "$1" = 'r' ]; then
		[ "$2" = 'm' ] && { printf "$(tmf_mkr)" ; return $? ;}
		local prefix='regfile'
		tmf_mkr ()
		{
			touch "$(tmf_fname)" && \
			return 0 || return 1
		}
	elif [ "$1" = 'p' ]; then
		[ "$2" = 'm' ] && { printf "%s" "$(tmf_mkp)" ; return $? ;}
		local prefix='np'
		tmf_mkp ()
		{
			mkfifo "$(tmf_fname)"
			return $(($? ? 1 : 0))
		}
	else
		 die $ERR_TMF_UNKNOWN_FTYPE # unknown filetype
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
	## $2..$n - options to pass to AWK function

	local func=${1} ; shift
	local awkopt="awk -f ${srcdir}/trop.awk -v silent=${silent}"
	      # string cannot be split between lines with leading spaces
	      awkopt="$awkopt -v progname=trop.awk func=${func}"
	case ${func} in
	ta)
		[ ! -f $TROP_TRACKER ] && return $ERR_TRACKER_FILE
		${awkopt} $1 $2 "$3" ${TROP_TRACKER} || return $ERR_TROP_AWK
		;;
	tth)
		local thash=
		[ -n "$3" ] && thash="${srcdir}/.cache/${3}_thash"
		${awkopt} "$1" "$2" ${thash} || return $ERR_TROP_AWK
		;;
	tl)
		[ ! -f $TROP_TRACKER ] && return $ERR_TRACKER_FILE
		${awkopt} "$@" ${TROP_TRACKER} || return $ERR_TROP_AWK
		;;
	t*)
		[ ! -f $TROP_TRACKER ] && return $ERR_TRACKER_FILE
		[ -z $1 ] && return $ERR_NO_ALIAS
		local tmp=${func} ; func='tm'
		if ! [ "$1" = 'tm' ] && [ -z "${1##t[t]*}" ]; then
			${awkopt} ${1} ${TROP_TRACKER} \
			|| return $ERR_NO_MSG # alias not found, awk reports
		fi
		func=${tmp}
		${awkopt} "$@" ${TROP_TRACKER} || return $ERR_TROP_AWK
		;;
	*)
		${awkopt} "$@" || return $ERR_TROP_AWK
		;;
	esac

	return 0
}

trop_tracker_total ()
{
	## $1 - alias

	# check if alias is defined
	echo | trop_awk 'tm' ${1} || die $?
	local ta tta lst diff difftn s
	local t="$1" tt=1 diffu=0
	lst="$(trop_torrent l | awk '{ if ($1 !~ /Sum|ID/) print $1 }')" \
	|| die $ERR_TID_FAIL
	[ ! -e "${srcdir}/.cache" ] && \
	{ mkdir ${srcdir}/.cache || die $ERR_TTT_CACHE ;}
	[ ! -e "${srcdir}/.cache/"$1"_lstp" ] &&                                \
	{ echo "$lst" > "${srcdir}/.cache/"${1}"_lstp" || die $ERR_TTT_CACHE ;} \
	|| diff="$(echo "$lst" | diff --unchanged-line-format='' \
	                         --old-line-format='' ${srcdir}/.cache/"$1"_lstp -)"

	i=1 tac=0
	_ 'checking all torrent info...'
	if [ ! -e "${srcdir}/.cache/"$1"_tap" ]; then
		# first permanent cache
		_ 'caching all torrent info'
		ta="$(trop_torrent all i)"                      &&              \
		echo "$ta" > ${srcdir}/.cache/"$1"_tap && tac=1 &&              \
		echo "$ta" | trop_awk 'tth' 'add' > ${srcdir}/.cache/"$1"_thash \
		|| die $?
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
			}') || die $ERR_TTT_CACHE
			# if tth returns one, then torrent's idx was shifted
			if echo | trop_awk 'tth' 'check' $h ${1}; then
				# ;
			else # it is a new torrent
				tta=`printf "%s\n%s" "$tta" "$(trop_torrent ${tid} i)"`
			fi
			: $((i += 1))
		done
		diffu=1
	fi

	_ "grabbing tracker details...\n"
	if [ $diffu -eq 1 ]; then
		s="$(echo "$tta" | trop_awk 'ttd' ${1})" || die $?
	else
		[ -e "${srcdir}/.cache/"$1"_ttotal" ]          \
		&& printf "Total downloaded: %s\n"             \
		       "$(cat "${srcdir}/.cache/"$1"_ttotal")" \
		&& return 0
		s="$(cat ${srcdir}/.cache/"$1"_tap | trop_awk 'ttd' ${1})"
	fi
	local d="$(echo "$s" | awk \
	          '{ if ($1 ~ /Downloaded/) print $2 $3 }')"
	echo "$d" | trop_awk 'tt' $1 ${srcdir}/.cache/${1}_ttotal || die $?

	return 0
}

trop_torrent ()
{
	##  $1  - torrent ID or single opt
	## [$2] - option paired with torrent ID
	## [$3] - sub-option

	local opt
	if [ -z "$2" ]; then
		# if there are 3 or more chars then it is a long option
		# with some exceptions
		opt=`echo $1 | sed -r 's/^-+//g'`
		if [ ${#opt} -gt 2 ] && [ "$opt" != "asd" ] \
		                     && [ "$opt" != "asu" ] \
		                     && [ "$opt" != "asc" ] \
		                     && [ "$opt" != "ASC" ] \
		                     && [ "$opt" != "gsr" ] \
		                     && [ "$opt" != "GSR" ]; then
			opt="--${opt}"
		else
			opt="-${opt}"
		fi
		transmission-remote $(hpc) -n "$AUTH" ${opt} || die $ERR_TR_FAIL
		return 0
	fi

	opt=`echo $2 | sed -r 's/^-+//g'`
	local thirdopt=0
	case $opt in
	d|downlimit) thirdopt=1 ;;
	D|no-downlimit);;
	f|files);;
	i|info);;
	ip|info-peers);;
	ic|info-pieces);;
	it|info-trackers);;
	Bh|bandwith-high);;
	Bn|bandwith-normal);;
	Bl|bandwith-low);;
	pr|peers) thirdopt=1 ;;
	r|remove);;
	R|remove-and-delete);;
	reannounce);;
	move) thirdopt=1 ;;
	find) thirdopt=1 ;;
	sr|seedratio) thirdopt=1 ;;
	SR|no-seedratio);;
	srd|seedratio-default);;
	td|tracker-add) thirdopt=1 ;;
	tr|tracker-remove) thirdopt=1 ;;
	s|start);;
	S|stop);;
	hl|honor-session);;
	HL|no-honor-session);;
	u|uplimit) thirdopt=1 ;;
	U|no-uplimit);;
	no-utp);;
	v|verify);;
	pi|peer-info);;
	*) die $ERR_TT_UNKNOWN_OPT ;;
	esac

	if [ ${#opt} -gt 2 ] && [ "$opt" != "srd" ] \
	                     && [ "$opt" != "gsr" ] \
	                     && [ "$opt" != "GSR" ]; then
		opt="--${opt}"
	else
		opt="-${opt}"
	fi
	{ [ $thirdopt -eq 1 ]                                 && \
	ttshift=1                                             && \
	transmission-remote $(hpc) -n "$AUTH" -t $1 $opt "$3" || \
	transmission-remote $(hpc) -n "$AUTH" -t $1 $opt         \
	;} || die $ERR_TR_FAIL

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
		[ -z "$2" ] && die $ERR_BAD_ARGS
		cat ${srcdir}/.cache/tdscript | while read tid; do
			[ "${tid%% *}" = "$1" ] && die $ERR_TTD_SCHG
		done
		echo "$@" >> ${srcdir}/.cache/tdscript
		return 0
	fi
	local nr=0 tid
	cat ${srcdir}/.cache/tdscript | while read tid_and_cmd; do
		: $((nr += 1))
		if [ "$(trop_torrent ${tid_and_cmd%% *} i \
		        | awk '$1 ~ /^Percent/ { print $3 }')" \
		     = "100%" ]
		then
			eval trop_torrent $tid_and_cmd 2>>${TROP_LOG_PATH} \
			|| ldie $ERR_TTD_ACT_FAIL $tid
			_l "successfully processed command on torrent ${tid_and_cmd%% *}"\
			   "\b, removing from queue"
			sed -e "${nr}d" -i '' ${srcdir}/.cache/tdscript
		fi
	done

	return 0
}

trop_tracker_add()
{
	## $1 - alias to add

	[ -n "$1" ] && a=$1 || \
	{ printf_wrap 'enter alias to use > ' ; read a ;}
	printf_wrap 'enter primary tracker > '         ; read pt
	printf_wrap 'add secondary tracker(s)? y/n > ' ; read ast
	[ ${#ast} -gt 1 ] && ast=$(echo $ast | tr '[:upper:]' '[:lower:]')
	while :; do
		case $ast in
		[Yy]|yes)
			printf_wrap 'how many trackers would you like to add? > '
			read numt
			local numtlen=${#numt}
			numt=$(echo $numt | tr -Cd '[:digit:]')
			# if numt != numtlen, then numt
			# was stripped and thus invalid
			while [ -z "$numt"            ] ||
			      [ $numt -le 0           ] ||
			      [ ${#numt} -ne $numtlen ]; do
				printf_wrap "enter a valid number > "
				read numt
				numtlen=${#numt}
				numt=$(echo $numt | tr -Cd '[:digit:]')
			done
			break
			;;
		[Nn]|no) break ;;
		*)
			printf_wrap 'please answer yes or no > ' ; read ast
			[ ${#ast} -gt 1 ] && ast=$(echo $ast | tr '[:upper:]' '[:lower:]')
			;;
		esac
	done
	[ ! $numt ] && numt=0 st='_NULL'
	local i=1
	while [ $i -le $numt ]; do
		printf_wrap "enter tracker #%d > " "$i"
		read tmp
		[ "$st" ] && st="$st ""$tmp" || \
		st="$tmp"
		: $((i += 1))
	done
	echo | trop_awk 'ta' $a $pt "$st" || die $?

	return 0
}

trop_tracker_list ()
{
	echo | trop_awk 'tl' $1 || die $?
}

trop_mtl_common ()
{
	##  $1  - run check_symlink() or do_move()
	## [$2] - dir prefix for check_symlink
	## [$3] - repl prefix for check_symlink

	check_symlink ()
	{
		# XXX assuming tr session was started in $HOME
		# XXX does tr create directories that don't
		#     exist for --move?
		if [ "${HOSTPORT%:*}" = 'localhost' ] || \
		   [ "${HOSTPORT%:*}" = '127.0.0.1' ] || \
		   [ "${HOSTPORT%:*}" = '::1'       ] || \
		   [ -z "${HOSTPORT}" ]
		then
			# trailing fwd slashes need to stripped
			# so file doesn't follows symlinks
			prefx="$(echo "$1" | sed -r 's/\/+$//')"
			repfx="$(echo "$2" | sed -r 's/\/+$//')"
			# `./' is relative to $PWD, replace it
			echo "$prefx" | grep -qE '^\./' && \
			prefx="${PWD}/${prefx#./}"
			echo "$repfx" | grep -qE '^\./' && \
			repfx="${PWD}/${repfx#./}"
			# prepend $HOME if paths are relative
			echo "$prefx" | grep -qE '^[^/]' && \
			prefx="${HOME}/$prefx"
			echo "$repfx" | grep -qE '^[^/]' && \
			repfx="${HOME}/$repfx"
			# strip extraneous fwd slashes to prepare for
			# string comparison
			prefx="$(echo "$prefx" | sed -r 's/\/+/\//g')"
			repfx="$(echo "$repfx" | sed -r 's/\/+/\//g')"
			if [ "$prefx" = "$repfx" ]; then
				die $ERR_TMTLC_SAMEDIR
			else
				file -hb "$prefx" "$repfx"            \
				| awk -v p="${prefx}" -v r="${repfx}" \
				'
					BEGIN { i = 0 }
					{ if (/^symbolic link to /) {
					  	absdir[i] = substr($0, 18) # start at len(m)+1
					  	if (absdir[i++] !~ /^\//) # relative path
					  		absdir[i-1] = "/"absdir[i-1]
					  } else nonsym = (NR == 1 ? p : r)
					}
					END {
						if (!i) exit 0 # no symlinks
						exit (i == 2 ? absdir[0] == absdir[1] : absdir[0] == nonsym)
					}
				' || die $ERR_TMTLC_SYMLINK
			fi
		fi
	}
	do_move ()
	{
		local tid newloc numt=0
		while read tmp; do
			tid=${tmp%% *} newloc=$(echo $tmp | sed -r 's/^[^ ]+ //')     \
			&& eval ${tmptr} -t ${tid} --move "${newloc}" >/dev/null      \
			&& printf_wrap "successfully moved $((numt += 1)) torrents\r" \
			|| break
		done \
		|| die $ERR_TMTL_MV_FAIL ${tid}
	}
	eval "$@"
	return $?
}

trop_mv_torrent_location()
{
	##  $1  - dir prefix to replace
	## [$2] - replacement prefix

	trop_mtl_common check_symlink "$1" "$2"
	trop_torrent all i                         \
	| trop_awk 'mtl' "$1" "$2"                 \
	| pipe_check 'trop_mtl_common do_move' 220 \
	|| die $?
	echo # newline

	return 0
}

trop_mv_torrent_location_tracker ()
{
	##  $1  - alias
	##  $2  - dir prefix to replace
	## [$3] - replacement prefix

	trop_mtl_common	check_symlink "$2" "$3"
	trop_torrent all i                         \
	| trop_awk 'tmtl' "$1" "$2" "$3"           \
	| pipe_check 'trop_mtl_common do_move' 220 \
	|| die $?
	echo # newline

	return 0
}

pipe_check ()
{
	## $1 - shell commands
	## $2 - custom err code

	{ \
	local inp="$(cat /dev/stdin)"
	if [ -n "$inp" ]; then
		# pass along...
		echo "$inp" | eval "$1" || return $?
		return 0
	fi
	[ -n "$2" ] && return $2
	return $ERR_PC_STDIN_EMPTY \
	;}
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

_w ()
{
	## $@ - strings to echo

	_ "WARNING:" "$@"

	return 0
}

# reminder: only use functions to return codes
#           _never_ use exit!
#
# largest number: 29

ERR_TR_FAIL=1

# trop_seed_list
ERR_TSL_FAIL=2

# trop_make_file
ERR_TMF_UNKNOWN_FTYPE=3

# pipe_check
ERR_PC_STDIN_EMPTY=4
ERR_PC_NO_INPUT=5

# trop_torrent
ERR_TT_UNKNOWN_OPT=12

# trop_tracker_total
ERR_TTT_CACHE=6
ERR_TTT_TID_FAIL=7

# show_torrent_errors
ERR_STE_NO_PROBLEMS=8

# check_torrent_errors
ERR_CTE_PROBLEM=9

# trop_tracker_done
ERR_TTD_ACT_FAIL=10
ERR_TTD_SCHG=11

# trop_mtl_common
ERR_TMTLC_MV_FAIL=13
ERR_TMTLC_SYMLINK=14
ERR_TMTLC_SAMEDIR=29

# general
# XXX potential namespace crash with function errors,
#     unimportant for now
ERR_NO_MSG=15
ERR_TR_CONNECT=16
ERR_TROP_AWK=17
ERR_AWK=18
ERR_TRACKER_FILE=19
ERR_NO_ALIAS=20
ERR_ALIAS_NOT_FOUND=21
ERR_TR_PATH=22
ERR_BAD_ARGS=23
ERR_BAD_FORMAT=24
ERR_TOO_MANY_OPTS=25
ERR_TDAUTO_DISABLED=26
ERR_TROP_DEP=27
ERR_SUGGEST_FLAGS=28

trop_errors ()
{
	##  $1  - error code
	## [$2] - error-specific information
	##        to concat with the error msg

	case ${1} in
	$ERR_TR_FAIL )
		_ "transmission-remote error"
		;;
	$ERR_NO_MSG ) ;; # no message
## FUNC GENERAL ERRORS ##
	$ERR_TSL_FAIL )
		_ 'trop_seed_list() failed'
		;;
	$ERR_TMF_UNKNOWN_FTYPE )
		_ 'trop_make_file(): file not recognized'
		;;
	$ERR_PC_STDIN_EMPTY )
		_ 'pipe_check(): nothing on stdin,'\
		  'probably nothing currently seeding'
		;;
	$ERR_PC_NO_INPUT )
		_ 'pipe_check(): no input'
		;;
	$ERR_TT_UNKNOWN_OPT )
		_ "trop_torrent(): unknown option, please check tr-remote for valid"\
		  "options."
		;;
	$ERR_TTT_CACHE )
		_ 'trop_tracker_total(): caching error'
		;;
	$ERR_TTT_TID_FAIL )
		_ "trop_tracker_total(): failed getting torrent IDs"
		;;
	$ERR_STE_NO_PROBLEMS )
		tret=0
		_ 'show_torrent_errors(): no torrent errors detected.'
		;;
	$ERR_CTE_PROBLEM )
		_ "check_torrent_errors(): WARNING: trop detected a torrent error."\
		  "Use the \`-terr' switch to show more info."
		;;
	$ERR_TTD_ACT_FAIL )
		_ 'trop_tracker_done(): failed to perform requested action on torrent'\
		  "$2"
		;;
	$ERR_TTD_SCHG )
		_ 'trop_tracker_done(): torrent already scheduled for action'
		;;
	$ERR_TMTLC_MV_FAIL )
		_ 'trop_mtl_common(): failed to move torrent `' "$2" "'"
		;;
	$ERR_TMTLC_SAMEDIR )
		_ 'trop_mtl_common(): you entered the same directory!'
		;;
	$ERR_TMTLC_SYMLINK )
		_  "trop_mtl_common():\n"                                             \
		   "Transmission currently won't change the location if the current\n"\
		   "one links to the replacement base or vice versa, or, if a\n"      \
		   "relative path was supplied, expands to the same location."
		;;
## FUNC ERR END $$
	$ERR_TR_CONNECT )
		_ "couldn't connect to transmisson session"
		;;
	$ERR_TROP_AWK )
		_ 'trop.awk failed'
		;;
	$ERR_AWK )
		_ 'awk failed'
		;;
## TRACKER ERROR ##
	$ERR_TRACKER_FILE )
		_ 'tracker file not found!'
		;;
	$ERR_NO_ALIAS )
		_ 'no alias specified'
		;;
	$ERR_ALIAS_NOT_FOUND )
		_ 'alias not found'
		;;
## TRACKER ERR END $$
	$ERR_TR_PATH )
		_ "can't find transmission-remote in PATH!"
		;;
	$ERR_BAD_ARGS )
		_ 'insufficient arguments' "$2"
		;;
	$ERR_BAD_FORMAT )
		_ 'bad format' "$2"

		;;
	$ERR_TOO_MANY_OPTS )
		_ 'no futher options should be supplied after' "$2"
		;;
	$ERR_TDAUTO_DISABLED )
		_ 'tr-remote set to run --torrent-done-script,' \
		  'but your configuration has the option disabled. Bailing.'
		;;
	$ERR_TROP_DEP )
		_ 'trop depends on' "$2" "but couldn't find it. Bailing."
		;;
	$ERR_SUGGEST_FLAGS )
		output="bad option\ndid you mean \`-${2%% *}'"
		[ -z "${2##*[ ]*}" ] && \
		for flag in ${2#* }; do
			output="$output or \`-$flag'"
		done
		_ "$output ?"
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

trop_dep ()
{
	## $1 - cmd-name of trop dependency

	case ${1} in
	diff)
		# trop depends on GNU diff options
		diff --version 2>&1 | sed 1q | grep -q 'GNU'
	esac

	return $?
}

check_torrent_errors ()
{
	## $1 - silence warning

	trop_private
	trop_torrent l | awk \
	'
		BEGIN { ret = 0 }
		$1 ~ /\*/ {
			if (!ret)
				ret=1
		}
		END { exit ret }
	' && return 1 || { [ -z "$1" ] && _e $ERR_CTE_PROBLEM ;}

	return 0
}

show_torrent_errors ()
{
	check_torrent_errors 1 || die $ERR_STE_NO_PROBLEMS
	trop_torrent l | awk \
	'
		$1 ~ /\*/ {
			print $1
		}
	' | tr -d \* \
	  | while read tid; do
	        trop_torrent ${tid} i
	    done | trop_awk 'ste'

	return 0
}

# --------------- main --------------- #

# global variables
unset _
PROG_NAME=${0##*/}
[ $# -eq 0 ] && usage
LC_ALL=POSIX
POSIXLY_CORRECT=1
toppid=$$
silent=0
tret=1 # trap exit return value

trap 'exit ${tret}' 6
hash transmission-remote 2>/dev/null || die $ERR_TR_PATH

# check if file used to call the script is a link or the script file itself
# hard links will fail, so stick to sym links
if file -hb $0 | grep -q '^POSIX shell'
then
	[ "${0##*/}" != "$0" ] \
	&& srcdir=${0%/*} || srcdir="."
else
	srcdir="$(echo $(file -hb $0) \
                 | sed -r -e "s/^symbolic link to //i;s/\/+[^\/]+$//")"
fi

TROP_TRACKER=${srcdir}/trackers
auser=0 huser=0 PRIVATE=0 cte=1
. ${srcdir}/trop.conf # various user options
[ "$TROP_LOG" = 'yes' ] && : ${TROP_LOG_PATH:=${srcdir}/trop.log} \
|| TROP_LOG_PATH=/dev/null

for i;
do
	case $i in
	-p)
		break ;;
	-help)
		usage ;;
	-q)
		silent=1 ;;
	-V|-version)
		echo "$TROP_VERSION" ; exit 0 ;;
	-terr|-t[adl]|tdauto|-startup|-tdel)
		cte=0 ;;
	-notd)
		ADD_TORRENT_DONE='no' ;;
	esac
done

while :; do
	case $1 in
	-h)
		test -z "$2" && die $ERR_BAD_ARGS "for \`-h'"
		# regex checks for bad format in host, eg: awd:123g4 -- bad port
		echo $2 | grep -qE '^-|([[:alnum:]]*:.*[^0-9].*)|(:$)' \
		&& die $ERR_BAD_FORMAT "for \`-h'"
		trop_private "sethp" "$2" ; huser=1
		shift 2
		;;
	-a)
		test -z "$2" && die $ERR_BAD_ARGS "for \`-a'"
		echo $2 | grep -qE '^-' && die $ERR_BAD_FORMAT "for \`-a'"
		trop_private "seta" "$2" ; auser=1
		shift 2
		;;
	*) break ;;
	esac
done

[ "$CHECK_TORRENT_ERRORS" = 'yes' ] \
&& [ $silent -eq 0 ]                \
&& [ $cte -eq 1    ]                \
&& check_torrent_errors

while [ "$1" != '' ]; do
	case $1 in
	-terr)
		show_torrent_errors
		exit 0
		;;
	-dl)
		trop_private
		trop_torrent all i | trop_awk 'dli' || die $?
		shift
		;;
	-m)
		[ -z "$2" ] && die $ERR_BAD_ARGS "for \`-m'"
		two=${2}
		echo $2 | grep -qE '/$' && two=${2%*/}
		trop_private
		tmptr="transmission-remote $(hpc) -n \"$AUTH\""
		trop_mv_torrent_location "$two" "$3"
		unset two tmptr
		test -n "$3" ; shift $(($? ? 2 : 3))
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
		trop_seed_ulrate 1
		shift
		;;
	-ta)
		trop_tracker_add $2
		exit 0
		;;
	-td|tdauto)
		[ "$1" = 'tdauto' ] && \
		{ [ "$ADD_TORRENT_DONE" = 'yes' ] || ldie $ERR_TDAUTO_DISABLED ;} \
		&& trop_private 2>>${TROP_LOG_PATH}
		shift
		trop_torrent_done "$@"
		exit 0
		;;
	-tdel)
		echo | trop_awk 'tm' $2 || die $?
		nr=0
		cat "${TROP_TRACKER}" | while read line; do
			: $((nr += 1))
			if [ "${line%% *}" = "$2" ]; then
				ot=$nr
				while read sec; do
					[ ! "${sec%% *}" = '+' ] && break
					: $((ot += 1))
				done
				sed -i '' "${nr},${ot}d" "${TROP_TRACKER}"
				break
			fi
		done                                                            \
		&& esc_srcdir=$(echo $srcdir | sed -r 's/([./?*(){}|])/\\\1/g') \
		&& cache_files=$(ls -1d $srcdir/.cache/${2}_* 2>/dev/null \
		     | sed -r "s/$esc_srcdir\/\.cache\/(conf|priv)_chksum//g")  \
		&& [ -n "${cache_files}" ]                                      \
		&& { rm -- $cache_files \
		     || _w "couldn't remove cache files for \`${2}'" ;}
		_ "successfully removed \`${2}'"
		exit 0
		;;
	-tl)
		trop_tracker_list $2
		test -n "$2" ; shift $(($? ? 1 : 2))
		;;
	-t|-t[0-9]*)
		trop_private
		[ -z "$2" ] && die $ERR_BAD_ARGS "for \`-t'"
		if [ ${#1} -gt 2 ]; then
			one=${1#-t}
			[ -z "${one##*[^0-9,-]*}" ] \
			&& die $ERR_BAD_FORMAT "for \`-t'"
			shift
			savenextopts="$(echo "$@" | sed -r 's/[^\\](&|$)/\\&\1/g')"
			eval set -- ${one} "$savenextopts"
			unset one savenextopts
		else
			shift
		fi
		ttshift=0
		trop_torrent "$@"
		# over-shifting produces garbage
		test -n "$2" ; shift $(($? ? 1 : $((ttshift ? 3 : 2))))
		unset ttshift
		;;
	-tdl|-tns|-tul|-t[mst]|-p)
		[ -z "$2" ] && die $ERR_BAD_ARGS "for \`${1}'"
		trop_private
		move=0
	case $1 in
	-tdl)
		trop_torrent all i | trop_awk 'tdli' $2 || die $?
		;;
	-tm)
		three=${3}
		echo $3 | grep -qE '/$' && three=${3%*/}
		tmptr="transmission-remote $(hpc) -n \"$AUTH\""
		trop_mv_torrent_location_tracker "$2" "$three" "$4"
		unset three tmptr
		test -n "$4" ; move=$(($? ? 1 : 2))
		;;
	-tns)
		trop_num_seed_tracker $2
		;;
	-ts)
		trop_seed_info_tracker $2
		;;
	-tul)
		trop_seed_ulrate_tracker $2
		;;
	-tt)
		trop_dep 'diff' || die $ERR_TROP_DEP 'GNU diff'
		trop_tracker_total $2
		;;
	-p)
		shift
		trout=$(transmission-remote $(hpc) -n "$AUTH" "$@" 2>&1) || \
		{ [ -n "$trout" ] \
		  && echo_wrap "transmission-remote:" "${trout##*transmission-remote: }"
		  die $ERR_TR_FAIL ;}
		[ -n "$trout" ] && echo "$trout"
		echo "$@" | grep -qE '^-(a|add)' && [ "$ADD_TORRENT_DONE" = 'yes' ] && \
		tid=$(trop_torrent l | awk '$1 !~ /(ID)|(Sum)/{print $1}' | sort -rn \
		      | sed 1q)
		[ -n "$tid" ] && trop_torrent_done ${tid} ${ADD_TORRENT_DONE_ACT:-r}
		exit 0
		;;
	esac
		shift $((2 + move))
	;;
	-startup)
		[ "$STARTUP_LOGIN" = 'yes' ] && \
		{ who | awk -v me=$(id -un) \
		'
			BEGIN { mecnt = -1 }
			$1 == me { mecnt++ }
			END { exit mecnt }
		' || break ;}
		_l 'attempting startup...'
		eval ${STARTUP_CMD} || ldie 'STARTUP_CMD failed'
		trop_private 2>>${TROP_LOG_PATH}
		[ "$ADD_TORRENT_DONE" = 'yes' ] && \
		{ transmission-remote $(hpc) -n "$AUTH"                                \
		      --torrent-done-script ${srcdir}/trop_torrent_done.sh             \
		   2>>${TROP_LOG_PATH}                                                 \
		  && _l 'set tr-remote --torrent-done-script successfully -' "$(date)" \
		  || _l 'failed to set tr-remote --torrent-done-script' ;}
		exit 0
		;;
	-q|-notd)
		shift
		;;
	# suggest a flag to the user
	-no*)
		die $ERR_SUGGEST_FLAGS "notd"
		;;
	-s*)
		die $ERR_SUGGEST_FLAGS "si sul"
		;;
	-t???)
		die $ERR_SUGGEST_FLAGS "terr tdel"
		;;
	-t??)
		die $ERR_SUGGEST_FLAGS "tdl tns tul"
		;;
	-t[a-mA-M])
		die $ERR_SUGGEST_FLAGS "ta td tl tm"
		;;
	-t[n-zN-Z])
		die $ERR_SUGGEST_FLAGS "ts tt"
		;;
	-[a-mA-M])
		die $ERR_SUGGEST_FLAGS "a h m"
		;;
	-[n-zN-Z])
		die $ERR_SUGGEST_FLAGS "p q V"
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
# vim: ft=sh:ts=4:sw=4
