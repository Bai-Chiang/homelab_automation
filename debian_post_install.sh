#!/usr/bin/bash

apt update
apt dist-upgrade

# install firewalld
apt install firewalld

# set ssh port
echo "ssh port? (22)"
read ssh_port
ssh_port="${ssh_port:-22}"
if [[ $ssh_port -ne 22 ]] ; then
    sed -i "s/^#Port.*/Port ${ssh_port}/" /etc/ssh/sshd_config
    sed "/port=/s/port=\"22\"/port=\"${ssh_port}\"/" /usr/lib/firewalld/services/ssh.xml  > /etc/firewalld/services/ssh.xml
    firewall-cmd --reload
fi

read -p "Do you want to set default firewall zone to drop? [y/N] " firewall_drop
firewall_drop="${firewall_drop:-n}"
firewall_drop="${firewall_drop,,}"
if [[ $firewall_drop == y ]] ; then
    firewall-cmd --set-default-zone=drop
fi

echo -e "\nssh allow source ip address (example 192.168.1.0/24), empty to skip"
read ssh_source
if [[ -n $ssh_source ]]; then
    firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source address='${ssh_source}' service name='ssh' accept"
    firewall-cmd --permanent --remove-service ssh
fi
firewall-cmd --reload

# raspberry pi
# create wheel user and disable root user
if [[ ${HOSTNAME:0:3} == rpi ]] ; then
    read -p "Tell me your username: " username
    useradd -m -G wheel sudo "$username"
    passwd "$username"

    echo "Disabling root ..."
    passwd -d root
    passwd -l root

    echo -e "\n\nPlease tell me the hostname:"
    read hostname
    echo "$hostname" > /etc/hostname
fi

