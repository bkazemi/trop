# trop
## Introduction

trop is a shell script designed to make interaction with
transmission-remote easier. It started as a group of different
scripts I threw together to get specific information about
torrents that was not explicitly included as an option in
transmission-remote. My primary goal with this project is to
get information or do common tasks in tr-remote in a convient
way.

## Installing:

The recommended way to install trop is to use the \`install.sh'
script. The install script will install the trop files to the
path specified in the PREFIX environment variable. The default
path is \`~/.trop'.

If you prefer to install trop in a different
fashion, the only requirement is that all files distributed in
the release are kept in the same directory. Any other configuration
is not guaranteed to work.

## The `tracker' file

The tracker file is used to bind an alias to a set of bittorrent tracker
URLs. That way you can gather information about torrents specific to a tracker, or a
set of trackers.

Here is an example of an entry:
```
example : primary-tracker.example.org
	+ second-tracker.example.org
	+ third-tracker.example.com
```
The first word is the alias; The second word is the primary tracker. Both these entries
are required. The alias and all tracker entries must NOT contain any spaces. There must
be a space on both sides of the alias-primary tracker seperator (the colon).
Secondary tracker entries must contain a \`+' symbol as the first non-whitespace character,
followed by a space, then the tracker entry. There may not be more than one unique tracker URL entry
in any alias. Any number of secondary trackers may be specified. You may interactively add trackers
through the \`-ta' flag in trop.

## License

trop is licensed under the BSD2 Clause. See the LICENSE file for details.

## Contact

For any questions, comments, etc. Contact me at:

bkazemi@users.sf.net

If you would like to contribute code, email me a patch or open a pull-request.
