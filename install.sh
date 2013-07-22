#! /bin/bash

# Minectl installation script
#

# Test if we are root
if [ $EUID -ne 0 ]; then
	echo "You need to be root to run `basename $0`" 1>&2
	exit 1
fi

ROOT_DIR="$(dirname $(realpath $0))"

# Add minectl user
add_user() {
	# Create new minectl user
	if [ `grep -c ^"minecraft:" /etc/passwd` == "0" ]; then
		/usr/sbin/useradd -mUrd /srv/minecraft minecraft
	else
		/usr/sbin/usermod -md /srv/minecraft minecraft
	fi
}

# Remove minectl user
remove_user() {
	userdel $@ minecraft
}

# Install necessary files
install_files() {
	# Change to source directory
	cd $ROOT_DIR/src

	# Install appropriate files
	mkdir -p /usr/local/bin

	install -o root -g root -m 775 -t /usr/local/share/man/man1 ../man/minectl.1
	install -o root -g root -m 775 -t /usr/local/bin bin/*
	install -o root -g root -m 775 -d /usr/local/libexec/minectl
	install -o root -g root -m 775 -t /usr/local/libexec/minectl libexec/*
	install -o minectl -g minectl -m 775 -d /srv/minecraft/lang
	install -o minectl -g minectl -m 775 -t /srv/minecraft/lang lang/*
	install -o minectl -g minectl -m 775 -d /srv/minecraft/jar
	install -o minectl -g minectl -m 775 -d /srv/minecraft/jar/repo
	install -o minectl -g minectl -m 775 -t /srv/minecraft/jar/repo jar/repo/.[^.]*
	install -o minectl -g minectl -m 775 -d /srv/minecraft/backup
	install -o minectl -g minectl -m 775 -d /srv/minecraft/servers
	install -o minectl -g minectl -m 775 -t /srv/minecraft/servers servers/.[^.]*
	install -o minectl -g minectl -m 775 -d /srv/minecraft/event-handlers
	install -o minectl -g minectl -m 775 -t /srv/minecraft/event-handlers event-handlers/*

	# Install system services
	if [ -d /lib/systemd/system ]; then
		install -o root -g root -m 775 -t /lib/systemd/system/ service/"minecraft@.service"
		echo "Systemd service template '/lib/systemd/system/minecraft@.service' installed"
	else
		install -o root -g root -m 775 -t /etc/init.d/ service/minecraft
		echo "Init service '/etc/init.d/minecraft' installed"
	fi

	# Set EN_us as default language
	cd /srv/minecraft/lang
	ln -sf EN_us.lang default.lang

	# Add binaries' path to the users's PATH variable
	if [ -z "`grep "PATH=.*/usr/local/bin" /srv/minecraft/.bashrc`" ]; then
		echo 'export PATH="$PATH:/usr/local/bin"' >> /srv/minecraft/.bashrc
	fi
}

# Uninstall minectl's files and directories
uninstall_files() {
	rm -f /usr/local/bin/{mcpasswd,mcsrv,minectl}
	rm -Rf /usr/local/libexec/minectl
	rm -f /etc/init.d/minecraft
	rm -f "/lib/systemd/system/minecraft@.service"
	rm -f "/lib/systemd/system/minemon@.service"
	rm -f /usr/local/share/man/man1/minectl.1
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
		rm -f /etc/minectl.servers
		rm -f /tmp/minectl.servers
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
