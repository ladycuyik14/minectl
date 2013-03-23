#! /bin/bash
########################################################
# This is an event handler for local command execution #
########################################################

INFO="This event handler watches out for users saying something beginning with 
'%' and interprets the following characters as commands and their respective 
arguments, returning the stdout and stderr output to the respective user."
EXAMPLE="Example: If user says '%date +%s' this event will tell the respective user the
system's date in seconds since 1970."
MORE="The valid commands the users can execute are checked against a case switch 
inside this event handler up until now but may be outsourced to more extensive 
configuration files in the future."

# Handle the event
handle_event() {
	# Define default arguments
	EVENT="$1"
	SERVER_NAME="$2"

	# A line containing a user saying something beginning with 
	# '%' which indicates a command for this event handler.
	VALID_LINE="`echo "$EVENT" | cut --output-delimiter " " -d " " -f 4- | grep ^"<.*> %"`"

	# If we did not grep anything,
	# its probably nothing we should care of
	if [ -z "$VALID_LINE" ]; then
		exit 1
	fi

	# The name of the user, calling the command
	# In Minecraft's output, it's standing in between "<" and ">"
	USER_NAME="`echo "$VALID_LINE" | cut -d "<" -f 2 | cut -d ">" -f 1`"

	# The command line containing
	# %<command> [arguments]
	COMMAND_LINE="`echo "$VALID_LINE" | cut -d ">" -f 2- | cut -d "%" -f 2-`"

	# Decode valid commands
	decode_command() {
		# The first argument is the command itself
		# the further arguments may be arguments for the command
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
}

CMD=$1
shift 

case $CMD in
	handle)	handle_event "$1" "$2"
	;;
	info)	echo -e "\033[1m`basename $0 .eh` - INFORMATION\033[0m\n$INFO\n$EXAMPLE\n$MORE\n"
esac