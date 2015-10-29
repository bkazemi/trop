# current options include:
#   func=
#     ta   - run tracker_add
#
#     tm   - run tracker_match
#     tmo  - run tracker_match_other
#
#     tsi  - run tracker_seed_info
#
#     sul  - run seed_ulrate
#     tsul - run tracker_seed_ulrate
#
#     tt   - run tracker_total
#     ttd  - run tracker_total_details
#     tth  - run tracker_total_hashop
#
#     dli  - run dl_info
#     tdli - run tracker_dl_info
#
#     ste  - run show_tracker_errors
#
#     mtl  - run move_torrent_location
#     tmtl - run tracker_move_torrent_location

BEGIN {
	if (!length(ARGV[1])) exit
	if (!progname) progname = "trop.awk"
	tmerr = 0
	picked_tm  = picked_tsi  = picked_sul = picked_tsul = picked_tt = 0
	picked_tmo = picked_tns  = picked_dli = picked_tdli = picked_te = 0
	picked_mtl = picked_tmtl = 0
	for (i in ARGV)
		argv[i] = ARGV[i]
	delete ARGV
	for (i = 1; i < ARGC; i++) {
		if (argv[i] ~ /^func=/) {
			sub(/^func=/, "", argv[i])
			if (argv[i] == "tsi") {
				tmerr = picked_tsi = 1
				tracker_match(argv[i+1], argv[i+2])
				i += 2
			} else if (argv[i] == "tsul") {
				tmerr = picked_tsul = 1
				tracker_match(argv[i+1], argv[i+2])
				i += 2
			} else if (argv[i] == "tt") {
				tmerr = picked_tt = 1
				tracker_match(argv[i+1], argv[i+3])
				cachefile = argv[i+2]
				i += 3
			} else if (argv[i] == "ttd") {
				tmerr = picked_ttd = 1
				tracker_match(argv[i+1], argv[i+2])
				i += 2
			} else if (argv[i] == "tth") {
				picked_tth = 1
				c = 0
				if ((op = argv[i+1]) == "check") {
					c = 1
					hash = argv[i+2]
				}
				i += (c ? 2 : 1)
			} else if (argv[i] == "tmo") {
				tracker_match_other(argv[i+1], argv[i+2])
				i += 2
			} else if (argv[i] == "tm") {
				tmerr = 1
				exit(tracker_match(argv[i+1], argv[i+2]))
			} else if (argv[i] == "tns") {
				tmerr = picked_tns = 1
				tracker_match(argv[i+1], argv[i+2])
				i += 2
			} else if (argv[i] == "ta") {
				tracker_add(argv[i+1], argv[i+2], argv[i+3], argv[i+4])
				exit 0
			} else if (argv[i] ~ /mtl$/) {
				# common mv_tr_loc() stuff
				shift = 0
				if (argv[i] ~ /^t/) shift = 1
				prefix = argv[i+1+shift]
				newprefix = argv[i+2+shift]
				if (newprefix && newprefix !~ /\/$/)
					newprefix = newprefix"/"
				# `&' produces bizarre results without a backslash
				gsub(/\&/, "\\\\&", newprefix)
				if (argv[i] == "tmtl") {
					tmerr = picked_tmtl = 1
					tracker_match(argv[i+1], argv[i+4])
					i += 4
				} else {
					picked_mtl = 1
					i += 3
				}
			} else if (argv[i] == "sul") {
				picked_sul = 1
			} else if (argv[i] == "ste") {
				picked_te = 1
			} else if (argv[i] == "dli") {
				tmerr = picked_dli = 1
			} else if (argv[i] == "tdli") {
				tmerr = picked_tdli = 1
				tracker_match(argv[i+1], argv[i+2])
				i += 2
			} else {
				err("invalid function")
			}
		} else if (argv[i] == "-") {
			continue
		} else {
			err("invalid option `"argv[i]"'")
		}
	}
}

function err(msg)
{
	if (!silent)
		printf progname": " msg"\n" > "/dev/stderr"

	# drain stdin to prevent a broken pipe
	fflush()
	if ($0) while(getline);

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

function tracker_match_line()
{
	for (i in allt)
		if ($0 ~ "^[[:space:]]*Magnet.*&tr=.*"allt[i]".*")
			return 1

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
		if (tracker_match_line())
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

function tracker_seed_ulrate()
{
	if (!$0) exit 1
	ll = idx = 0
	do {
		if (tracker_match_line()) {
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
		} else if ($0 ~ /^[[:space:]]*Name:/) {
			name = $0
		}
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
			if (tracker_match_line())
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

function tracker_num_seed()
{
	if (!$0) exit 1
	tseeding = 0
	FS="  +"
	do {
		if ($2 ~ /^Magnet:/)
			if (tracker_match_line())
				while (getline)
					if ($2 ~ /^State:/) {
						if ($2 ~ /Seeding$/)
							tseeding++
						break
					}
	} while (getline)
}

function tracker_dl_info()
{
	if (!$0) exit 1
	FS="  +"
	do {
		if ($2 ~ /^Magnet:/) {
			if (tracker_match_line()) {
				while (getline) {
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
						break
					}
				}
			}
		} else if ($2 ~ /^Id:/) {
			id = $0
		} else if ($2 ~ /^Name:/) {
			name = $2
		}
	} while (getline)
}

function dl_info()
{
	if (!$0) exit 1
	FS="  +"
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

function tracker_mv_torrent_location()
{
	do {
		if (tracker_match_line()) {
			while (getline) {
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
					break
				}
			}
		} else if ($1 == "Id:") {
			id = $2
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
	if (picked_tns)
		tracker_num_seed()
	if (picked_tsi)
		tracker_seed_info()
	if (picked_sul)
		seed_ulrate()
	if (picked_tsul)
		tracker_seed_ulrate()
	if (picked_tt)
		tracker_total()
	if (picked_ttd)
		tracker_total_details()
	if (picked_tth)
		tracker_total_hashop()
	if (picked_dli)
		dl_info()
	if (picked_tdli)
		tracker_dl_info()
	if (picked_te)
		show_tracker_errors()
	if (picked_mtl)
		mv_torrent_location()
	if (picked_tmtl)
		tracker_mv_torrent_location()
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
	if (picked_tns) {
		if (tseeding)
			print tseeding
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
