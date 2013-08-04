#! /bin/bash
#
#	minelib - Library for functions frequently used by minectl's plugins
#
#	Version 3.0
#
#	Copyright (C) 2012 Richard Neumann <mail@richard-neumann.de>
#
#	This program is free software: you can redistribute it and/or modify
#	it under the terms of the GNU General Public License as published by
#	the Free Software Foundation, either version 3 of the License, or
#	at your option) any later version.
#
#	This program is distributed in the hope that it will be useful,
#	but WITHOUT ANY WARRANTY; without even the implied warranty of
#	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#	GNU General Public License for more details.
#
#	You should have received a copy of the GNU General Public License
#	along with this program.  If not, see <http://www.gnu.org/licenses/>.

####################
# Global variables #
####################

# Define default minectl user
export MC_USER=minecraft

# Debug level for output detail management
export DEBUG_LEVEL=0

# The current server's name
export SERVER_NAME=""

### Absolute paths ###

# Define home directory
export MC_HOME="/srv/$MC_USER"

# Define backup directory
export MC_BACKUP="$MC_HOME/backup"

# The directory containing the servers
export SERVERS_DIR="$MC_HOME/servers"

# JARs' directory
export JAR_DIR="$MC_HOME/jar"

# Define repository list
export REPO_LIST="$JAR_DIR/.repolist"

# Name of the event scripts
export EVENT_HANDLERS_DIR="$MC_HOME/event-handlers"

# Binaries' directory
export BIN_DIR="/usr/local/bin"

# Library directory
export LIB_DIR="/usr/local/libexec/$MC_USER"

### Paths relative to server ###

# The server's log file
export SERVER_LOG_FILE="./mcsrv.log"

# Define our configuration file name
export SERVER_CONFIG="./.mcsrv.cfg"

# The server's properties file
export SERVER_PROPERTIES="./server.properties"

# The server's white-list
export SERVER_WHITE_LIST="./white-list.txt"

# The server's ops-list
export SERVER_OP_LIST="./ops.txt"

# Name of the event scripts
export SERVER_EVENT_HANDLERS_DIR="./eh.d"

### Pipes ###

# The server's stdin pipe
export SERVER_STDIN="./.stdin"

# The server's stdout pipe
export SERVER_STDOUT="./.stdout"

# The server's stderr pipe
export SERVER_STDERR="./.stderr"

#####################
# Private functions #
#####################

# Test if input is an integer
_minelib_is_int() {
	local INT=$1

	test $INT -eq $INT 2> /dev/null
}

# Display stuff
_minelib_print() {
	local STDERR=false

	local FAIL=false
	local RETVAL=0

	local ON_DEBUG_LEVEL=0
	local ECHO_ARGS=""
	local MESSAGE=""

	while (( $# )); do
		case $1 in
			--stdout|-1)	STDERR=false
			;;
			--stderr|-2)	STDERR=true
			;;
			--level|-l)	ON_DEBUG_LEVEL=$2
					shift
			;;
			--error)	STDERR=true
					if ( _minelib_is_int $2 ); then
						RETVAL=$2
						shift
					else
						RETVAL=1
					fi
			;;
			--fail)		STDERR=true
					FAIL=true
					if ( _minelib_is_int $2 ); then
						RETVAL=$2
						shift
					else
						RETVAL=2
					fi
			;;
			-n)		ECHO_ARGS="$ECHO_ARGS -n"
			;;
			*)		MESSAGE="$*"
					break
		esac
		shift
	done

	# Define debug level, iff undefined
	if [ -z "$DEBUG_LEVEL" ]; then
		echo "ERROR: Debug level undefined!" 1>&2
		return 1
	fi

	# Print if debug level matches
	if [ $ON_DEBUG_LEVEL -le $DEBUG_LEVEL ]; then
		if ( $STDERR ); then
			echo -e $ECHO_ARGS "$MESSAGE" 1>&2
		else
			echo -e $ECHO_ARGS "$MESSAGE"
		fi
	fi

	if ( $FAIL ); then
		exit $RETVAL
	else
		return $RETVAL
	fi
}		

# List (just) directories in the current folder (without sub directories)
_minelib_ls_dir() {
	local DIR="$1"

	if [ -z "$DIR" ]; then
		DIR="./"
	fi

	find "$DIR" -type d 2> /dev/null | grep -E ^"./.[^/]*"$ | sed 's:./::g'
}

# Operate on files
_minelib_fileop() {
	local GREP="grep"
	local IGNORE_CASE=false
	local BEGINS_WITH=false
	local ENDS_WITH=false
	local CMD=

	# Add a string to a file
	_minelib_fileop_add() {
		echo "$PATTERN" >> "$FILE"
		return $?
	}

	# Check if a certain string is contained in a file
	_minelib_fileop_contains() {
		if ( $BEGINS_WITH && $ENDS_WITH ); then
			$GREP -E "^[[:blank:]]*$PATTERN[[:blank:]]*$" "$FILE" 2> /dev/null
		elif ( $BEGINS_WITH ); then
			$GREP "^[[:blank:]]*$PATTERN" "$FILE" 2> /dev/null
		elif ( $ENDS_WITH ); then
			$GREP -E "$PATTERN[[:blank:]]*$" "$FILE" 2> /dev/null
		else
			$GREP "$PATTERN" "$FILE" 2> /dev/null
		fi

		return $?
	}

	# Remove a string that is in the beginning of a file from this file
	_minelib_fileop_remove() {
		while read MATCH; do
			local TMP="`mktemp`"		
			grep -v "$MATCH" "$FILE" > "$TMP" 2> /dev/null
			mv "$TMP" "$FILE"
		done < "$1"
	
		rm -f "$1" 2> /dev/null
	}

	while (( $# ));do
		case $1 in
			--ignore-case|-i)	IGNORE_CASE=true
			;;
			--full-match|-f)	BEGINS_WITH=true
						ENDS_WITH=true
			;;
			--begins-with|-b)	BEGINS_WITH=true
			;;
			--ends-with|-e)		ENDS_WITH=true
			;;
			*)			break
		esac
		shift
	done

	if ( $IGNORE_CASE ); then
		GREP="$GREP -i"
	fi

	CMD="$1"
	local PATTERN="$2"
	local FILE="$3"

	case $CMD in
		contains)	_minelib_fileop_contains
		;;
		remove)		local TMP_FILE="`mktemp`"
				_minelib_fileop_contains > "$TMP_FILE"
				_minelib_fileop_remove "$TMP_FILE"
				rm -f "$TMP_FILE" 2> /dev/null
		;;
		add)		_minelib_fileop_add
		;;
		*)		print --error "Unknown file operation \"CMD\""
	esac
}

# Extract data from a file removing comments and empty lines
_minelib_extract_data() {
	local FILE="$1"

	grep -vE "^[[:blank:]]*$|^[[:blank:]]*#" "$FILE" 2> /dev/null
}

# Ask a question and return 0 on 'yes' or 1 otherwise
_minelib_ask() {
	local USAGE="\
	Usage: ask [The question]\nReturns 0 on \"y\" or 1 else."

	if [ $# -lt 1 ]; then
		echo -e $USAGE
		return 2
	fi

	local MSG="$@"
	local ANSWER=
	local RETVAL=1

	echo -en "$MSG"

	# Read and print answer 
	read ANSWER

	# Check if the answer was 'yes'
	shopt -s nocasematch
	case "$ANSWER" in
		y|yes)	RETVAL=0
	esac
	shopt -u nocasematch

	return $RETVAL
}

# Change the value of a variable inside a file
_minelib_set_var() {
	# Arguments for variable name declaration
	local DECLARE_ARGS=

	# Check if we want to force the variable name to upper or lower case
	case $1 in
		-u|-l)	DECLARE_ARGS="$1"
		shift
	esac
	
	# First argument is the variable declaration 
	# in the shape of <variable>=<value>
	local VAR_DEC="$1"

	# The second argument is the file to operate on
	local FILE="$2"

	local VARIABLE_PURE="$(echo "$VAR_DEC" | cut -d "=" -f 1)"
	local $DECLARE_ARGS VARIABLE="$VARIABLE_PURE"
	local VALUE="$(echo "$VAR_DEC" | cut -d "=" -f 2)"

	# Check if variable is not empty
	if [ -n "$VARIABLE_PURE" ]; then
		# If the variable name preceeds a "-", that means
		# we want the variable to be removed from the file
		if [ -n "$(echo "$VARIABLE_PURE" | grep ^"-" 2> /dev/null)" ]; then
			VARIABLE_PURE="`echo "$VARIABLE_PURE" | cut -d "-" -f 2`"
			_minelib_fileop -b remove "$VARIABLE_PURE" "$FILE" 2> /dev/null
		else
			# Search for variable inside the file	
			local VAR_LINE="`grep ^"$VARIABLE=" "$FILE" 2> /dev/null`"

			# If the variable is in the file, replace it with its new value
			if ( _minelib_fileop -b contains "$VARIABLE=" "$FILE" > /dev/null 2> /dev/null ); then
				sed -i "s|$VAR_LINE|$VARIABLE=$VALUE|" "$FILE" 2> /dev/null
			else
				_minelib_fileop add "$VARIABLE=$VALUE" "$FILE"
			fi

			# Print out the new variable assignment
			echo "$VARIABLE=$VALUE"
		fi
	else
		print --error "No variable specified"
		return 2
	fi
	
	return 0
}

# Print out a file and highlight changes. Usage:
# print_file [--offset, -o <offset>] <file_name> [change_log]
_minelib_print_file() {
	local OFFSET=""

	# Check if we specified an offset
	case $1 in
		--offset|-o)	OFFSET="$2"
				shift 2
	esac

	local FILE="$1"
	local CHANGE_LOG="$2"

        while read LINE; do
		local CONTINUE=false

		if [ -f "$CHANGE_LOG" ]; then
			while read CHANGE; do
				if [ "$CHANGE" == "$LINE" ]; then
					echo -e "$OFFSET\033[1m$LINE\033[0m"
					CONTINUE=true
					continue
				fi
			done < "$CHANGE_LOG"
		fi

		# Skip the output of the line if
		# it has already been highlighted
		$CONTINUE && continue

		echo -e "$OFFSET$LINE"
        done < "$FILE"
}

# Access a server's directory securely
# XXX: Do not just use a simple "cd" statement to change to a server's directory, beacuase
# if a user does not specify a server name by mistake, we will change to $MC_HOME/servers 
# and, if clean is called "clean()", may remove all servers by mistake. That won't be good!
# 'access_server' also makes sure that a certain server (directory) exists
_minelib_access_server() {
	# First parameter is the server name
	# XXX: This variable needs to be global!
	SERVER_NAME="$1"
	
	# Check is server name is not empty
	test -n "$SERVER_NAME" 2> /dev/null || print --fail no_srv_name

	# Check whether server's directory exists
	test -d "$SERVERS_DIR/$SERVER_NAME" 2> /dev/null || print --fail srv_not_existant

	# Check whether server's directory is accessible
	cd "$SERVERS_DIR/$SERVER_NAME" 2> /dev/null || print --fail access_srv_dir_failed

	# Check if we did really change to a subfolder of $MC_HOME/servers
	test "$(dirname $PWD)" == "$SERVERS_DIR" 2> /dev/null || print --fail inside_srv_dir
}

# Clean up the server directory
_minelib_clean() {
	# First parameter is the server name
	SERVER_NAME=$1
	shift

	# Change to server's directory
	_mineclib_access_server "$SERVER_NAME"

	# Remove server directory's content
	rm -R * > /dev/null 2> /dev/null || print --fail srv_clean_failed
}

# Check dependencies
_minelib_checkdeps() {
	true
}

# Test if debug level is verbose
_minelib_verbose() {
	test $DEBUG_LEVEL -ge 1 2> /dev/null
}

# Test if debug level is very verbose
_minelib_very_verbose() {
	test $DEBUG_LEVEL -ge 2 2> /dev/null
}

# Test if a certain function is defined
_minelib_function_exists() {
	local FUNCTION_NAME="$1"

	type $FUNCTION_NAME 2> /dev/null | grep -q ^"$1 ()"
}

###################
# Public funtions #
###################

is_int() {
	_minelib_is_int "$@"
}

print() {
	_minelib_print "$@"
}		

ls_dir() {
	_minelib_ls_dir "$@"
}

fileop() {
	_minelib_fileop "$@"
}

extract_data() {
	_minelib_extract_data "$@"
}

ask() {
	_minelib_ask "$@"
}

set_var() {
	_minelib_set_var "$@"
}

print_file() {
	_minelib_print_file "$@"
}

access_server() {
	_minelib_access_server "$@"
}

clean() {
	_minelib_clean "$@"
}

checkdeps() {
	_minelib_checkdeps "$@"
}

verbose() {
	_minelib_verbose "$@"
}

very_verbose() {
	_minelib_very_verbose "$@"
}

function_exists() {
	_minelib_function_exists "$@"
}

