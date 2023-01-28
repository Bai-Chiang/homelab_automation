#!/usr/bin/bash

# set ssh port
echo "ssh port? (22)"
read ssh_port
ssh_port="${ssh_port:-22}"
sed -i "s/^#Port.*/Port ${ssh_port}/" /etc/ssh/sshd_config

if [[ $ssh_port -ne 22 ]] ; then
    dnf install -y policycoreutils-python-utils
    semanage port -a -t ssh_port_t -p tcp $ssh_port

    # add firewall rule
    firewall-cmd --add-port="${ssh_port}/tcp" --permanent
    firewall-cmd --reload
fi

