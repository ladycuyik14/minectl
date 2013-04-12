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
	PLAYER_NAME="`echo "$VALID_LINE" | cut -d "<" -f 2 | cut -d ">" -f 1`"

	# The command line containing
	# %<command> [arguments]
	COMMAND_LINE="`echo "$VALID_LINE" | cut -d ">" -f 2- | cut -d "%" -f 2-`"
		
	# Execute valid commands
	execute_command() {
		# The first argument is the command itself
		# the further arguments may be arguments for the command
		CMD="$1"
		shift
		
		# Results file
		local TMP_RESULT="`mktemp`"
		
		# Check if the user is an admin
		is_admin() {
			if ( /usr/local/bin/minectl $SERVER_NAME passwd is-op "$PLAYER_NAME" ); then
				return 0
			else
				/usr/local/bin/minectl $SERVER_NAME exec say "Player $PLAYER_NAME tried to play admin."
				/usr/local/bin/minectl $SERVER_NAME exec tell "$PLAYER_NAME" "Fool! May the creeper get you!" 
			fi
			
			return 1
		}

		tell_result() {
			if [ -f "$TMP_RESULT" ]; then				
				while read LINE; do
					/usr/local/bin/minectl "$SERVER_NAME" tell "$PLAYER_NAME" "$LINE"
				done < "$TMP_RESULT"
			
				rm -f "$TMP_RESULT" 2> /dev/null
			fi
		}
		
		# Switch known commands
		case $CMD in
			""|help)	echo -e "Usage: %<command> [arguments]\nValid commands are: date, uname, uptime, admininfo" > "$TMP_RESULT" 2>&1
			;;
			date)		date "$@" > "$TMP_RESULT" 2>&1
			;;
			uname)		uname "$@" > "$TMP_RESULT" 2>&1
			;;
			uptime)		uptime "$@" > "$TMP_RESULT" 2>&1
			;;
			admininfo)	echo -e "Administrator of this server is: <ADMIN_NAME>" > "$TMP_RESULT" 2>&1
			;;
			backup)		# Check if user is operator
						if ( is_admin "$PLAYER_NAME" ); then
							/usr/local/bin/minectl $SERVER_NAME exec say "Operator $PLAYER_NAME called for a backup of the server" 
							/usr/local/bin/minectl $SERVER_NAME backup -m "Creating a backup of the server..." -p "...done"
						fi
			;;
			*)		echo "Unknown command: $CMD $@" 1>&2
					return 1
		esac
		
		tell_result
	}
	
	# Execute the command line
	execute_command $COMMAND_LINE
}

CMD=$1
shift 

case $CMD in
	handle)	handle_event "$1" "$2"
	;;
	info)	echo -e "\033[1m`basename $0 .eh` - INFORMATION\033[0m\n$INFO\n$EXAMPLE\n$MORE\n"
esac
