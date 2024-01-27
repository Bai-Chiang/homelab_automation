NAS and file server related tasks for Arch Linux.

[`raid.yml`](tasks/raid.yml) and [`samba.yml`](tasks/samba.yml) should also work on fedora.
Since fedora uses SELinux samba share can only access files with `samba_share_t` context.
[`samba.yml`] will re-label those directories,
but if the directory or its subdirectory is mounted to podman container its context will become `container_file_t` therefore samba won't have permission to access those directories.

This role depends on [`roles/msmtp`](/roles/msmtp/).

## Tasks
- RAID
  - Edit `/etc/crypttab` to decrypt hard drives on boot.
  - Edit `/etc/fstab` create mount points.
- btrfs scrub
  - Enable `btrfs-scrub@.timer` to automatically scrub btrfs volumes.
  - Create [`btrfs_scrub_report.sh`](templates/btrfs_scrub_report.sh.j2) to send scrub result with an email.
    The email is configured with [`roles/msmtp`](/roles/msmtp/).
- [S.M.A.R.T.](https://wiki.archlinux.org/title/S.M.A.R.T.) status
  - Create self-test schedule.
  - Create [`smartd_notify.sh`](templates/smartd_notify.sh.j2) allow smartd send email warnings.
    The email is configured with [`roles/msmtp`](/roles/msmtp/).
- [NFS](https://wiki.archlinux.org/title/NFS) file server
  - Edit `/etc/fstab` and create bind mounts.
  - Edit `/etc/exports`.
  - Set up firewall rules for NFS.
- [Samba](https://wiki.archlinux.org/title/Samba)
  - Edit `/etc/fstab` and create bind mounts.
  - Create `/etc/samba/smb.conf`.
  - Create samba user.
  - Set up samba firewall rules.

## Variables
### RAID
Run [`raid.yml`](tasks/raid.yml) when `{{ crypttab_entries }}` or `{{ fstab_entries }}` is defined.
```yaml
# decrypt disks (optional)
# Skip if not defined
crypttab_entries:

  # device mapper name, the decrypted volume will be /dev/mapper/cryptdisk0
  - device_mapper_name: cryptdisk0

    # here UUID are the UUID of luks volume /dev/sda1
    UUID: 0a659df5-5f33-4fc9-bd20-9f32bc945f19

    # path to decrypt keyfile. Using keyfile allow automatically decrypt drive.
    keyfile: /path/to/keyfile

  # another device mapper name, the decrypted volume will be /dev/mapper/cryptdisk1
  - device_mapper_name: cryptdisk1

    # here UUID are the UUID of luks volume /dev/sda2
    UUID: 3195bd48-c9c5-4523-98f5-f2b14ba481aa

    # path to decrypt keyfile
    keyfile: /path/to/keyfile


# Add entries to /etc/fstab file (optional)
# Skip if not defined
fstab_entries:

  # here UUID are the uuid of decrypted volume /dev/mapper/cryptdisk0
  - device: UUID=f55c9ddb-e245-430a-a902-13f8dd688458

    # The mount point
    mount_point: /home/tux/data

    # filesystem type
    fs: btrfs

    # mount options
    mount_opts: "noatime,compress=zstd:3,space_cache=v2,autodefrag,subvol=@data,nodev,nosuid,noexec"

    # The owner, group and permission for the mount point /home/tux/data
    # The playbook will create the mount point with this permssion if not exist.
    owner: tux
    group: tux
    mode: '0700'


# spindown timeout for the drive (optional)
# Skip if not defined
# The number will pass to hdparm -S
# 242 will set timeout to be 60 min
# https://wiki.archlinux.org/title/Hdparm#Power_management_configuration
hdparm_spindown: 242
```

### btrfs scrub
Set up btrfs scurb when `{{ btrfs_scrub_path }}` is defined.
```yaml
# btrfs scrub paths. Use systemd-escape -p /path/to/mountpoint to get escape path
btrfs_scrub_path:
  - { path: '/', escape: '-' }
  - { path: '/home/tux/data', escape: 'home-tux-data' }

# Schedule btrfs scrub with systemd-timer format
btrfs_scrub_time: 'Sun *-*-* 01:00:00'
```

### S.M.A.R.T.
Set up S.M.A.R.T monitor when `{{ btrfs_scrub_path }}` is defined.
```yaml
# schedule S.M.A.R.T. self-tests
# https://wiki.archlinux.org/title/S.M.A.R.T.#Schedule_self-tests
# smartd will also monitor all drives, and send email notification with information specified in roles/msmtp
# The following example will schedule a short self-test every day at 00:00 to 01:00.
smartd_time: '(S/../.././00)'
```

### NFS
Set up NFS when `{{ nfs_mount_point }}` is defined.
```yaml
# NFS server
# The root directory for NFSv4
nfs_root: /srv/nfs

# NFS mount points
nfs_mount_point:

  # The directory to be shared
  - target: /home/tux/data

    # Bind mount address of the target. See https://wiki.archlinux.org/title/NFS#Server
    bind: /srv/nfs/data

    # options for the mount point, same format as in /etc/exports
    ip_opt: '192.168.122.1(rw,sync,all_squash,anonuid=1000,anongid=1000)' }

# (Optional) Firewall rule, only allow NFS connection from these IP address.
nfs_accept_source_ipv4:
  - 192.168.122.1
```

### Samba
Set up Samba when `{{ smb_share }}` is defined.
```yaml
# Samba share in /etc/samba/smb.conf
# Following example will create a samba share
#    [data]
#       comment = data
#       path = /srv/smb/data
#       valid users = smb_username
#       public = no
#       browseable = no
#       printable = no
#       read only = no
#       create mask = 0664
#       directory mask = 2755
#       force create mode = 0644
#       force directory mode = 2755
# /srv/smb/data is a bind mount, point to /home/tux/data
smb_share:
  - name: data
    comment: data
    path: /home/tux/data        # no trailing slash at the end
    valid_users: smb_username
    read_only: 'no'

# Samba user with UID and password
smb_users:
  - name: smb_username
    passwd: !unsafe pa$sw0r6
    uid: 10001

# (Optional) Firewall rule, only allow Samba connection from these IP address.
samba_accept_source_ipv4:
  - 192.168.122.1
```

