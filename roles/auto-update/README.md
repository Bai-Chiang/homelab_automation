Update the system and reboot if necessary.

## Variables

### Arch Linux
Update with script [`auto-update.sh`](templates/auto-update.sh.j2).
To enable email notification set up [`roles/msmtp`](/roles/msmtp/).
This will send `pacman -Syu` log to the email address specified in [`roles/msmtp`](/roles/msmtp/).
```yaml
# Auto update time. With format of systemd-timer OnCalendar=
auto_update_time: '01:00:00'
```

### Debian
Set up [unattended upgrades](https://wiki.debian.org/UnattendedUpgrades).
```yaml
# Optional auto update time. With format of systemd-timer OnCalendar=
#auto_update_time: '01:00:00'
```

### Fedora
Set up [dnf-automatic](https://dnf.readthedocs.io/en/latest/automatic.html),
with [`dnf-autoreboot.service`](files/dnf-autoreboot.service) and [`dnf-autoreboot.timer`](templates/dnf-autoreboot.timer.j2)
specify the the reboot time.
```yaml
# Auto reboot time. With format of systemd-timer OnCalendar=
auto_update_time: '01:00:00'
```
