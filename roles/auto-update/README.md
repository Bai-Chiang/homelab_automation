Update the system and reboot if necessary.

This role depends on [`roles/msmtp`](/roles/msmtp/).

## Variables

### Arch Linux
Update with script [`auto-update.sh`](templates/auto-update.sh.j2).
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
