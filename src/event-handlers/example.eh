#! /bin/bash

# This is a sample event handler
#
# - All event handlers must be executable binaries or scripts
# - All event handlers need to accept the following arguments:
#	event_handler_bin handle <event> <server_name>	
#		To handle the event <event> on server <server_name>
#	event_handler_bin info
#		To print useful information about the event handler
##############################################################################

INFO="This is an example of an event handler to show how 
minectl's event system works."
EXAMPLE="If a user on the respective server says 'eventtest',
the event handler will tell the user that the event has been 
successfully tested."
MORE="This event handler is purposed for testing only as it has no deeper sense."

# Handle an event
handle_event() {
	# Define default arguments
	EVENT="$1"
	SERVER_NAME="$2"

	if [ "`echo "$EVENT" | awk '{ print $5 }'`" == "eventtest" ]; then
		/usr/local/bin/minectl $SERVER_NAME exec say "Event successfully tested on server $SERVER_NAME"
	fi
}

CMD=$1
shift

case $CMD in
	handle)	handle_event "$1" "$2"
	;;
	info)	echo -e "\033[1m`basename $0` - INFORMATION\033[0m\n$INFO\n$EXAMPLE\n$MORE\n$INFO\n$EXAMPLE\n$MORE"
esac