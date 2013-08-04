#! /bin/bash

#############################
# Minecraft server commands #
#############################

require srvmgr

#####################
# Private functions #
#####################

# Send commands to server and print results
_srvexec_execute() {
	local SERVER_NAME="$1"
	shift

	access_server "$SERVER_NAME"

	# Per default, we don't want to see the verbose output
	local VERBOSE=false
	local SHOW_TAIL=false
	local WAIT_TIME=0.1
	local CLEAN=true

	# Switch options
	while (( $# )); do
		case $1 in
			--verbose|-v)	VERBOSE=true
					shift
			;;
			--show-tail|-s)	SHOW_TAIL=true
					shift
			;;
			--wait-time|-w)	WAIT_TIME=$2
					shift 2
			;;
			--no-clean|-n)	CLEAN=false
					shift 2
			;;
			*)		break
		esac
	done

	# Execute a Java command on the server
	_srvexec_execute_cmd() {
		access_server "$SERVER_NAME"

		if ( status > /dev/null 2> /dev/null ); then
			# Push command into server's stdin pipe
			echo "$@" > $SERVER_STDIN 2> /dev/null || print --fail EXEC_CMD_FAILED
		else
			print --fail SRV_NOT_RUNNING
		fi
	}

	# If cleaning is enabled, perform an empty query first
	if ( $CLEAN ); then
		# If SHOW_TAIL is enabled, print the recent output
		if ( $SHOW_TAIL ); then
			_srvexec_execute_cmd " "
		# Else, discard the output
		else
			_srvexec_execute_cmd " " 2> /dev/null
		fi
	fi

	# If verbose information is wanted, also
	# do not cut off timestamps and info fields
	if ( $VERBOSE ); then
		_srvexec_execute_cmd "$@"
	else 
		_srvexec_execute_cmd "$@" | cut -d " " -f 4-
	fi
}

# List players that are logged in
# Return 0 iff there are players on the server
# or 1 else
_srvexec_players() {
	local SERVER_NAME="$1"
	shift

	access_server "$SERVER_NAME"

	local TMP_PLAYERS="`mktemp`"
	local RETVAL=1

	_srvexec_execute list | tail -n +2 > $TMP_PLAYERS 2> /dev/null

	if [ -n "$(cat $TMP_PLAYERS)" ]; then
		cat "$TMP_PLAYERS"
		RETVAL=0
	else
		print NO_PLAYERS
	fi
	
	rm -f "$TMP_PLAYERS" 2> /dev/null 
	return $RETVAL	
}

# Display count of players logged in
# Return 0 iff there are players on the server
# or 1 else
_srvexec_player_count()  {
	local SERVER_NAME="$1"
	shift

	access_server "$SERVER_NAME"

	local TMP_PLAYERS="$(mktemp)"
	local RETVAL=1
	
	if ( _srvexec_players > /dev/null 2>&1 ); then
		_srvexec_players | head -n 1 | awk '{ print $3 }' | cut -d "/" -f 1 > $TMP_PLAYERS 2> /dev/null
		PLAYERS=`cat $TMP_PLAYERS`
		RETVAL=0
	else
		echo 0
	fi
	
	rm -f "$TMP_PLAYERS" 2> /dev/null
	return $RETVAL
}

####################
# Public functions #
####################

execute() {
	_srvexec_execute "$@"
}

players() {
	_srvexec_players "$@"
}

player_count()  {
	_srvexec_player_count "$@"
}

############
# Commands #
############

mc_execute() {
	_srvexec_execute "$@"
}

mc_players() {
	_srvexec_players "$@"
}
