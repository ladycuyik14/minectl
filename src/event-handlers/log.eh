#! /bin/bash
########################################
# This is an event handler for logging #
########################################

# Define default arguments
SERVER_NAME="$1"
EVENT="$2"

# Source minelib
source /usr/local/libexec/minelib

LOG_FILE="$SERVERS_DIR/$SERVER_NAME/mcsrv.log"

echo "$EVENT" >> $LOG_FILE
