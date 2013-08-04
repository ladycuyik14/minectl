#! /bin/bash

# Manage the JAR files
_jarmgr_jar() {
	# Set temporary repository for re-formatted repo list
	local TMP_REPO_LIST="$(mktemp)"

	##################
	# Repo functions #
	##################

	# Parse the repository list
	_jarmgr_jar_parse_repository() {
		# Check whether the repository list exists
		test -f "$REPO_LIST" 2> /dev/null || print --fail CHECK_REPO_FAILED

		# Re-format repo file
		extract_data "$REPO_LIST" > "$TMP_REPO_LIST" 2> /dev/null || print --fail PARSING_REPO_FAILED
	}

	# Operate on the repository
	_jarmgr_jar_repository() {
		# List available repositories
		_jarmgr_jar_repository_list() {
			# Parse our repo list
			_jarmgr_jar_parse_repository

			# Switch for verbose output
			VERBOSE=false

			while (( $# )); do
				case $1 in
					--verbose|-v)	VERBOSE=true
					;;
				esac
				shift
			done

			echo -e "\033[2mAvailable Repositories:\033[0m\n"

			# Iterate over each repository entry in the repository list
			while read REPO; do
				# The URL to the jar file
				local REPO_URL="$(echo "$REPO" | cut -d "#" -f 1)"
				# A descriptive name of the JAR file
				local REPO_NAME="$(echo "$REPO" | cut -d "#" -f 2)"
				# The name of the file we want to store
				local REPO_FILE="$JAR_DIR/$REPO_NAME.jar"

				echo -e "\033[1m$REPO_NAME\033[0m"
				if ( $VERBOSE ); then
					echo -e "\033[2mURL:\033[0m\t$REPO_URL"
					echo -e "\033[2mFILE:\033[0m\t$REPO_FILE\n"
				fi
			done < $TMP_REPO_LIST
		}

		# Add an entry to the repository
		_jarmgr_jar_repository_add() {
			# Clear variables
			local REPO_URL="$1"
			local REPO_NAME="$2"

			# If nothing has been specified via the parameters, go to interactive mode
			if [ -z "$REPO_URL" ]; then
				print SPEC_REPO_URL
				read REPO_URL
			fi

			if [ -z "$REPO_NAME" ]; then
				print SPEC_REPO_NAME
				read REPO_NAME
			fi

			# Store new repository in file
			echo "$REPO_URL#$REPO_NAME" >> $REPO_LIST 2> /dev/null || print --fail REPO_SAVE_FAILED
		}

		# Remove an entry from the repository list
		_jarmgr_jar_repository_remove() {
			# Only argument: The Repo's name
			local REPO_NAME="$1"

			# If nothing has been specified via the parameters, go to interactive mode
			if [ -z "$REPO_NAME" ]; then
				print SPEC_REPO_NAME
				read REPO_NAME
			fi

			# Remove repo from the list if it is inside
			fileop -e remove  "#$REPO_NAME" "$REPO_LIST" 2> /dev/null
			
		}

		local CMD=$1
		shift
	
		# Switch commands
		case $CMD in
			list|ls)		_jarmgr_jar_repository_list "$@"
			;;
			add)			_jarmgr_jar_repository_add "$@"
			;;
			remove|delete|rm)	_jarmgr_jar_repository_remove "$@"
			;;
			*)			print --fail UNKNOWN_PARAM $CMD
		esac
	}

	# List available JAR files
	_jarmgr_jar_list() {
		# Change to the JARs' folder
		cd $JAR_DIR 2> /dev/null || print --fail ACCESS_JAR_DIR_FAILED

		# Parse arguments
		case $1 in
			-a|--all)	ls --color=auto -alF
			;;
			*)		if ( ! ls --color=auto *.jar 2> /dev/null ); then
						print NO_JAR_FILES
						return 1
					fi
		esac
	}

	# Check if updates for JAR files are available
	_jarmgr_jar_update() {
		# Change to temoprary directory
		cd "$JAR_DIR" > /dev/null 2> /dev/null || print --fail ACCESS_REPO_DIR_FAILED

		# Update counter
		local UPDATES=0

		# Skipping indicator
		local CONTINUE=false

		# Parse our repo list
		_jarmgr_jar_parse_repository

		# Iterate over each repository entry in the repository list
		while read REPO; do
			# The URL to the jar file
			local REPO_URL="$(echo "$REPO" | cut -d "#" -f 1)"
			# A descriptive name of the JAR file
			local REPO_NAME="$(echo "$REPO" | cut -d "#" -f 2)"
			# The name of the file we want to store
			local REPO_FILE="$(date +%s)-$REPO_NAME.jar"
			# The latest file of the repo
			local LATEST_FILE="$REPO_NAME.latest.jar"

			# Check if we specified aonly a selection 
			# of repos and skip unwanted ones
			for WANTED_REPO in "$@"; do
				CONTINUE=true

				if [ "$REPO_NAME" == "$WANTED_REPO" ]; then
					CONTINUE=false
					break
				fi		
			done

			$CONTINUE && continue

			# Download the JAR file
			print -n "Retrieving \033[1m$REPO_NAME\033[0m\t"
			wget -q "$REPO_URL" -O "$REPO_FILE" 2> /dev/null || minelib_fail "[  failed   ]"
		
			# If the file exists...
			if [ -f "$LATEST_FILE" ]; then
				# ...and it is the same, we don't need to update it
				if ( cmp "$LATEST_FILE" "$REPO_FILE" > /dev/null 2> /dev/null ); then
					rm -f "$REPO_FILE" 2> /dev/null
					print "[ up 2 date ]"
					continue
				fi
			fi

			ln -sf "$REPO_FILE" "$LATEST_FILE" 2> /dev/null

			# Increment update counter
			UPDATES=$(($UPDATES+1))

			print "[  updated  ]"
		done < $TMP_REPO_LIST

		# Return value is number of updates
		return $UPDATES
	}

	# Upgrade Minecraft's JAR files
	_jarmgr_jar_upgrade() {
		# Change to temoprary directory
		cd "$JAR_DIR" > /dev/null 2> /dev/null || print --fail ACCESS_REPO_DIR_FAILED

		# Upgrade counter
		local UPGRADES=0

		# Skipping indicator
		local CONTINUE=false

		# Parse our repo list
		_jarmgr_jar_parse_repository

		# Iterate over each repository entry in the repository list
		while read REPO; do
			# The URL to the jar file
			local REPO_URL="$(echo "$REPO" | cut -d "#" -f 1)"
			# A descriptive name of the JAR file
			local REPO_NAME="$(echo "$REPO" | cut -d "#" -f 2)"
			# The latest file of the repo
			local LATEST_FILE="$REPO_NAME.latest.jar"
			# The current file of the repo
			local CURRENT_FILE="$REPO_NAME.jar"
			# Check if we specified aonly a selection 
			# of repos and skip unwanted ones

			for WANTED_REPO in "$@"; do
				CONTINUE=true

				if [ "$REPO_NAME" == "$WANTED_REPO" ]; then
					CONTINUE=false
					break
				fi		
			done

			$CONTINUE && continue
		
			print -n "JAR file from repo \033[1m$REPO_NAME\033[0m "
			# If the file exists...
			if [ -f "$LATEST_FILE" ]; then
				if [ -f "$CURRENT_FILE" ]; then
					# ...and it is the same, we don't need to update it
					if ( cmp "$CURRENT_FILE" "$LATEST_FILE" > /dev/null 2> /dev/null ); then
						echo "is up to date"
						continue
					fi
				fi

				ln -sf "$(basename "$(readlink $LATEST_FILE)")" "$CURRENT_FILE" 2> /dev/null

				# Increment update counter
				UPGRADES=$(($UPGRADES+1))

				print "has been upgraded"
			else
				print JAR_UPDATE
				exit 1
			fi
		done < $TMP_REPO_LIST

		# Return value is number of updates
		return $UPDATES
	}


	local CMD=$1
	shift
	
	# Switch commands
	case $CMD in
		list|ls)		_jarmgr_jar_list "$@"
		;;
		update)			_jarmgr_jar_update "$@"
		;;
		upgrade)		_jarmgr_jar_upgrade "$@"
		;;
		repository|repo)	_jarmgr_jar_repository "$@"
		;;
		*)			print --error UNKNOWN_PARAM $1
					exit 1
	esac
}

####################
# Public functions #
####################

jar() {
	_jarmgr_jar "$@"
}

############
# Commands #
############

mc_jar() {
	_jarmgr_jar "$@"
}
