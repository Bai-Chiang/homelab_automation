#!/usr/bin/bash

systemctl enable --now systemd-homed.service
read -p "Tell me your username: " username
read -p "uid: (default 1000)" uid
uid="${uid:-1000}"
read -p "Tell me the filesystem inside your home directory (btrfs or ext4): " fstype
homectl create "$username" --uid="$uid" --member-of=wheel --shell=/bin/bash --storage=luks --fs-type="$fstype"

read -p "Do you want to disable root account? [Y/n] " disable_root
disable_root="${disable_root:-n}"
disable_root="${disable_root,,}"
if [[ $disable_root == y ]] ; then
    # https://wiki.archlinux.org/title/Sudo#Disable_root_login
    echo "Disabling root ..."
    passwd -d root
    passwd -l root
fi
