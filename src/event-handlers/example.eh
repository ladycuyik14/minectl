#! /bin/bash

# This is a sample event handler
#
# - All event handlers must be executable binaries or scripts
# - All event handlers need to accept the following arguments:
#	event_handler_bin <server_name> <event>
##############################################################################

# Define default arguments
SERVER_NAME="$1"
EVENT="$2"

if [ "`echo "$EVENT" | awk '{ print $5 }'`" == "eventtest" ]; then
	/usr/local/bin/minectl $SERVER_NAME exec say "Event successfully tested on server $SERVER_NAME"
fi
