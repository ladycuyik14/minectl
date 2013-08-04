#! /bin/bash

require srvexec

# Create a backup of the server
_backup() {
	local SERVER_NAME="$1"
	shift
	# Set current time and date as default backup name
	local BACKUP_NAME="$SERVER_NAME-`date +%Y.%m.%d-%H.%M`"
	local MESSAGE_PRE=
	local MESSAGE_POST=

	# Process params
	while (( $# )); do
		case $1 in
			--message-pre|--message|-m)	MESSAGE_PRE="$2"
							shift
			;;
			--message-post|-p)		MESSAGE_POST="$2"
							shift
			;;
			*)				print --error UNKNOWN_PARAM $1
		esac
		shift
	done

	access_server "$SERVER_NAME"
		
	# If there is still an argument (or more) remaining
	# it must be the backup's name
	if [ $# -gt 0 ]; then
		BACKUP_NAME="$@"
	fi

	# Display pre-backup message on server
	# XXX: Execute in a shubshell, so that a failure in
	# minectl_server_execute won't affect the backup
	if [ -n "$MESSAGE_PRE" ]; then
		( execute say "$MESSAGE_PRE" )
	fi
	
	# Create the backup as a gzip compressed tar archive, but with the custom *.mcb suffix 
	tar czf "$MC_BACKUP/$BACKUP_NAME.mcb" * > /dev/null 2> /dev/null 
	if [ $? -le 1 ]; then		
		# Display pre-backup message on server
		# XXX: Execute in a shubshell, so that a failure in
		# minectl_server_execute won't affect the backup
		if [ -n "$MESSAGE_POST" ]; then
			( execute say "$MESSAGE_POST" )
		fi

		return 0
	else
		# Display failure message on server, if one type of
		# notification was enabled.
		# XXX: Execute in a shubshell, so that a failure in
		# minectl_server_execute won't affect the backup
		if [ -n "$MESSAGE_PRE" -o -n "$MESSAGE_POST" ]; then
			( execute say "WARNING: Attempted backup failed!" )
		fi

		print --fail BACKUP_FAILED
	fi
}

# Restore the server
_backup_restore() {
	local SERVER_NAME="$1"
	shift
	# Assume latest backup shall be restored
	local BACKUP_NAME="$(ls -tl $MC_BACKUP/$SERVER_NAME-* 2> /dev/null | head -n1 | awk '{print $9}')"
	local BACKUP=""

	# We don't want to minelib_clean the server directory by default
	local CLEAN=false
	
	# Switch options
	while (( $# )); do
		case $1 in
			--clean|-c)		CLEAN=true
			;;
			*)			BACKUP_NAME="$@"
						break
		esac
     		shift
	done

	access_server "$SERVER_NAME"

	# Check whether the backup file is present...
	# ... as the file itself (full or relative file path)...
	if [ -f "$BACKUP_NAME" ]; then
		BACKUP="$BACKUP_NAME"
	# ... or as the file's name located in the backup folder ...
	elif [ -f "$MC_BACKUP/$BACKUP_NAME" ]; then
		BACKUP="$MC_BACKUP/$BACKUP_NAME"
	# ... or finally as the file's name in the backup folder without the suffix specified.
	elif [ -f "$MC_BACKUP/$BACKUP_NAME.mcb" ]; then
		BACKUP="$MC_BACKUP/$BACKUP_NAME.mcb"
	# minelib_fail otherwise
	else
		print --fail BACKUP_NOT_FOUND
	fi

	# Check if server is still running
	status > /dev/null 2> /dev/null && print --fail SRV_RUNNING
			
	# Clean the server if wanted
	if ( $CLEAN ); then
		clean "$SERVER_NAME"
	fi

	# Perform restore
	tar xzf "$BACKUP" > /dev/null 2> /dev/null && return 0 || print --fail RESTORE_FAILED
}

# Set the backup directory
_backup_set_backup_dir() {
	BACKUP_DIR="$@"
	
	if [ -d "$BACKUP_DIR" ]; then
		if ( chmod 770 "$BACKUP_DIR" 2> /dev/null ); then
			cp -au "$MC_BACKUP/*" "$BACKUP_DIR/"
		else
			print --error ACCESS_BACKUP_DIR_FAILED
		fi

		unlink "$MC_BACKUP"
		ln -s "$BACKUP_DIR" "$MC_BACKUP"
	else
		print --error ACCESS_BACKUP_DIR_FAILED
	fi
}

####################
# Public functions #
####################

backup() {
	_backup "$@"
}

restore() {
	_backup_restore "$@"
}

set_backup_dir() {
	_backup_set_backup_dir "$@"
}

############
# Commands #
############

mc_backup() {
	_backup "$@"
}

mc_restore() {
	_backup_restore "$@"
}

mc_set_backup_dir() {
	_backup_set_backup_dir "$@"
}
