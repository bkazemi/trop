# current options include:
#   func=
#     ta   - run tracker_add
#
#     tl   - list trackers under an alias
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
	tmerr = 1
	picked_tm  = picked_tsi  = picked_sul = picked_tsul = picked_tt = 0
	picked_tmo = picked_tns  = picked_dli = picked_tdli = picked_te = 0
	picked_mtl = picked_tmtl = 0
	# delete ARGV array to prevent
	# awk from taking arguments as
	# input files
	for (i in ARGV)
		argv[i] = ARGV[i]
	delete ARGV
	for (i = 1; i < ARGC; i++) {
		if (argv[i] ~ /^func=/) {
			sub(/^func=/, "", argv[i])
			if (argv[i] == "tsi") {
				picked_tsi = 1
				tracker_match(argv[i+1], argv[i+2])
				i += 2
			} else if (argv[i] == "tsul") {
				picked_tsul = 1
				tracker_match(argv[i+1], argv[i+2])
				i += 2
			} else if (argv[i] == "tt") {
				picked_tt = 1
				tracker_match(argv[i+1], argv[i+3])
				cachefile = argv[i+2]
				i += 3
			} else if (argv[i] == "ttd") {
				picked_ttd = 1
				tracker_match(argv[i+1], argv[i+2])
				i += 2
			} else if (argv[i] == "tth") {
				picked_tth = 1
				c = 0
				if ((op = argv[i+1]) == "check") {
					c = 1
					hash = argv[i+2]
					hashfile = argv[i+3]
				}
				i += (c ? 3 : 2)
			} else if (argv[i] == "tmo") {
				tmerr = 0
				tracker_match_other(argv[i+1], argv[i+2])
				i += 2
			} else if (argv[i] == "tm") {
				exit(tracker_match(argv[i+1], argv[i+2]))
			} else if (argv[i] == "tns") {
				picked_tns = 1
				tracker_match(argv[i+1], argv[i+2])
				i += 2
			} else if (argv[i] == "ta") {
				tmerr = 0
				tracker_add(argv[i+1], argv[i+2], argv[i+3], argv[i+4])
				exit 0
			} else if (argv[i] == "tl") {
				if (ARGC != 4) {
					while ((getline < argv[i+1]) > 0)
						if ($1 !~ /^#/)
							print $0
				} else {
					tracker_match(argv[i+1], argv[i+2])
					printf "%s : %s\n", argv[i+1], all_trackers[0]
					for (i = 1; i < length(all_trackers); i++)
						printf "\t+ %s\n", all_trackers[i]
				}
				i += 2
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
					picked_tmtl = 1
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
				picked_dli = 1
			} else if (argv[i] == "tdli") {
				picked_tdli = 1
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

function assert(expr_is_false, msg)
{
	if (!expr_is_false)
		err("assert(): FAILURE" (msg ? ": "msg : ""))

	return 0
}

function err(msg)
{
	if (!silent)
		print progname":", msg > "/dev/stderr"

	# drain stdin to prevent a broken pipe
	fflush()
	if ($0) while(getline);

	exit err_exit = 1
}

function all_ascii(str)
{
	return str !~ /[^[:alnum:][:space:][\]~`!@#$%^&*()_+-={}\/\\|;:'",.<>?]/
}

function get_non_ascii(str)
{
	gsub(/[[:alnum:][:space:][\]~`!@#$%^&*()_+-={}\/\\|;:'",.<>?]/, "", str)
	return str
}

function kb_conv(kb)
{
	# convert to int
	kb = int(kb) / 1
	if (kb >= 1e9) {
		kb = (kb / 1e9)" TB\/s"
	} else if (kb >= 1e6) {
		kb = (kb / 1e6)" GB\/s"
	} else if (kb >= 1e3) {
		kb = (kb / 1e3)" MB\/s"
	} else {
		kb = kb" kB/s"
	}

	return kb
}

function tracker_is_valid(trackerarr)
{
	for (i in trackerarr)
		if (trackerarr[i] !~ /^([[:alnum:]]+:\/\/)?([[:alnum:]]+\.[[:alpha:]]+)+$/)
			err("`"trackerarr[i]"' doesn't look like a proper URL!")

	return
}

function tracker_match(alias, tracker_file)
{
	assert(alias, "no alias specified")
	while ((getline < tracker_file) > 0) {
		if ($1 == alias && $2 == ":") {
			all_trackers[0] = $3
			idx = 1
			while (getline < tracker_file) {
				if ($1 ~ /^\+$/) {
					all_trackers[idx++] = $2
					continue
				} else if ($1 == ":") {
					err("first tracker already defined for alias `"alias"'")
				}
				break
			}
		}
	}
	savei = i
	tracker_is_valid(all_trackers)
	i = savei

	close(tracker_file)
	return (!length(all_trackers)) ? (tmerr ? err("tracker alias not found") : 1) : 0
}

function tracker_get_all(tracker_file)
{
	idx = 0
	while ((getline < tracker_file) > 0) {
		if ($1 == "+")
			every_tracker[idx++] = $2
		else if ($2 == ":")
			every_tracker[idx++] = $3
	}

	return
}

function tracker_match_other(alias, secondary_tracker_list, tracker_file)
{
	if (!tracker_match(alias, tracker_file))
		err("alias already defined")
	tracker_get_all(tracker_file)
	for (i in every_tracker) {
		tmp_tracker = tolower(every_tracker[i])
		for (j in secondary_tracker_list) {
			if (tmp_tracker == tolower(secondary_tracker_list[j]))
				err("tracker `" secondary_tracker_list[j] "' already defined")
		}
	}

	return 0
}

function tracker_match_line()
{
	for (i in all_trackers)
		if ($0 ~ "^[[:space:]]*Magnet.*&tr=.*"all_trackers[i]".*")
			return 1

	return 0
}

function tracker_add(alias, primary_tracker, secondary_trackers, tracker_file)
{
	assert((alias && primary_tracker && secondary_trackers), "You entered an empty string!")
	if (alias ~ /^[+#]/)
		err("alias cannot start with `"substr(alias, 1, 1)"'")
	if (secondary_trackers == "_NULL")
		secondary_trackers = 0
	tmparr[0] = primary_tracker
	# check if tracker format is valid
	tracker_is_valid(tmparr)
	if (secondary_trackers) {
		split(secondary_trackers, secarr)
		tracker_is_valid(secarr)
		for (i in secarr) {
			if (secarr[i] == primary_tracker)
				err("tracker `"primary_tracker"' entered more than once")
			# I don't believe {} is portable...
			if (secondary_trackers ~ " *""("secarr[i]")"" *""("secarr[i]")"" *")
				err("tracker `"secarr[i]"' entered more than once")
		}
	}
	# since split idx starts at one, use 0 for
	# primary tracker
	secarr[0] = primary_tracker
	tracker_match_other(alias, secarr, tracker_file)
	delete secarr[0]
	print alias, ":", primary_tracker >> tracker_file
	if (secondary_trackers)
		for (i in secarr)
			printf "\t+ %s\n", secarr[i] >> tracker_file

	return 0
}

function tracker_seed_info()
{
	assert($0, "no input")
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
	assert($0, "no input")
	longest_name = idx = total = 0
	do {
		if (tracker_match_line()) {
			sub(/^[[:space:]]*Name: */, "", name)
			namelen = length(name) - (all_ascii(name) ? 0 : length(get_non_ascii(name)))
			if (namelen > longest_name)
				longest_name = namelen
			while (getline) {
				if ($0 ~ /^[[:space:]]*Upload Speed:/) {
					ul = $0
					if ($4 == "TB/s")
						total += ($3 * 1e9)
					else if ($4 == "GB/s")
						total += ($3 * 1e6)
					else if ($4 == "MB/s")
						total += ($3 * 1e3)
					else
						total += ($3 / 1)
					break
				}
			}
			if (!ul) exit 1
			sub(/^[[:space:]]*Upload Speed: */, "", ul)
			tsularr[idx++] = name ; tsularr[idx++] = namelen
			tsularr[idx++] = ul
		} else if ($0 ~ /^[[:space:]]*Name:/) {
			name = $0
		}
	} while (getline)

	return 0
}

function seed_ulrate()
{
	assert($0, "no input")
	longest_name = idx = total = 0
	FS = "  +"
	do {
		sub(/^[[:space:]]*/, "")
		if ($8 == "Seeding") {
			name = $9 # name field
			if (NF >= 10 && $10 != "") {
				name = substr($0, match($0, /Seeding/))
				sub(/^Seeding         /, "", name)
				sub(/[[:space:]]*$/, "", name)
			}
			sularr[idx++] = name
			assert(name, "BUG: couldn't get name")
			namelen = length(name) - (all_ascii(name) ? 0 : length(get_non_ascii(name)))
			sularr[idx++] = namelen
			if (namelen > longest_name)
				longest_name = namelen
			total += sularr[idx++] = $5 # ul speed field
		}
	} while (getline)

	return 0
}

function tracker_total()
{
	assert($0, "No input. Probably no downloaded files found for this alias.")
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
			tdn += (tmpnum / 1e3)
		} else if ($0 ~ /KB/) {
			tmpnum = $0
			sub(/KB/, "", tmpnum)
			tdn += (tmpnum / 1e6)
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
		} while (getline < hashfile)
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
	assert($0, "no input")
	FS = "  +"
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
	assert($0, "no input")
	tseeding = 0
	FS = "  +"
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
	assert($0, "no input")
	FS = "  +"
	do {
		if ($2 ~ /^Magnet:/) {
			if (tracker_match_line()) {
				while (getline) {
					if ($2 ~ /^State: (Download|Up & Down)/) {
						printf "%s\n%s\n%s\n", name, id, $0
						while (getline) {
							if ($2 ~ /^(Percent Done|ETA|Download Speed|Upload Speed|Peers):/)
								# leave leading spaces to make info clearer
								print $0
							else if ($1 ~ /^HISTORY/) {
								print "----"
								break
							}
						}
						break
					} else if ($2 ~ /^State: /) {
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
	assert($0, "no input")
	FS = "  +"
	do {
		if ($2 ~ /^State: (Download|Up & Down)/) {
			printf "%s\n%s\n%s\n", name, id, $0
			while (getline) {
				if ($2 ~ /^(Percent Done|ETA|Download Speed|Upload Speed|Peers):/)
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
	FS = "  +"
	do {
		if ($2 ~ /^Name:/) {
			printf "%s\n%s\n", $2, id
		} else if ($2 ~ /^Id:/) {
			id = $0
		} else if ($2 ~ /^(Location|Error|Tracker gave an error):/) {
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
	if (err_exit) exit 1
	if (picked_sul || picked_tsul) {
		if (!longest_name) exit 0 # nothing seeding
		CONVFMT = "%.2f"
		name_id_line = "Name"
		for (i = 0; i < longest_name - 4; i++)
			name_id_line = name_id_line" "
		print name_id_line, "Upload Speed"
		if (picked_sul) {
			for (i = 0; i < idx; i += 3) {
				namediff = longest_name - sularr[i+1]
				for (j = 0; j < namediff; j++)
					sularr[i] = sularr[i]" "
				printf "%s %s\n", sularr[i], kb_conv(sularr[i+2])
			}
		} else {
			for (i = 0; i < idx; i += 3) {
				namediff = longest_name - tsularr[i+1]
				for (j = 0; j < namediff; j++)
					tsularr[i] = tsularr[i]" "
				printf "%s %s\n", tsularr[i], tsularr[i+2]
			}
		}
		sub(/\..*/, "", total) # remove fractional part
		total_line = "Total: "
		for (i = 0; i < longest_name - 7; i++)
			total_line = total_line" "
		printf "\n%s %s\n", total_line, kb_conv(total)
	}
	if (picked_tns) {
		if (tseeding)
			print tseeding
	}
	if (picked_tt) {
		assert(tdn, "no downloaded files detected")
		print "Total downloaded:", tdn, "GB"
		print tdn, "GB" >cachefile
	}
}
# vim: ft=awk:ts=4:sw=4
