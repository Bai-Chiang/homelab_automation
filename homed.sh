#!/usr/bin/bash

systemctl enable --now systemd-homed.service
read -p "Tell me your username: " USERNAME
read -p "uid: (default 1000)" HOMED_UID
: "${HOMED_UID:=1000}"
read -p "Tell me the filesystem inside your home directory (btrfs or ext4): " FSTYPE
homectl create "$USERNAME" --uid="$HOMED_UID" --member-of=wheel --shell=/bin/bash --storage=luks --fs-type="$FSTYPE"

read -p "Do you want to disable root account? [Y/n] " IS_ROOT_DISABLE
: "${IS_ROOT_DISABLE:=n}"
IS_ROOT_DISABLE="${IS_ROOT_DISABLE,,}"
if [ "$IS_ROOT_DISABLE" = y ] ; then
    # https://wiki.archlinux.org/title/Sudo#Disable_root_login
    echo "Disabling root ..."
    passwd -d root
    passwd -l root
fi
