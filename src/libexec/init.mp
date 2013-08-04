#! /bin/bash

#####################
# Private functions #
#####################

# Initialize the minecraft server installation and configuration after installation
# This should be done interactively
_init_init() {
	# Change to home directory
	cd $MC_HOME 2> /dev/null || print --fail ACCESS_HOME_DIR_FAILED

	# Check if no servers are configured yet
	if ( ! list > /dev/null ); then
		print srv_name
		read SERVER_NAME

		# Check if we already have some JAR files at hand (although this should not be the case)
		if ( jar list ); then
			# minelib_ask the user which jar file shall be used
			print SELECT_JAR_FILE
			read JAR_FILE
		else
			# minelib_ask the user to update the system
			if ( ask jar_update ); then
				minectl_jar update
				minectl_jar upgrade
				minectl_jar list
				minelib_prompt SELECT_JAR_FILE
				read JAR_FILE
			else
				print UPDATE_MANUALLY
				exit 1
			fi
		fi

		# Add the new server
		add "$SERVER_NAME" --jar "$JAR_FILE" 

	# If we already have servers, don't initialize
	else
		print INIT_NOT_REQUIRED
	fi		
}

####################
# Public functions #
####################

init() {
	_init_init "$@"
}

############
# Commands #
############

command_init() {
	_init_init "$@"
}
