#! /bin/bash
########################################
# This is an event handler for logging #
########################################

INFO="This is an event handler to log all stderr-output of Minecraft's
jar file."
EXAMPLE="Any line read will be added to the file specified in 
'$SERVER_LOG_FILE' in minelib."
MORE="This event handler is especially useful for server debugging 
and documentation of events on the server."

handle_event() {
	# Define default arguments
	EVENT="$1"
	SERVER_NAME="$2"

	# Source minelib
	source /usr/local/libexec/minectl/minelib 2> /dev/null || { echo "Could not load main library" 1>&2; exit 1; }

	minelib_access_server "$SERVER_NAME"

	echo "$EVENT" >> "$SERVER_LOG_FILE"
}

CMD=$1
shift 

case $CMD in
	handle)	handle_event "$1" "$2"
	;;
	info)	echo -e "\033[1m`basename $0` - INFORMATION\033[0m\n$INFO\n$EXAMPLE\n$MORE\n$INFO\n$EXAMPLE\n$MORE"
esac