#! /bin/bash
########################################
# This is an event handler for logging #
########################################

# Define default arguments
SERVER_NAME="$1"
EVENT="$2"

# Source minelib
source /usr/local/libexec/minectl/minelib 2> /dev/null || { echo "Could not load main library" 1>&2; exit 1; }

minelib_access_server "$SERVER_NAME"

echo "$EVENT" >> "$SERVER_LOG_FILE"
