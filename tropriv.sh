#!/bin/sh

# private vars for user info

# set USERHOST to the default address to connect to
# transmission-remote's default is `localhost:9091'
#
# set AUTH to the user+pass used to authenticate the
# tr-remote connection. Leave blank if no
# authentication is used.

[ $huser -eq 0 ] && \
	# set here for default
	USERHOST='' ; export USERHOST
[ $auser -eq 0 ] && \
	# set here for default
	AUTH='' ; export AUTH

set_uah ()
{ USERHOST="$1" ; export USERHOST && return 0  || return 1 ;}

set_auth ()
{ AUTH="$1" ; export AUTH && return 0 || return 1 ;}

[ "$1" = 'seth' ] && set_uah "$2"
[ "$1" = 'seta' ] && set_auth "$2"

return 0
