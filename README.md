# trop
## Introduction

trop is a shell script designed to make interaction with
transmission-remote easier. It features options to get
information about tr-remote torrents by seeding torrents
or by a specific set of tracker URLs. This project aims to
provide information from transmission-remote to the user
in a clean way, and make doing common tasks more automatic,
interchangeably through command-line or scripts. The code
is written to be as POSIX compliant as possible.

## Installing

The recommended way to install trop is to use the \`install.sh'
script. The install script will install the trop files to the
path specified in the PREFIX environment variable. The default
path is \`~/.trop'.

If you prefer to install trop in a different
fashion, the only requirement is that all files distributed in
the release are kept in the same directory. Any other configuration
is not guaranteed to work.

## Updating

Starting with trop 1.4.0, you can update the core files through install.sh by supplying
\`up' or \`update' as an argument.
Starting with trop 1.6.0, install.sh will also check user modifiable files for updates.
However, trop.conf _did_ change in v1.6 but cannot be checked as the checksum is cached
for the first time in this update. **Please update manually!**

## Storing tr-remote authentication information

To save a default host and/or user:pass combination, the tropriv.sh file was created.
To save the host information, open tropriv.sh and enter the default you'd like to use in
the HOSTPORT variable like so:
```
HOSTPORT='example.org:1234' # set here for default
```
And likewise for the user:pass (-n switch in tr-remote)
```
AUTH='bob:secretpass' # set here for default
```

## The \`tracker' file

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
are required. The alias and all tracker entries must _not_ contain any spaces. There must
be a space on both sides of the alias-primary tracker separator (the colon). The alias may
_not_ start with \`+' or \`#'. Secondary tracker entries must contain a \`+' symbol as the
first non-whitespace character, followed by a space, then the tracker entry. There may not
be more than one unique tracker URL entry in any alias. Any number of secondary trackers
may be specified. You may interactively add trackers through the \`-ta' flag in trop.

## trop.conf - Configuration

trop.conf is used to set default actions upon trop initialization. This file is simply a shell script
with variables that trop sources to get defaults. Each variable is commented in trop.conf to show what
it is used for.

## Setting up trop upon login

In order to use certain features, trop must be called with the -startup flag once when logging in.
Where to add this depends on your login shell. For Bourne-like shells this would be \`~/.profile';
In Zsh, it is \`~/.zprofile'. Typically you would look for your default shell in /etc/passwd.
Once you've found out your login shell, add this to the login script:
```sh
hash trop 2>&- && trop -q -startup >/dev/null
```

## License

trop is licensed under the BSD2 Clause. See the LICENSE file for details.

## Contact

For any questions, comments, etc. Contact me at:

bkazemi@users.sf.net

If you would like to contribute code, email me a patch or open a pull-request.
