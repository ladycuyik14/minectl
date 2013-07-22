#! /bin/bash

# Minectl installation script
#

MC_USER="minecraft"
MC_HOME="/srv/$MC_USER"

# Test if we are root
if [ $EUID -ne 0 ]; then
	echo "You need to be root to run `basename $0`" 1>&2
	exit 1
fi

ROOT_DIR="$(dirname $(realpath $0))"

# Add "$MC_USER" user
add_user() {
	# Create new "$MC_USER" user
	if [ `grep -c ^""$MC_USER":" /etc/passwd` == "0" ]; then
		/usr/sbin/useradd -mUrd "$MC_HOME" "$MC_USER"
	else
		/usr/sbin/usermod -md "$MC_HOME" "$MC_USER"
	fi
}

# Remove "$MC_USER" user
remove_user() {
	userdel $@ "$MC_USER"
}

# Install necessary files
install_files() {
	# Change to source directory
	cd $ROOT_DIR/src

	# Install appropriate files
	mkdir -p /usr/local/bin

	install -o root -g root -m 775 -t /usr/local/share/man/man1 ../man/minectl.1
	install -o root -g root -m 775 -t /usr/local/bin bin/*
	install -o root -g root -m 775 -d /usr/local/libexec/"$MC_USER"
	install -o root -g root -m 775 -t /usr/local/libexec/"$MC_USER" libexec/*
	install -o "$MC_USER" -g "$MC_USER" -m 775 -d "$MC_HOME"/lang
	install -o "$MC_USER" -g "$MC_USER" -m 775 -t "$MC_HOME"/lang lang/*
	install -o "$MC_USER" -g "$MC_USER" -m 775 -d "$MC_HOME"/jar
	install -o "$MC_USER" -g "$MC_USER" -m 775 -d "$MC_HOME"/jar/repo
	install -o "$MC_USER" -g "$MC_USER" -m 775 -t "$MC_HOME"/jar/repo jar/repo/.[^.]*
	install -o "$MC_USER" -g "$MC_USER" -m 775 -d "$MC_HOME"/.backup
	ln -s "$MC_HOME"/.backup "$MC_HOME"/backup
	install -o "$MC_USER" -g "$MC_USER" -m 775 -d "$MC_HOME"/servers
	install -o "$MC_USER" -g "$MC_USER" -m 775 -t "$MC_HOME"/servers servers/.[^.]*
	install -o "$MC_USER" -g "$MC_USER" -m 775 -d "$MC_HOME"/event-handlers
	install -o "$MC_USER" -g "$MC_USER" -m 775 -t "$MC_HOME"/event-handlers event-handlers/*

	# Install system services
	if [ -d /lib/systemd/system ]; then
		install -o root -g root -m 775 -t /lib/systemd/system/ service/"$MC_USER@.service"
		echo "Systemd service template '/lib/systemd/system/$MC_USER@.service' installed"
	else
		install -o root -g root -m 775 -t /etc/init.d/ service/"$MC_USER"
		echo "Init service '/etc/init.d/$MC_USER' installed"
	fi

	# Set EN_us as default language
	cd "$MC_HOME"/lang
	ln -sf EN_us.lang default.lang

	# Add binaries' path to the users's PATH variable
	if [ -z "`grep "PATH=.*/usr/local/bin" "$MC_HOME"/.bashrc`" ]; then
		echo 'export PATH="$PATH:/usr/local/bin"' >> "$MC_HOME"/.bashrc
	fi
}

# Uninstall minectl's files and directories
uninstall_files() {
	rm -f /usr/local/bin/{mcpasswd,mcsrv,minectl}
	rm -Rf /usr/local/libexec/"$MC_USER"
	rm -f /etc/init.d/"$MC_USER"
	rm -f "/lib/systemd/system/"$MC_USER"@.service"
	rm -f "/lib/systemd/system/minemon@.service"
	rm -f /usr/local/share/man/man1/minectl.1
}

# Disable and stop minectl's services
disable_services() {
	# Uninstall system services
	if [ -d /lib/systemd/system ]; then
		cd /etc/systemd/system/multi-user.target.wants/
		for SERVICE in "$MC_USER"@*; do
			systemctl disable $SERVICE
			systemctl stop $SERVICE
		done
		echo "Systemd services uninstalled"
	else
		chkconfig "$MC_USER" off
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
