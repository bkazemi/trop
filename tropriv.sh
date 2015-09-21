#!/bin/sh

# private vars for user info

[ $huser -eq 0 ] && \
	export USERHOST='' # set here for default
[ $auser -eq 0 ] && \
	export AUTH='' # set here for default

set_uah ()
{ export USERHOST="$1" && return 0  || return 1 ;}

set_auth ()
{ export AUTH="$1" && return 0 || return 1 ;} 

[ "$1" = 'seth' ] && set_uah "$2"
[ "$1" = 'seta' ] && set_auth "$2"

return 0
