#! /bin/bash

# Minectl installation script
#

# Test if we are root
if [ $EUID -ne 0 ]; then
	echo "You need to be root to run `basename $0`" 1>&2
	exit 1
fi

DIR_NAME="$(dirname $(realpath $0))"

# Add minectl user
add_user() {
	# Create new minectl user
	if [ `grep -c ^"minectl:" /etc/passwd` == "0" ]; then
		/usr/sbin/useradd -mUrd /home/minectl minectl
	else
		/usr/sbin/usermod -md /home/minectl minectl
	fi
}

# Remove minectl user
remove_user() {
	userdel $@ minectl
}

# Install necessary files
install_files() {
	# Change to source directory
	cd $DIR_NAME/src

	# Install appropriate files
	mkdir -p /usr/local/bin

	install -o minectl -g minectl -m 775 -t /usr/local/bin mcpasswd mcsrv minectl
	install -o minectl -g minectl -m 775 -d /home/minectl/backup
	install -o minectl -g minectl -m 775 -d /home/minectl/servers
	install -o minectl -g minectl -m 775 -t /home/minectl/servers .mcsrv.cfg 
	install -o minectl -g minectl -m 775 -d /usr/local/libexec/minectl
	install -o minectl -g minectl -m 775 -t /usr/local/libexec/minectl minelib .repolist errcodes
	install -o minectl -g minectl -m 775 -d /usr/local/libexec/minectl/jar
	install -o minectl -g minectl -m 775 -d /usr/local/libexec/minectl/jar-repo

	# Install language files
	cd $DIR_NAME/lang
	install -o minectl -g minectl -m 775 -d /usr/local/libexec/minectl/lang
	install -o minectl -g minectl -m 775 -t /usr/local/libexec/minectl/lang *.lang

	# Set EN_us as default language
	cd /usr/local/libexec/minectl/lang
	ln -sf EN_us.lang default.lang

	# Add binaries' path to the users's PATH variable
	if [ -z "`grep "PATH=.*/usr/local/bin" /home/minectl/.bashrc`" ]; then
		echo 'export PATH="$PATH:/usr/local/bin"' >> /home/minectl/.bashrc
	fi

	# Install system services
	cd $DIR_NAME/service
	if [ -d /lib/systemd/system ]; then
		cp "minecraft@.service" /lib/systemd/system/
		echo "Systemd service template '/lib/systemd/system/minecraft@.service' installed"
	else
		cp minecraft /etc/init.d/
		echo "Init service '/etc/init.d/minecraft' installed"
	fi
}

# Uninstall minectl's files and directories
uninstall_files() {
	rm -f /usr/local/bin{mcpasswd,mcsrv,minectl}
	rm -Rf /usr/local/libexec/minectl
	rm -f /etc/init.d/minecraft
	rm -f "/lib/systemd/system/minecraft@.service"
}

# Disable and stop minectl's services
disable_services() {
	# Uninstall system services
	if [ -d /lib/systemd/system ]; then
		cd /etc/systemd/system/multi-user.target.wants/
		for SERVICE in minecraft@*; do
			systemctl disable $SERVICE
			systemctl stop $SERVICE
		done
		echo "Systemd services uninstalled"
	else
		chkconfig minecraft off
		echo "Init service uninstalled"
	fi
}

# Switch commands
case $1 in
	""|--install)	add_user
			install_files
	;;
	--uninstall)	disable_services
			uninstall_files
			remove_user
	;;
	--purge)	disable_services
			uninstall_files
			remove_user -rf
	;;
	*)		echo "Usage: `basename $0` {--install, --uninstall, --purge}" 1>&2
			exit 1
esac
