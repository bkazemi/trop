#!/bin/sh

# private vars for user info

# set HOSTPORT to the default address to connect to
# transmission-remote's default is `localhost:9091'
#
# set AUTH to the user+pass used to authenticate the
# tr-remote connection. Leave blank if no
# authentication is used.

[ $huser -eq 0 ] && \
	# set here for default
	{ HOSTPORT='' ; export HOSTPORT ;}
[ $auser -eq 0 ] && \
	# set here for default
	{ AUTH='' ; export AUTH ;}

set_hp ()
{ HOSTPORT="$1" ; export HOSTPORT ; return $? ;}

set_auth ()
{ AUTH="$1" ; export AUTH ; return $? ;}

[ "$1" = 'sethp' ] && set_hp "$2"
[ "$1" = 'seta' ] && set_auth "$2"

return 0
# vim: ft=sh:ts=4:sw=4
