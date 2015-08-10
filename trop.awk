#!/bin/env awk -f
#
# current options include:
#   func=
#     tsi - run tracker_seed_info function
#
BEGIN {
	if (!length(ARGV[1])) exit
	progname = ARGV[0]
	pickedtm = 0
	for (i = 1; i < ARGC; i++) {
		if (ARGV[i] ~ /^func=/) {
			if (ARGV[i] ~ /tsi$/) {
				pickedtsi = 1
				if (tracker_match(ARGV[i+1], ARGV[i+2]))
					exit 1
				delete ARGV[i] ; delete ARGV[i+1] ; delete ARGV[i+2]
				i += 2
			}
			else
				err("invalid function")
		} else if (ARGV[i] == "-") {
			continue
		} else {
			err("invalid option")
		}
	}
}

function err(msg)
{
	printf progname": " msg"\n" > "/dev/stderr"
	exit 1
}

function tracker_match(alias, tfile)
{
	if (!alias)
		err("no alias specified")
	while ((getline < tfile) > 0) {
		if ($1 ~ "^"alias"$" && $2 == ":") {
			allt[0] = $3
			idx = 1
			while (getline < tfile) {
				if ($1 ~ /^\+$/) {
					#print $2
					allt[idx++] = $2"\n"
					continue
				} else if ($1 == ":") {
					err("first tracker already defined for alias `"alias"'")
				}
				break
			}
		}
	}
	
	fflush(tfile)
	close(tfile) 
	return (!length(allt)) ? 1 : 0
}

function tracker_seed_info()
{
	do {
		if ($0 ~ "^  Magnet.*&tr=.*"allt[0]".*")
			printf "%s\n%s\n%s\n%s\n----\n", id, name, hash, $0
		else if ($0 ~ /^[[:space:]]*Id:/)
			id = $0
		else if ($0 ~ /^[[:space:]]*Name:/)
			name = $0
		else if ($0 ~ /^[[:space:]]*Hash:/)
			hash = $0
	} while (getline)
	
	return 0
}

{
	if (pickedtsi)
		tracker_seed_info()
}