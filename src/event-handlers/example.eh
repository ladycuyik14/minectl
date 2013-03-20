#! /bin/bash

# This is a sample event handler
#
# - All event handlers must be executable binaries or scripts
# - All event handlers need to accept the following arguments:
#	event_handler_bin <server_name> <event>
# - All event handlers must return the following exit codes
#	0	The event has been successfully handled
#	1	The event handler is not responsible for the event
# 	2	There was an error handling the event
#	3	Order the event monitor to stop monitoring (use with CAUTION!)
##############################################################################

# Define default arguments
SERVER_NAME="$1"
EVENT="$2"

if [ "`echo "$EVENT" | awk '{ print $5 }'`" == "eventtest" ]; then
	/usr/local/bin/minectl $SERVER_NAME exec say "Event successfully tested"
	
	# XXX: Don't forget to return properly...
	exit 0
else
	# XXX: ... in any case!
	exit 1
fi
