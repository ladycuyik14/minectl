#! /bin/bash

##################
# Event handling #
##################

####################
# Public functions #
####################

# Handle event configuration
_event() {
	local SERVER_NAME="$1"
	shift

	access_server "$SERVER_NAME"

	# List events enabled for the current server
	_event_list() {
		case $1 in
			--all)	cd "$EVENT_HANDLERS_DIR"
			;;
			*)	cd "$SERVER_EVENT_HANDLERS_DIR"
		esac

		for EVENT_HANDLER in $(ls *.eh 2> /dev/null); do
			"./$EVENT_HANDLER" info
		done
	}

	# Enable an event on the server
	_event_enable() {
		while (( $# )); do
			EVENT_NAME="$1.eh"

			if [ -f "$EVENT_HANDLERS_DIR/$EVENT_NAME" ]; then
				ln -s "$EVENT_HANDLERS_DIR/$EVENT_NAME" "$SERVER_EVENT_HANDLERS_DIR/$EVENT_NAME" 2> /dev/null
				"$EVENT_HANDLERS_DIR/$EVENT_NAME" info
			else
				print --fail NO_SUCH_EVENT "$1"
			fi

			shift
		done
	}

	# Disable an event on the server
	_event_disable() {
		while (( $# )); do
			EVENT_NAME="$1.eh"

			if [ -f "$SERVER_EVENT_HANDLERS_DIR/$EVENT_NAME" ]; then
				unlink "$SERVER_EVENT_HANDLERS_DIR/$EVENT_NAME" 2> /dev/null
			else
				print --fail NO_SUCH_EVENT $1
			fi

			shift
		done
	}

	local CMD="$1"
	shift

	case $CMD in
		ls|list)	_event_list "$@"
		;;
		enable)		_event_enable "$@"
		;;
		disable)	_event_disable "$@"
		;;
		*)		print --error UNKNOWN_PARAM $1
	esac		
}

####################
# Public functions #
####################

event() {
	_event "$@"
}

############
# Commands #
############

mc_event() {
	_event "$@"
}
