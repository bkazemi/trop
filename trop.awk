#!/bin/env awk -f
#
# current options include:
#   func=
#     tsi - run tracker_seed_info function
#
BEGIN {
	if (!length(ARGV[1])) exit
	progname = ARGV[0]
	pickedtm = pickedsul = 0
	for (i = 1; i < ARGC; i++) {
		if (ARGV[i] ~ /^func=/) {
			if (ARGV[i] ~ /tsi$/) {
				if (tracker_match(ARGV[i+1], ARGV[i+2]))
					exit 1
				pickedtsi = 1
				delete ARGV[i] ; delete ARGV[i+1] ; delete ARGV[i+2]
				i += 2
			} else if (ARGV[i] ~ /tsul$/) {
				if (tracker_match(ARGV[i+1], ARGV[i+2]))
					exit 1
				pickedtsul = 1
				delete ARGV[i] ; delete ARGV[i+1] ; delete ARGV[i+2]
				i += 2
			} else if (ARGV[i] ~ /sul$/) {
				pickedsul = 1
				delete ARGV[i]
			} else {
				err("invalid function")
			}
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

function tracker_seedul()
{
	idx = ll = 0
	do {
		if ($0 ~ "^  Magnet.*&tr=.*"allt[0]".*") {
			sub(/^[[:space:]]*/, "", name)
			if (length(name) > ll)
				ll = length(name)
			if (!ul) {
				while (getline) {
					if ($0 ~ /^[[:space:]]*Upload Speed:/) {
						ul = $0
						break
					}
				}
			}
			if (!ul) exit 1
			sub(/^[[:space:]]*/, "", ul)
			tsularr[idx++] = name ; tsularr[idx++] = ul
		} else if ($0 ~ /^[[:space:]]*Name:/) {
			name = $0
		} else if ($0 ~ /^[[:space:]]*Upload Speed:/) {
			ul = $0
		}
	} while (getline)
}

function seed_ulrate()
{
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
}

{
	if (pickedtsi)
		tracker_seed_info()
	if (pickedsul)
		seed_ulrate()
	if (pickedtsul)
		tracker_seedul()
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
}
