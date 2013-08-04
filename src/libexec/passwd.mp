#! /bin/bash

require srvexec

# Manage a server's users
_srvpasswd_passwd() {
	local SERVER_NAME="$1"
	shift

	access_server "$SERVER_NAME"

	# Reload the whitelist
	_srvpasswd_passwd_whitelist_reload() {
		execute whitelist reload > /dev/null 2> /dev/null
	}

	# Check if we are given a valid user name
	_srvpasswd_passwd_valid_user() {
		# minelib_fail if no user name has been given
		if [ -z "$1" ]; then
			print --fail no_user_name
		fi
	}

	# Check whether a certain user is white-listed
	_srvpasswd_passwd_is_whitelisted() {
		_srvpasswd_passwd_valid_user "$1"
		if ( fileop -f -i contains "$1" "$SERVER_WHITE_LIST" > /dev/null 2 /dev/null ); then
			print "User \033[1m$1\033[0m is \033[1mwhitelisted\033[0m on server \033[1m$SERVER_NAME\033[0m"
		else
			print --error "User \033[1m$1\033[0m is \033[1mnot whitelisted\033[0m on server \033[1m$SERVER_NAME\033[0m"
		fi
	}

	# Check whether a certain user is an operator
	_srvpasswd_passwd_is_op() {
		_srvpasswd_passwd_valid_user "$1"
		if ( fileop -f -i contains "$1" "$SERVER_OP_LIST" > /dev/null 2 /dev/null ); then
			print "User \033[1m$1\033[0m is \033[1man operator\033[0m on server \033[1m$SERVER_NAME\033[0m."
		else
			print --error  "User \033[1m$1\033[0m is \033[1mnot an operator\033[0m on server \033[1m$SERVER_NAME\033[0m."
		fi
	}

	# Add a user to the white-list, iff he's not in it yet
	_srvpasswd_passwd_whitelist() {
		_srvpasswd_passwd_valid_user "$1"
		if ( ! _srvpasswd_passwd_is_whitelisted "$1" > /dev/null 2> /dev/null ); then
			if ( fileop add "$1" "$SERVER_WHITE_LIST" > /dev/null 2> /dev/null ); then
				print "User \033[1m$1 whitelisted\033[0m on server \033[1m$SERVER_NAME\033[0m."
			else
				print --error "\033[1mFailed whitelisting $1\033[0m on server \033[1m$SERVER_NAME\033[0m'.\nCheck your configuration."
			fi
		else
			print --error "User \033[1m$1\033[0m is \033[1malready\033[0m whitelisted on server \033[1m$SERVER_NAME\033[0m."
		fi
		
		_srvpasswd_passwd_whitelist_reload
	}

	# Remove user from the white list, iff he's in it
	_srvpasswd_passwd_remove() {
		_srvpasswd_passwd_valid_user "$1"
		if ( _srvpasswd_passwd_is_whitelisted "$1" > /dev/null 2> /dev/null ); then
			_srvpasswd_passwd_deop "$1" 2> /dev/null
			if ( fileop -f -i remove "$1" "$SERVER_WHITE_LIST" > /dev/null 2> /dev/null ); then
				print "User \033[1m$1 removed\033[0m on server \033[1m$SERVER_NAME\033[0m."
			else
				print --error  "\033[1mFailed removing $1\033[0m on server \033[1m$SERVER_NAME\033[0m.\nCheck your configuration."
			fi
		else
			print --error  "User \033[1m$1\033[0m is \033[1mnot whitelisted\033[0m on server \033[1m$SERVER_NAME\033[0m."
		fi

		_srvpasswd_passwd_whitelist_reload
	}

	# Add a user to the operators list
	_srvpasswd_passwd_op() {
		_srvpasswd_passwd_valid_user "$1"
		if ( _srvpasswd_passwd_is_whitelisted "$1" > /dev/null 2> /dev/null ); then
			if ( ! _srvpasswd_passwd_is_op "$1" > /dev/null 2> /dev/null ); then		
				if ( fileop add "$1" "$SERVER_OP_LIST" > /dev/null 2> /dev/null ); then
					# Make the user an operator instantly 
					# on the running server
					execute op "$1" > /dev/null 2> /dev/null

					print "User \033[1m$1\033[0m is \033[1mnow an operator\033[0m on server \033[1m$SERVER_NAME\033[0m."
				else
					print --error "\033[1mFailed opping $1\033[0m on server \033[1m$SERVER_NAME\033[0m.\nCheck your configuration."
				fi
			else
				print --error "User \033[1m$1\033[0m is \033[1malready an operator\033[0m on server \033[1m$SERVER_NAME\033[0m."
			fi
		else
			print --error "User \033[1m$1\033[0m is \033[1mnot whitelisted\033[0m on server \033[1m$SERVER_NAME\033[0m."
		fi
	}

	# Delete a user from the operators list
	_srvpasswd_passwd_deop() {
		_srvpasswd_passwd_valid_user "$1"
		if ( _srvpasswd_passwd_is_op "$1" > /dev/null 2> /dev/null ); then
			if ( fileop -f -i remove "$1" "$SERVER_OP_LIST" > /dev/null 2> /dev/null ); then
				# Deop the user on running server
				execute deop "$1" > /dev/null 2> /dev/null

				print "User \033[1m$1\033[0m is \033[1mno longer an operator\033[0m on server \033[1m$SERVER_NAME\033[0m."
			else
				print --error "\033[1mFailed de-opping $1\033[0m on server \033[1m$SERVER_NAME\033[0m.\nCheck your configuration."
			fi
		else
			print --error "User \033[1m$1\033[0m is \033[1mnot an operator\033[0m on server \033[1m$SERVER_NAME\033[0m."
		fi
	}

	# Print the status of a user
	_srvpasswd_passwd_status() {
		_srvpasswd_passwd_valid_user "$1"
		if ( _srvpasswd_passwd_is_whitelisted "$1" ); then	
			_srvpasswd_passwd_is_op "$1"
		fi
	}

	# Print the status of the whole server mode, white-list and ops-list configuration
	_srvpasswd_passwd_print() {
		# Determine mode
		echo -en "Server \033[1m$SERVER_NAME\033[0m is configured as "
		if ( fileop -f -i contains "online-mode=true" "$SERVER_PROPERTIES" > /dev/null 2> /dev/null ); then
			echo -en "\033[1monline\033[0m"
		else
			echo -en "\033[1moffline\033[0m"
		fi

		# Determine whether white-list is enabled
		echo -n ", its white-list is "
		if ( fileop -f -i contains "white-list=true" "$SERVER_PROPERTIES" > /dev/null 2> /dev/null ); then
			echo -e "\033[1menabled\033[0m."
		else
			echo -e "\033[1mdisabled\033[0m."
		fi	

		# Display users
		echo -e "\n\033[1mWhitelisted users:\033[0m"
		cat "$SERVER_WHITE_LIST" 2> /dev/null
		echo -e "\n\033[1mOperators:\033[0m"
		cat "$SERVER_OP_LIST" 2> /dev/null
		echo ""
	}

	# Lock the server by putting it into online mode and enabling the white-list
	_srvpasswd_passwd_lock() {
		properties "online-mode=true" "white-list=true" > /dev/null && print SRV_LOCKED || print --fail SRV_LOCKING_FAILED
	}

	# Unlock the server by putting it into offline mode and disabling the white-list
	# XXX: This is not recommended. We anyway want to offer this feature for there 
	# might be user that want to run an open game server e.g. on networking parties
	_srvpasswd_passwd_unlock() {
		properties "online-mode=false" "white-list=false" > /dev/null && print SRV_UNLOCKED || print --fail SRV_UNLOCKING_FAILED
	}

	# Error flag
	local ERROR=false
	
	# Switch commands
	while (( $# )); do
		case "$1" in
			reload)			_srvpasswd_passwd_whitelist_reload
			;;
			is-whitelisted)		_srvpasswd_passwd_is_whitelisted $2
						if [ $? -ne 0 ]; then
							ERROR=true
						fi
						shift
			;;
			add|whitelist)		_srvpasswd_passwd_whitelist $2
						shift
			;;
			remove|blacklist)	_srvpasswd_passwd_remove $2
						shift
			;;
			is-op)			_srvpasswd_passwd_is_op $2
						if [ $? -ne 0 ]; then
							ERROR=true
						fi
						shift
			;;
			op)			_srvpasswd_passwd_op $2
						shift
			;;
			deop)			_srvpasswd_passwd_deop $2
								shift
			;;
			status)			_srvpasswd_passwd_status $2
						shift
			;;
			lock)			_srvpasswd_passwd_lock
			;;
			unlock)			_srvpasswd_passwd_unlock
			;;
			""|list|print)		_srvpasswd_passwd_print
			;;
			*)			SERVER_NAME="$1"
						break
		esac
		shift
	done
	
	if ( $ERROR ); then
		return 1
	fi
}


####################
# Public functions #
####################

passwd() {
	_srvpasswd_passwd "$@"
}

############
# Commands #
############

mc_passwd() {
	_srvpasswd_passwd "$@"
}
