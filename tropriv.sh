#!/bin/sh

# private vars for user info

if [ "$huser" = 0 ]; then
	export USERHOST='' # set here for default
fi
if [ "$auser" = 0 ]; then
	export AUTH='' # set here for default
fi

set_uah ()
{ export USERHOST="$1" && return 0  || return 1 ;}

set_auth ()
{ export AUTH="$1" && return 0 || return 1 ;} 

if [ "$1" = 'seth' ]; then
	set_uah "$2"
fi
if [ "$1" = 'seta' ]; then
	set_auth "$2"
fi

return 0
