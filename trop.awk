# current options include:
#   func=
#     tm   - run tracker_match
#     tmo  - run tracker_match_other
#     tsi  - run tracker_seed_info
#     sul  - run seed_ulrate
#     tsul - run tracker_seedul
#     tt   - run tracker_total
#     ttd  - run tracker_total_details
#     tth  - run tracker_total_hashop
#     ta   - run tracker_add
#     dli  - run dl_info
#     ste  - run show_tracker_errors
#     mtl  - run move_torrent_location
BEGIN {
	if (!length(ARGV[1])) exit
	if (!progname) progname = "trop.awk"
	skip = tmerr = picked_tm = picked_tsi = picked_sul = picked_tsul = picked_tt = 0
	for (i = 1; i < ARGC; i++) {
		if (ARGV[i] ~ /^func=/) {
			sub(/^func=/, "", ARGV[i])
			if (ARGV[i] == "tsi") {
				tmerr = picked_tsi = 1
				tracker_match(ARGV[i+1], ARGV[i+2])
				delargs(i, i+=2)
			} else if (ARGV[i] == "tsul") {
				tmerr = picked_tsul = 1
				tracker_match(ARGV[i+1], ARGV[i+2])
				delargs(i, i+=2)
			} else if (ARGV[i] == "tt") {
				tmerr = picked_tt = 1
				tracker_match(ARGV[i+1], ARGV[i+2])
				cachefile = ARGV[i+3]
				delargs(i, i+=3)
			} else if (ARGV[i] == "ttd") {
				tmerr = picked_ttd = 1
				tracker_match(ARGV[i+1], ARGV[i+2])
				delargs(i, i+=2)
			} else if (ARGV[i] == "tth") {
				picked_tth = 1
				c = 0
				if ((op = ARGV[i+1]) == "check") {
					c = skip = 1
					hash = ARGV[i+2]
				}
				delargs(i, i+=(c ? 2 : 1))
			} else if (ARGV[i] == "tmo") {
				tracker_match_other(ARGV[i+1], ARGV[i+2])
				delargs(i, i+=2)
			} else if (ARGV[i] == "tm") {
				exit(tracker_match(ARGV[i+1], ARGV[i+2]))
			} else if (ARGV[i] == "ta") {
				tracker_add(ARGV[i+1], ARGV[i+2], ARGV[i+3], ARGV[i+4])
				delargs(i, i+=4)
				exit 0
			} else if (ARGV[i] == "mtl") {
				picked_mtl = 1
				prefix = ARGV[i+1]
				newprefix = ARGV[i+2]
				if (newprefix && newprefix !~ /\/$/)
					newprefix = newprefix"/"
				# `&' produces bizarre results without a backslash
				gsub(/\&/, "\\\\&", newprefix)
				delargs(i, i+=2)
			} else if (ARGV[i] == "sul") {
				picked_sul = 1
				delete ARGV[i]
			} else if (ARGV[i] == "ste") {
				picked_te = 1
				delete ARGV[i]
			} else if (ARGV[i] == "dli") {
				tmerr = picked_dli = 1
				delete ARGV[i]
			} else {
				err("invalid function")
			}
		} else if (ARGV[i] == "-") {
			continue
		} else if (skip) {
			skip = 0
			continue
		} else {
			err("invalid option `"ARGV[i]"'")
		}
	}
}

function delargs(s, e)
{
	if (e < s)
		err("invalid arguments to delargs()")
	while (s <= e)
		delete ARGV[s++]

	return
}

function err(msg)
{
	if (!silent)
		printf progname": " msg"\n" > "/dev/stderr"
	exit 1
}

function tracker_is_valid(trackerarr)
{
	for (i in trackerarr)
		if (trackerarr[i] !~ /([[:alnum:]]+:\/\/)?([[:alnum:]]+\.[[:alpha:]]+)+/)
			err("`"trackerarr[i]"' doesn't look like a proper URL!")

	return
}

function tracker_match(alias, tfile)
{
	if (!alias)
		err("no alias specified")
	while ((getline < tfile) > 0) {
		if ($1 == alias && $2 == ":") {
			allt[0] = $3
			idx = 1
			while (getline < tfile) {
				if ($1 ~ /^\+$/) {
					allt[idx++] = $2
					continue
				} else if ($1 == ":") {
					err("first tracker already defined for alias `"alias"'")
				}
				break
			}
		}
	}

	close(tfile)
	return (!length(allt)) ? (tmerr ? err("tracker alias not found") : 1) : 0
}

function tracker_get_all(tfile)
{
	idx = 0
	while ((getline < tfile) > 0) {
		if ($1 == "+")
			everyt[idx++] = $2
		else if ($2 == ":")
			everyt[idx++] = $3
	}

	return
}

function tracker_match_other(alias, stlst, tfile)
{
	if (!tracker_match(alias, tfile))
		err("alias already defined")
	tracker_get_all(tfile)
	for (i in everyt) {
		tmpt = tolower(everyt[i])
		for (j in stlst) {
			if (tmpt == tolower(stlst[j]))
				err("tracker `" stlst[j] "' already defined")
		}
	}

	return 0
}

function tracker_add(alias, prim, sec, tfile)
{
	if (!alias || !prim || !sec)
		err("You entered an empty string!")
	if (sec == "_NULL") sec = 0
	tmparr[0] = prim
	tracker_is_valid(tmparr)
	if (sec) {
		split(sec, secarr)
		tracker_is_valid(secarr)
		for (i in secarr) {
			if (secarr[i] == prim)
				err("tracker `"prim"' entered more than once")
			# I don't believe {} is portable...
			if (sec ~ " *""("secarr[i]")"" *""("secarr[i]")"" *")
				err("tracker `"secarr[i]"' entered more than once")
		}
	}
	# since split idx starts at one, use 0 for
	# primary tracker
	secarr[0] = prim
	tracker_match_other(alias, secarr, tfile)
	delete secarr[0]
	print alias" : "prim >> tfile
	if (sec)
		for (i in secarr)
			printf "\t+ "secarr[i]"\n" >> tfile

	return 0
}

function tracker_seed_info()
{
	if (!$0) exit 1
	do {
		for (i in allt)
			if ($0 ~ "^  Magnet.*&tr=.*"allt[i]".*")
				printf "%s\n%s\n%s\n%s\n----\n", id, name, hash, $0
		if ($0 ~ /^[[:space:]]*Id:/)
			id = $0
		else if ($0 ~ /^[[:space:]]*Name:/)
			name = $0
		else if ($0 ~ /^[[:space:]]*Hash:/)
			hash = $0
	} while (getline)

	return 0
}

function tracker_seedul()
{
	if (!$0) exit 1
	ll = idx = 0
	do {
		for (i in allt) {
			if ($0 ~ "^  Magnet.*&tr=.*"allt[i]".*") {
				sub(/^[[:space:]]*/, "", name)
				if (length(name) > ll)
					ll = length(name)
				while (getline) {
					if ($0 ~ /^[[:space:]]*Upload Speed:/) {
						ul = $0
						break
					}
				}
				if (!ul) exit 1
				sub(/^[[:space:]]*/, "", ul)
				tsularr[idx++] = name ; tsularr[idx++] = ul
			}
		}
		if ($0 ~ /^[[:space:]]*Name:/)
			name = $0
	} while (getline)

	return 0
}

function seed_ulrate()
{
	if (!$0) exit 1
	ll = idx = 0
	do {
		if ($0 ~ /^[[:space:]]*Name/) {
			sularr[idx] = $0
			sub(/^[[:space:]]*/, "", sularr[idx])
			if (length(sularr[idx++]) > ll)
				ll = length(sularr[idx-1])
			# at current, the UL line is
			# ten lines below the Name line
			for (i = 0; i < 10; i++)
				getline
			sularr[idx] = $0
			sub(/^[[:space:]]*/, "", sularr[idx++])
		}
	} while (getline)

	return 0
}

function tracker_total()
{
	if (!$0) exit 1
	total = tmpnum = 0
	do {
		if ($0 ~ /None/) {
			continue
		} else if ($0 ~ /GB/) {
			tmpnum = $0
			sub(/GB/, "", tmpnum)
			tdn += tmpnum
		} else if ($0 ~ /MB/) {
			tmpnum = $0
			sub(/MB/, "", tmpnum)
			tdn += (tmpnum / 1000)
		} else if ($0 ~ /KB/) {
			tmpnum = $0
			sub(/KB/, "", tmpnum)
			tdn += (tmpnum / 1000000)
		}
	} while (getline)

	return 0
}

function tracker_total_hashop()
{
	if (op == "check") {
		do {
			if ($1 == hash)
				exit 1
		} while (getline)
		return 0
	} else if (op == "add") {
		do {
			if ($1 ~ /^Hash:/)
				print $2
		} while (getline)
	}

	return 0
}

function tracker_total_details()
{
	if (!$0) exit 1
	FS="  +"
	do {
		if ($2 ~ /^Magnet:/)
			for (i in allt)
				if ($2 ~ ".*&tr=.*"allt[i]".*")
					while (getline)
						if ($2 ~ /^Downloaded:/) {
							print $2 ; getline
							# get UL + Ratio lines
							for (j=0;j<2;j++) {
								print $2
								getline
							}
							break
						}
	} while(getline)
}

function dl_info()
{
	FS="  +"
	if (!$0) exit 1
	do {
		if ($2 ~ /^State: (Download)|(Up & Down)/) {
			printf "%s\n%s\n%s\n", name, id, $0
			while (getline) {
				if ($2 ~ /^(Percent Done:)|(ETA:)|(Download Speed:)|(Upload Speed:)|(Peers:)/)
					# leave leading spaces to make info clearer
					print $0
				else if ($1 ~ /^HISTORY/) {
					print "----"
					break
				}
			}
		} else if ($2 ~ /^Id:/) {
			id = $0
		} else if ($2 ~ /^Name:/) {
			name = $2
		}
	} while (getline)
}

function mv_torrent_location()
{
	do {
		if ($1 == "Id:") { id = $2 }
		if ($1 == "Location:") {
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
	} while (getline)
}

function show_tracker_errors()
{
	FS="  +"
	do {
		if ($2 ~ /^Name:/) {
			printf "%s\n%s\n", $2, id
		} else if ($2 ~ /^Id:/) {
			id = $0
		} else if ($2 ~ /^(Location:)|(Error:)/) {
			print $0
		}
	} while (getline)
}

{
	if (picked_tsi)
		tracker_seed_info()
	if (picked_sul)
		seed_ulrate()
	if (picked_tsul)
		tracker_seedul()
	if (picked_tt)
		tracker_total()
	if (picked_ttd)
		tracker_total_details()
	if (picked_tth)
		tracker_total_hashop()
	if (picked_dli)
		dl_info()
	if (picked_te)
		show_tracker_errors()
	if (picked_mtl)
		mv_torrent_location()
}

END {
	if (picked_sul) {
		for (i = 0; i < idx; i += 2) {
			ldiff = ll - length(sularr[i])
			for (j = 0; j < ldiff; j++)
				sularr[i] = sularr[i]" "
			printf "%s %s\n", sularr[i], sularr[i+1]
		}
	}
	if (picked_tsul) {
		for (i = 0; i < idx; i += 2) {
			ldiff = ll - length(tsularr[i])
			for (j = 0; j < ldiff; j++)
				tsularr[i] = tsularr[i]" "
			printf "%s %s\n", tsularr[i], tsularr[i+1]
		}
	}
	if (picked_tt) {
		if (!tdn) exit 1
		print "Total downloaded: " tdn " GB"
		print tdn" GB" >cachefile
	}
}
