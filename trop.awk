# current options include:
#   func=
#     tm   - run tracker_match function
#     tsi  - run tracker_seed_info function
#     sul  - run seed_ulrate function
#     tsul - run tracker_seedul function
#     tt   - run tracker_total function
#     ta   - run tracker_add function
#     dli  - run dl_info function
BEGIN {
	if (!length(ARGV[1])) exit
	if (!progname) progname = "trop.awk"
	tmerr = pickedtm = pickedtsi = pickedsul = pickedtsul = pickedtt = 0
	for (i = 1; i < ARGC; i++) {
		if (ARGV[i] ~ /^func=/) {
			if (ARGV[i] ~ /tsi$/) {
				tmerr = pickedtsi = 1
				tracker_match(ARGV[i+1], ARGV[i+2])
				delargs(i, i+=2)
			} else if (ARGV[i] ~ /tsul$/) {
				tmerr = pickedtsul = 1
				tracker_match(ARGV[i+1], ARGV[i+2])
				delargs(i, i+=2)
			} else if (ARGV[i] ~ /tt$/) {
				tmerr = pickedtt = 1
				tracker_match(ARGV[i+1], ARGV[i+2])
				cachefile = ARGV[i+3]
				delargs(i, i+=3)
			} else if (ARGV[i] ~ /tmo$/) {
				tracker_match_other(ARGV[i+1], ARGV[i+2])
				delargs(i, i+=2)
			} else if (ARGV[i] ~ /tm$/) {
				exit(tracker_match(ARGV[i+1], ARGV[i+2]))
			} else if (ARGV[i] ~ /ta$/) {
				tracker_add(ARGV[i+1], ARGV[i+2], ARGV[i+3], ARGV[i+4])
				delargs(i, i+=4)
				exit 0
			} else if (ARGV[i] ~ /sul$/) {
				pickedsul = 1
				delete ARGV[i]
			} else if (ARGV[i] ~ /dli$/) {
				tmerr = pickeddli = 1
				delete ARGV[i]
			} else {
				err("invalid function")
			}
		} else if (ARGV[i] == "-") {
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

function tracker_match_other(alias, tfile, stlst)
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

function tracker_add(alias, tfile, prim, sec)
{
	if (!alias || !prim || !sec)
		err("You entered an empty string!")
	split(sec, secarr)
	for (i in secarr) {
		if (secarr[i] == prim)
			err("tracker `"prim"' entered more than once")
		# I don't believe {} is portable...
		if (sec ~ " *""("secarr[i]")"" *""("secarr[i]")"" *")
			err("tracker `"secarr[i]"' entered more than once")
	}
	# since split idx starts at one, use 0 for
	# primary tracker
	secarr[0] = prim
	tracker_match_other(alias, tfile, secarr)
	delete secarr[0]
	print alias" : "prim >> tfile
	if (sec != "NULL")
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

function dl_info()
{
	FS="  +"
	if (!$0) exit 1
	do {
		if ($2 ~ /^State: (Download)|(Up & Down)/) {
			print name
			print id
			print $0
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

{
	if (pickedtsi)
		tracker_seed_info()
	if (pickedsul)
		seed_ulrate()
	if (pickedtsul)
		tracker_seedul()
	if (pickedtt)
		tracker_total()
	if (pickeddli)
		dl_info()
}

END {
	if (pickedsul) {
		for (i = 0; i < idx; i += 2) {
			ldiff = ll - length(sularr[i])
			for (j = 0; j < ldiff; j++)
				sularr[i] = sularr[i]" "
			printf "%s %s\n", sularr[i], sularr[i+1]
		}
	}
	if (pickedtsul) {
		for (i = 0; i < idx; i += 2) {
			ldiff = ll - length(tsularr[i])
			for (j = 0; j < ldiff; j++)
				tsularr[i] = tsularr[i]" "
			printf "%s %s\n", tsularr[i], tsularr[i+1]
		}
	}
	if (pickedtt) {
		if (!tdn) exit 1
		print "Total downloaded: " tdn " GB"
		print tdn" GB" >cachefile
	}
}
