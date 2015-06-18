#!/bin/sh
#
# TODO: implement mass location change
# 	real tracker checking
#	use mktemp and $TMPDIR for files

TROP_VERSION=\
'trop 0.0.1
last checked against: transmission-remote 2.84 (14307)'

usage ()
{
	cat <<EOF
trop.sh - transmission-remote text operations

usage: `basename $0` [-b host:port] [-a auth] [options]

options:
 -b				  	set host and port to connect to
 -a				  	set authorization information
 -p					pass flags directly to tr-remote - note: keep all flags in a single quotation!
 -ns				  	list number of torrents actively seeding
 -si				  	list information about active torrents
 -sul		 	          	list active torrents and their upload rates 
 -tul		<tracker-alias>		list active torrents and their upload rates by tracker
 -ts		<tracker-alias>		list active torrents by tracker 
 -t		<torrent-id> <opts>	pass tr-remote option to torrent
 -V					show version information, including last version of tr-remote checked against
 -h					show this output
EOF

	exit 0;
}

uhc ()
{
	if [ -n "$USERHOST" ];then printf "%s" "$USERHOST";else printf "";fi
}

trop_common ()
{
	export trsi="$(trop_seed_info)" || return 1
	return 0;
}

trop_private ()
{
	if [ "$auser" = 1 ] && [ "$huser" = 1 ];then return 0;fi
	
	. $scrdir/tropriv.sh

	if [ "$1" == 'seth' ];then
		. $scrdir/tropriv.sh "$@" && return 0 || return 1
	fi
	if [ "$1" == 'seta' ];then
		. $scrdir/tropriv.sh "$@" && return 0 || return 1
	fi
	
	return 0;
}

trop_num_seed ()
{
	wc -l <<<"$(trop_seed_list)" || exit 1
	exit 0;
}

trop_seed_info ()
{
	trsl="$(trop_seed_list)" || exit 1
	trsltmp="$(<<<"$trsl" cut -b2-4 | tr -d '[:blank:]')"
	
	i=1
	itmp=${i}

	checki () { if [ "$itmp" = `expr $i - 1` ];then return 0;else return 1;fi }
	# XXX: needs work
	if [ "$trsltmp" = '' ];then { echo trsl error ; exit 1; } fi ; while ((i <= $(<<<"$trsltmp" wc -l)));do trop_torrent $(<<<"$trsltmp" awk NR==$i) i && echo ----- && itmp=$i && ((i++)) && checki || i=1000 ;done \
	; if [ $i = 1000 ] && [ $? = 0 ];then { echo trt error ; exit 1; };fi ; exit 0

	# trt error handling -
	# if itmp is i-1 then trt was successful, so ret true
	# else it wasn't return false
}

trop_seed_list ()
{
	<<<"$(transmission-remote $(uhc) -n "$AUTH" -l)" awk '$9 == "Seeding" || $9 == "Up & Down"' || exit 1
}

trop_seed_ulrate ()
{
	trop_common || exit 1

	if [ -n "$1" ];then
		trop_seed_tracker_stats "$1"
	else 

	a=$(<<<"$trsi" grep '^  Name' | cut -b3-)
	b=$(<<<"$trsi" grep Upload\ Speed)
	ll=`expr $(wc -L <<< "$a") + 1`
	nl=$(wc -l <<< "$a")
	
	fi

	for ((i=1; i <= nl; i++)); do
		local tmp=$(awk NR==$i <<< "$a" )
		local tmpn=$(wc -m <<< $tmp)
		local tmpo=`expr $tmpn % 2`
		if [ ! $tmpo ]; then
			while ((tmpn < ll)); do
				tmp="$tmp  " && tmpn+=2;
			done;
		else
			while ((tmpn < ll)); do
				tmp="$tmp " && ((tmp++))
			done;
		fi
		#if [ tmp > "$ll" ];then tmp="$(sed '$s/.$//' <<< "$tmp")";fi
		printf "%s\t%s\n" "$tmp" "$(awk NR==$i <<< "$b")"
	done
}

trop_seed_tracker_stats ()
{		
    exit 0; # add tracker stuff	
	a=$(<<<"$trsi" grep "$t" -B3 | grep Name | cut -b3-) || exit 1
	b=$(<<<"$trsi" grep "$t" -A8 | grep '^  Upload Speed')
	ll=`expr $(wc -L <<< "$a") + 1`
	nl=$(wc -l <<< "$a")
}

trop_seed_tracker ()
{
	trop_common
	
	if [ "$1" == '' ] || [ "$2" != '' ];then usage && exit 0;fi
    # tracker checking...
	else echo tracker not found; fi || { echo error ; exit 1; }
}

trop_make_file ()
{
	if [ "$1" == 'r' ];then
		if [ "$2" == 'm' ];then printf "$(tmf_mkr)" && return 0 || return 1;fi
		tmf_prefix="regfile"
		tmf_mkr ()
		{
			tmf_mkreg=`touch "$tmf_ftmp"` && \
			printf "$tmf_ftmp" && return 0 || return 1;
		}
	elif [ "$1" == 'p' ];then
		if [ "$2" == 'm' ];then printf "%s" "$(tmf_mkp)" && return 0 || return 1;fi
		tmf_prefix="np"
		tmf_mkp ()
		{
			tmf_mkfifo=`mkfifo "$tmf_ftmp"` && \
			printf "$tmf_ftmp" && return 0 || return 1;
		}
	else
		 echo trop_make_file: file not recognized && exit 1
	fi
	
	tmf_ftmp=`printf "/tmp/%s-%s-%s" "$(basename $0)" "$RANDOM" "$tmf_prefix"`

	while [ -e "$tmf_ftmp" ];do
		tmf_ftmp=`printf "/tmp/%s-%s-%s" "$(basename $0)" "$RANDOM" "$tmf_prefix"`
	done
	
	printf "$(trop_make_file $1 m)" && return 0;
}

trop_tracker_total ()
{
    # add tracker stuff	
	ttt_t="$1"	
	ttt_tt=1
	if [ ! -e "$scrdir/.cache/ttt_"$1"_lstp" ];then 
		touch $scrdir/.cache/ttt_"$1"_lstp
		ttt_lst="$(trop_torrent l|grep -v '^Sum'|grep -v '^ID')" && <<<"$ttt_lst" cat > "$scrdir/.cache/ttt_"$1"_lstp" || exit 1
	else
		ttt_lst="$(<<<"$(trop_torrent l) grep -v '^Sum'|grep -v '^ID'")" || exit 1
	fi
	if [ -n "$(ttt_diff="$(diff --unchanged-line-format='' - $scrdir/.cache/ttt_"$1"_lstp <<<"$ttt_lst")")" ];then 
		ttt_diffl=<<<"$("$ttt_diff" cut -b 2 | cut -f1 -d ' '|tr -d '[:blank:]')";fi || exit 2
	
	ttt_i=1
	ttt_tac=0;
	
	echo checking all torrent info...
	if [ ! -e "$scrdir/.cache/ttt_"$1"_tap" ];then # first permanent cache only should run once ever
		echo 'caching all torrent info'
		ttt_ta="$(trop_torrent all i)"
		echo "$ttt_ta" > $scrdir/.cache/ttt_"$1"_tap && ttt_tac=1 || exit 1
	fi

	if [ -n "$ttt_diffl" ];then 
		ttt_tta=`cat $scrdir/.cache/ttt_"$1"_tap`
		ttt_difftn=$(<<<"diffl" wc -l)
		for ((i=0;i < ttt_difftn;i++));do
			ttt_tta=`printf "%s\n%s" "$ttt_ta" "$(trop_torrent "`<<<"$ttt_diffl" awk NR==$i`" i)"`		
		done
		ttt_diffu=1
	fi 
	
	echo grabbing tracker details...;echo
	# a="$(<<<"$ttt_ta" grep "$ttt_t" -B 3 |grep Name | cut -b3-)"
	# b="$(<<<"$ttt_ta" grep "$ttt_t" -A 8 |grep Name | cut -b3-)"
	
	if [ "$ttt_diffu" == 1 ];then
		ttt_s="$(<<<"$ttt_ta" grep "$ttt_t" -A 14 |grep Downloaded -A 2 |cut -b 2-)"
	else
		if [ -e "$scrdir/.cache/ttt_"$1"_ttotal" ];then
			printf "total downloaded: " ; cat "$scrdir/.cache/ttt_"$1"_ttotal" && exit 0 || exit 1
		fi
		ttt_s="$(<<<"$(cat $scrdir/.cache/ttt_"$1"_tap)" grep "$ttt_t" -A 14 |grep Downloaded -A 2 |cut -b 2-)"
	fi
	ttt_d="$(<<<"$ttt_s" grep Downloaded | tr -d '[:blank:]' | cut -b 12-)"
	ttt_tdn=0	
	
	ttt_np=`trop_make_file p`
	
	grep PATH /etc/profile > "$ttt_np" &
	
	# total dl as seen by tracker (does not include freeleech downloads)
			<<<"$ttt_d" cat > "$ttt_np" &
			while read -r l;do
			if [ -n "$(<<<"$l" grep PATH)" ];then continue;fi

			if [ "$l" == 'None' ]; then
				continue
			elif [ -n "$(<<<"$l" grep GB)" ];then
				ttt_tdn=`<<<"scale=2; $ttt_tdn + $(<<<"$l" tr -d '[:alpha:]')" bc`
			elif [ -n "$(<<<"$l" grep MB)" ];then
				ttt_ltmp=`<<<"$l" tr -d '[:alpha:]'`
				ttt_tdn=`<<<"scale=2; $ttt_tdn + ( $ttt_ltmp / 1000 )" bc`
			elif [ -n "$(<<<"$1" grep KB)" ];then
				ttt_ltmp=`<<<"$l" tr -d '[:alpha:]'`
				ttt_tdn=`<<<"scale=2; $ttt_tdn + ( $ttt_ltmp / 1000000 )" bc`
			fi
			
				done < "$ttt_np" # use prefix in loop because env is exported to it

	echo "total downloaded: $(<<<"$ttt_tdn" sed 's/0*$//') GB" && rm "$ttt_np" && 
			printf "%s GB\n" "$(<<<"$ttt_tdn" cat)" > $scrdir/.cache/ttt_"$1"_ttotal && exit 0 || exit 1
}

trop_torrent ()
{
	if [ -n "$1" ] && [ -z "$2" ];then
		transmission-remote $(uhc) -n "$AUTH" -$1 || { echo "transmission-remote error" ; exit 1; } && exit 0;fi
	if [ -z "$1" ];then
		usage && exit 0;fi
	
	transmission-remote $(uhc) -n "$AUTH" -t $1 -$2 || exit 1
}

args_look_ahead ()
{
	for ((i=2; i < $#; i++)); do
		res="$(<<<"$i" grep '^-' -q)" &&
		unset res && return 1;
	done;
	unset res;
	return 0;
}

# ---------- main -------------
	
	noarg=${@:?"$(printf "\n%s" "$(usage)")"}

	# checks if file used to call the script is a link or the script file itself
	res="$(<<<"$0" grep -q '\\*.sh$')" && \
		#scrdir="$(<<<"$0" sed 's/\/\+[^\/]\+$//')" \
        scrdir="." \
	|| \
		scrdir="$(<<<"$(ls -l $0)" sed 's/^.*-> //' |sed 's/\/\+[^\/]\+$//')"

	#if [ -n "$(<<<"$@" grep '\-s')" ];then
	#	if [ ! -n "$(<<<"$@" grep '\-si')" ] && [ ! -n "$(<<<"$@" grep '\-sul')" ];then
	#		printf "possible opts: %s %s\n" "-si" "-sul" && exit 0;fi
	#fi
	
	auser=0
	huser=${auser}
	
	while true; do
		case $1 in
			-a)
			shift && \
			trop_private "seta" "$1" && auser=1 && shift || { echo bad\ auth && exit 1; }
			;;
			-b)
			shift && \
			trop_private "seth" "$1" && huser=1 && shift || { echo bad\ user/host && exit 1; }
			;;
			-ns) 
			shift;
			trop_private && \
			trop_num_seed && exit 0 || exit 1;
			;;
			-si)
			shift;
			trop_private && \
			trop_seed_info && exit 0 || exit 1;
			;;
			-sul)
			shift;
			trop_private && \
			trop_seed_ulrate && exit 0 || exit 1;
			;;
			-ts)
			trop_private && \
			shift && \
			trop_seed_tracker $1 && exit 0 || exit 1;
			;;
			-tul)
			trop_private && \
			shift && \
			trop_seed_ulrate $1 && exit 0 || exit 1;
			;;
			-tt)
			trop_private && \
			shift && \
			trop_tracker_total $1
			exit 0;
			;;
			-t)
			trop_private && \
			shift && \
			if [ -n "$4" ]; then echo 'multi opt not allowed' ; exit 0;fi
			if [ "$1" == 'dl' ]; then
				trop_torrent l | awk '$9 == "Downloading" || $9 == "Up & Down"' && exit 0 || exit 1;
			else
				trop_torrent $1 $2 && exit 0 || exit 1;
			fi
			;;
			-p)
			trop_private && \
			shift && \
			transmission-remote $(uhc) -n "$AUTH" $(eval <<<"${1}" cat) && exit 0 || exit 1;
			;;
			-V)
			echo "$TROP_VERSION" && exit 0;
			;;
			-h|*)
			usage && exit 0;
			;;
		esac
	done
