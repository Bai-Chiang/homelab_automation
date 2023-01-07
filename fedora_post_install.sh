#!/usr/bin/bash

# set ssh port
echo "ssh port? (22)"
read SSH_PORT
: "${SSH_PORT:=22}"
sed -i "s/^#Port.*/Port ${SSH_PORT}/" /etc/ssh/sshd_config

if [ "$SSH_PORT" -ne 22 ] ; then
    dnf install -y policycoreutils-python-utils
    semanage port -a -t ssh_port_t -p tcp $SSH_PORT

    # add firewall rule
    firewall-cmd --add-port="${SSH_PORT}/tcp" --permanent
    firewall-cmd --reload
fi

