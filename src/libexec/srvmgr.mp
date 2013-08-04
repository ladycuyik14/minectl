#! /bin/bash

require jarmgr

#####################
# Private functions #
#####################

# Determine status of server
_srvmgr_status() {
	local SERVER_NAME="$1"
	shift

	if [ -f "/lib/systemd/system/minecraft@.service" ]; then
		/usr/bin/systemctl status minecraft@$SERVER_NAME.service
	elif [ -f "/etc/init.d/minecraft" ]; then
		/etc/init.d/minecraft status "$SERVER_NAME" 
	else
		minelib_fail DETERMINE_STATUS_FAILED
	fi
}

# Create named pipes
_srvmgr_mk_fifos() {
        for FIFO in $SERVER_STDIN $SERVER_STDOUT $SERVER_STDERR $SERVER_EVENT_QUEUE; do
                if [ -e $FIFO ]; then
                        if [ ! -p $FIFO ]; then
                                print --fail file_blocking_pipe
                        fi
                else
                        mkfifo $FIFO
                fi
        done
}

# Get a list of ports that are in use
_srvmgr_ports_in_use() {
	local PORTS_IN_USE=""
	
	for SERVER in $(_srvmgr_list); do
		PORTS_IN_USE="$PORTS_IN_USE $(_srvmgr_configure $SERVER 2> /dev/null | grep -E "^[[:blank:]]*server-port=" 2> /dev/null | cut -d "=" -f 2> /dev/null)"
	done
	
	echo "$PORTS_IN_USE"
}

# Find a port not used by any existing server
_srvmgr_get_free_port() {
	local PORT=25565
	
	for PORT_IN_USE in $(_srvmgr_ports_in_use); do
		if [ $PORT -eq $PORT_IN_USE ]; then
			let PORT++
		else
			break
		fi
	done
	
	echo "$PORT"
}

# Set the server's configuration defaults
_srvmgr_server_defaults() {
	# Default server port
	local SERVER_PORT=$(_srvmgr_get_free_port)
	
	_srvmgr_properties "server-port=$SERVER_PORT" > /dev/null
}

# Add a server
_srvmgr_add() {
	local SERVER_NAME="$1"
	shift

	# JAR file to be used
	local JAR_FILE=
	
	# Flag whether to set server defaults
	local DEFAULTS=false
	
	# Server configuration options
	local CONFIG=

	# Server properties options
	local PROPERTIES=
	
	# Switch options
	while (( $# )); do
		case $1 in
			--jar)			JAR_FILE=$2
						shift
			;;
			--defaults)		DEFAULTS=true
			;;
			--configure|--config)	CONFIG="$2"
						shift
			;;
			--properties|--props)	PROPERTIES="$2"
						shift
			;;
			*)			minelib_err UNKNOWN_PARAM $1
		esac
		shift
	done

	# Change to servers directory
	cd $SERVERS_DIR 2> /dev/null || print --fail ACCESS_SRV_DIR_FAILED

	# Check if we specified a server name
	if [ -n "$SERVER_NAME" ]; then
		# Check whether no such file or folder already exists
		if [ -e "$SERVER_NAME" ]; then
			# If there's already such a directory, we assume that the server already exists
			if [ -d "$SERVER_NAME" ]; then
				print --fail SRV_EXISTS
			# If the thing with the server's name is not a directory, we give up :-(
			else
				print --fail FILE_EXISTS
			fi				
		else
			# Create the server
			mkdir "$SERVER_NAME" 2> /dev/null || print --fail CREATE_SRV_DIR_FAILED
			cp "$SERVER_CONFIG" "$SERVER_NAME" 2> /dev/null || print --fail COPY_SKEL_CFG_FAILED

			# Change to new server
			access_server "$SERVER_NAME"

			# If JAR file was not specified, let the user select one iteractively
			if [ -z "$JAR_FILE" ]; then
				if ( jar list ); then
					print SELECT_JAR_FILE
					read JAR_FILE
				# ...and exit if we don't have any
				else
					exit 1
				fi
			fi

			# Set the specified Jar file
			_srvmgr_configure "$SERVER_NAME" "JAR_FILE=$JAR_FILE" > /dev/null
			
			# Set the default configuration if wanted
			$DEFAULTS && _srvmgr_server_defaults
			
			# Set further initial custom configuration if specified
			if [ -n "$CONFIG" ]; then
				_srvmgr_configure "$SERVER_NAME" $CONFIG > /dev/null
			fi

			# Set further initial custom properties if specified
			if [ -n "$PROPERTIES" ]; then
				_srvmgr_properties "$SERVER_NAME" $PROPERTIES > /dev/null
			fi
			
			# Create basic minecraft-specific files
			touch $SERVER_PROPERTIES $SERVER_OP_LIST $SERVER_WHITE_LIST $SERVER_LOG_FILE 2> /dev/null || { 
				cd ..; rm -Rf "$SERVER_NAME"; print --fail CREATE_CFG_FILES_FAILED; 
			}
			mkdir $SERVER_EVENT_HANDLERS_DIR 2> /dev/null || { 
				cd ..; rm -Rf "$SERVER_NAME"; print --fail CREATE_CFG_FILES_FAILED; 
			}

			# Create named pipes for the server
			_srvmgr_mk_fifos 
		fi
	# If no name was specified, we cannot create a server
	else
		print --fail NO_SRV_NAME
	fi		
}

# Remove a server
_srvmgr_remove() {
	local SERVER_NAME="$1"
	shift
	access_server "$SERVER_NAME"

	# As default, minelib_ask again, before removing the server
	local FORCE=false

	# Switch options
	while (( $# ));do
		case $1 in
			--force)	FORCE=true
			;;
			*)		print --error  UNKNOWN_PARAM $1
		esac
		shift
	done

	# Do we really want to remove the server?
	local REMOVE=false

	# Check if we want to remove non-interactively
	if ( $FORCE ); then
		REMOVE=true
	else
		# minelib_ask the user if they really wants to remove the server
		ask REMOVE_SRV && REMOVE=true
	fi

	# If we finally want to remove the server
	if ( $REMOVE ); then
		# Change to server's directory
		access_server "$SERVER_NAME"

		# Stop server if it is running
		_srvmgr_status > /dev/null 2> /dev/null && print --fail SRV_RUNNING

		# Change to parent folder
		cd .. 2> /dev/null || print --fail ACCESS_PARENT_DIR_FAILED

		# Remove stuff
		rm -R "$SERVER_NAME" && print SRV_REMOVED || print --fail SRV_REMOVE_FAILED
	fi
}

# List available servers
_srvmgr_list() {
	# Define tamporary server list	
	local SERVER_LIST="$(mktemp)"
	local RETVAL=1

	# List all folders (servers) in the servers directory
	cd "$SERVERS_DIR" 2> /dev/null && ls_dir 2> /dev/null > "$SERVER_LIST"

	# Iterate over all servers in the list
	while read SERVER_NAME; do
		# We obviously do have servers
		RETVAL=0

		# Print the server's name
		# Bold if verbose
		verbose && echo -en "\033[1m"
		echo -en "$SERVER_NAME"
		very_verbose && echo -e "\033[0m" || echo ""

		# Print some more information in verbose mode
		if ( verbose ); then
			access_server "$SERVER_NAME"
			echo -e " \033[1mCONFIGURATION:\033[0m"
			_srvmgr_configure "$SERVER_NAME"
			if ( very_verbose ); then
				echo -e " \033[1mPROPERTIES:\033[0m"
				_srvmgr_properties "$SERVER_NAME"
			fi
		fi
	done < "$SERVER_LIST"

	return $RETVAL
}

# Rename a server
_srvmgr_rename() {
	local SERVER_NAME="$1"
	shift
	local NEW_NAME="$2"
	
	access_server "$SERVER_NAME"

	if ( srv_status "$SERVER_NAME "> /dev/null 2>/dev/null ); then
		print --fail SRV_RUNNING
	else
		cd ..
		mv "$SERVER_NAME" "$NEW_NAME" 2> /dev/null || print --fail SRV_RENAME_FAILED
	fi
}

# Reset the server
_srvmgr_reset() {
	local SERVER_NAME="$1"
	shift
	access_server "$SERVER_NAME"

	# As default we want to keep our configuration
	local KEEP_CONFIG=false

	# Temporary configuration backup
	local CFG_BACKUP="$(mktemp)"

	# Switch options
	while (( $# )); do
		case $1 in
			--erase-config|-ec|-e)	KEEP_CONFIG=false
			;;
			*)			print --error  UNKNOWN_PARAM $1
		esac
		shift
	done

	# Check if server is still running
	_srvmgr_status > /dev/null 2> /dev/null && print --fail SRV_RUNNING

	access_server "$SERVER_NAME"

	# If we want to keep the configuration, we create a temporal archive from them
	# XXX: Do not mix this up with our server's main backup() function
	if ( $KEEP_CONFIG ); then
		tar czf "$CFG_BACKUP" banned-ips.txt banned-players.txt ops.txt server.properties white-list.txt 2> /dev/null || print --fail CONFIG_BACKUP_FAILED
	fi

	# Remember used jar file
	local JAR_FILE="$(readlink minecraft_server.jar)"
	
	# Clean up the server
	clean "$SERVER_NAME" || print --fail

	# Link back to the active minecraft_server.jar
	ln -s "$JAR_FILE" minecraft_server.jar || print --error RESET_JAR_FAILED
	
	# If we wanted to keep our configuration, we now restore its backup	
	if ( $KEEP_CONFIG ); then
		tar xzf "$CFG_BACKUP" 2> /dev/null || print --fail RESTORE_CONFIG_FAILED
		rm "$CFG_BACKUP" 2> /dev/null
	fi
}

# Configure minecraft server installation and configuration
_srvmgr_configure() {
	local SERVER_NAME="$1"
	shift
	access_server "$SERVER_NAME"

	_srvmgr_configure_print() {		
		# Set temporary configuration file
		local TMP_SERVER_CONFIG="$(mktemp)"

		# Delete comments and empty lines from config file
		extract_data $SERVER_CONFIG > "$TMP_SERVER_CONFIG" 2> /dev/null

		# Print used JAR file
		if ( fileop -b contains "JAR_FILE=" "$1" > /dev/null 2> /dev/null); then
			echo -en "\033[1m"
		fi
		echo -e " JAR_FILE=$(readlink minecraft_server.jar 2> /dev/null)\033[0m"

		# Print configuration file content
                print_file -o " " "$TMP_SERVER_CONFIG" "$1"

		# Remove temp file
		rm -f "$TMP_SERVER_CONFIG" 2> /dev/null
	}
	
	# Set a new active JAR file
	_srvmgr_configure_set_jar() {
		# The second parameter is the JAR file
		local JAR_FILE_NAME="$1"
		local JAR_FILE=""

		# Read JAR file interactively if not specified via a parameter
		if [ -z "$JAR_FILE_NAME" ]; then
			print --fail NO_JAR_SPEC
		fi

		# Check if JAR file is present
		if [ -f "$JAR_FILE_NAME" ]; then
			JAR_FILE="$JAR_FILE_NAME"
		elif [ -f "$JAR_DIR/$JAR_FILE_NAME" ]; then
			JAR_FILE="$JAR_DIR/$JAR_FILE_NAME"
		elif [ -f "$JAR_DIR/$JAR_FILE_NAME.jar" ]; then
			JAR_FILE="$JAR_DIR/$JAR_FILE_NAME.jar"
		else
			print --fail JAR_FILE_NOT_FOUND
		fi

		# Link to new JAR file
		unlink minecraft_server.jar 2> /dev/null
		ln -sf "$JAR_FILE" minecraft_server.jar 2> /dev/null &&	print SRV_RESTART || print --fail SET_JAR_FAILED
	}

	# Print configuration of server, if no arguments are specified
	if [ $# -eq 0 ]; then
		_srvmgr_configure_print
	else
		local ALTERED_VARS="$(mktemp)"

		while (( $# )); do
			local VARIABLE="$1"
			shift

			local -u VAR_NAME="$(echo "$VARIABLE" | cut -d "=" -f 1)"
			local VAR_VAL="$(echo "$VARIABLE" | cut -d "=" -f 2-)"

			# Check if we want to change the JAR file
			if [ "$VAR_NAME" == "JAR_FILE" ]; then
				_srvmgr_configure_set_jar "$VAR_VAL"
				echo "JAR_FILE=$VAR_VAL" >> "$ALTERED_VARS"
			else
				# Change variable
				set_var -u "$VARIABLE" "$SERVER_CONFIG" >> "$ALTERED_VARS"
			fi
		done

		# Print new configuration after modifications
		_srvmgr_configure_print "$ALTERED_VARS"

		rm -f "$ALTERED_VARS" 2> /dev/null
	fi
}

# Configure a server's properties
_srvmgr_properties() {
	local SERVER_NAME="$1"
	shift
	access_server "$SERVER_NAME"

	_srvmgr_properties_print() {		
		# Set temporary properties file
		local TMP_SERVER_PROPERTIES="$(mktemp)"

		# Delete comments and empty lines from config file
		extract_data "$SERVER_PROPERTIES" > "$TMP_SERVER_PROPERTIES" 2> /dev/null

		# Print properties file content
                print_file -o " " "$TMP_SERVER_PROPERTIES" "$1"

		# Remove temp file
		rm -f "$TMP_SERVER_PROPERTIES" 2> /dev/null
	}

	if [ $# -eq 0 ]; then
		_srvmgr_properties_print
	else
		local ALTERED_VARS="$(mktemp)"

		while (( $# )); do
			local VARIABLE="$1"
			shift

			# Change variable and			
			# mark it as altered
			set_var -l "$VARIABLE" "$SERVER_PROPERTIES" >> "$ALTERED_VARS"
		done

		# Print new properties after modifications
		_srvmgr_properties_print "$ALTERED_VARS"
		rm -f "$ALTERED_VARS" 2> /dev/null
	fi
}


####################
# Public functions #
####################

add() {
	_srvmgr_add "$@"
}

remove() {
	_srvmgr_remove "$@"
}

rename() {
	_srvmgr_rename "$@"
}

list() {
	_srvmgr_list "$@"
}

reset() {
	_srvmgr_reset "$@"
}

configure() {
	_srvmgr_configure "$@"
}

properties() {
	_srvmgr_properties "$@"
}

status() {
	_srvmgr_status "$@"
}

############
# Commands #
############

mc_add() {
	_srvmgr_add "$@"
}

mc_remove() {
	_srvmgr_remove "$@"
}

mc_rename() {
	_srvmgr_rename "$@"
}

mc_list() {
	_srvmgr_list "$@"
}

mc_ls() {
	_srvmgr_list "$@"
}

mc_reset() {
	_srvmgr_reset "$@"
}

mc_configure() {
	_srvmgr_configure "$@"
}

mc_properties() {
	_srvmgr_properties "$@"
}

mc_status() {
	_srvmgr_status "$@"
}
