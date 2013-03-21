#! /bin/bash
########################################
# This is an event handler for logging #
########################################

# Define default arguments
SERVER_NAME="$1"
EVENT="$2"

# Source minelib
source /usr/local/libexec/minectl/minelib 2> /dev/null || { echo "Could not load main library" 1>&2; exit 1; }

# Access the server
minelib_access_server "$SERVER_NAME"

# A line containing a user saying something beginning with 
# '%' which indicates a command for this event handler.
VALID_LINE="`echo "$EVENT" | cut --output-delimiter " " -d " " -f 4- | grep ^"<.*> %"`"

# The name of the user, calling the command
USER_NAME="`echo "$VALID_LINE" | cut -d "<" -f 2 | cut -d ">" -f 1`"

# The command line containing
# %<command> [arguments]
COMMAND_LINE="`echo "$VALID_LINE" | cut -d ">" -f 2- | cut -d "%" -f 2-`"

# If we did not grep anything,
# its probably nothing we should care of
if [ -z "$VALID_LINE" ]; then
	exit 1
fi

# Decode valid commands
decode_command() {
	# The first argument is the command itself
	# the rest might be arguments
	CMD="$1"
	shift

	# Switch known commands
	case $CMD in
		"")		echo -e "Usage: %<command> [arguments]\nValid commands are: date, uname, uptime, admininfo"
		;;
		date)		date "$@"
		;;
		uname)		uname "$@"
		;;
		uptime)		uptime "$@"
		;;
		admininfo)	echo -e "Administrator of this server is: coNQP\na.k.a. Richard Neumann\nMelanchthonstraße 7\n30165 Hannover"
		;;
		*)		echo "Unknown command: $CMD $@" 1>&2
				return 1
	esac
}

tell_result() {
	local TMP_FILE="`mktemp`"

	# Decode command and sore 
	# answer in temporary file
	decode_command $COMMAND_LINE > "$TMP_FILE" 2>&1

	while read LINE; do
		"$BIN_DIR"/minectl "$SERVER_NAME" tell "$USER_NAME" "$LINE"
	done < "$TMP_FILE"
	
	rm -f "$TMP_FILE" 2> /dev/null
}

tell_result
