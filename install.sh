#! /bin/bash

# Minectl installation script
#

# Test if we are root
if [ $EUID -ne 0 ]; then
	echo "You need to be root to install minectl" 1>&2
	exit 1
fi

# Change to source directory
cd `dirname $0`

# Create new minectl user
if [ `grep -c ^"minectl:" /etc/passwd` == "0" ]; then
	/usr/sbin/useradd -mUrd /home/minectl minectl
else
	/usr/sbin/usermod -md /home/minectl minectl
fi

# Install appropriate files
mkdir -p /usr/local/bin
cd src
install -o minectl -g minectl -m 775 -d /home/minectl/backup
install -o minectl -g minectl -m 775 -d /home/minectl/servers
install -o minectl -g minectl -m 775 -t /home/minectl/servers .mined.cfg 
install -o minectl -g minectl -m 775 -d /usr/local/libexec/minectl
install -o minectl -g minectl -m 775 -d /usr/local/libexec/minectl/jar
install -o minectl -g minectl -m 775 -t /usr/local/libexec/minectl minelib .repolist
install -o minectl -g minectl -m 775 -t /usr/local/bin mcpasswd mcsrv minectl

# Add binaries' path to the users's PATH variable
if [ -z "`grep "PATH=.*/usr/local/bin /home/minectl/.bashrc`" ]; then
	echo 'export PATH="$PATH:/usr/local/bin"' >> /home/minectl/.bashrc
fi

# Install system services
cd ../service
if [ -d /lib/systemd/system ]; then
	cp "minecraft@.service" /lib/systemd/system/
	echo "Systemd service template '/lib/systemd/system/minecraft@.service' installed"
else
	cp minecraft /etc/init.d/
	echo "Init service '/etc/init.d/minecraft' installed"
fi
