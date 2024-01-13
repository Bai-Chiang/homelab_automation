Set up [Network UPS Tools](https://wiki.archlinux.org/title/Network_UPS_Tools) (NUT) and configure it to send email notification on Arch Linux.

This role depends on [`roles/msmtp`](/roles/msmtp/).

## Tasks
- Install `nut`.
- Edit `/etc/nut/ups.conf`, `/etc/nut/upsd.users`, `/etc/nut/upsmon.conf`
- Create `/etc/nut/msmtprc` for sending email, use the variables from [`roles/msmtp`](/roles/msmtp).
  Because NUT runs as user `nut` who won't be able to read `/root/.msmtprc` file, create a same file at `/etc/mut/msmtprc` for `nut` user to read.
- Copy [`nut_notify.sh`](templates/nut_notify.sh.j2), which will be executed to send email notification.
- Enable various systemd services.

## Variables
```yaml
# UPS password in the /etc/nut/upsd.conf
# https://wiki.archlinux.org/title/Network_UPS_Tools#upsd_configuration
ups_password: !unsafe 1234546


# Optional variable to fix _Can't claim USB device error_
# https://wiki.archlinux.org/title/Network_UPS_Tools#Can't_claim_USB_device_error
# These are the USB device manufacturer and product IDs.
# You can get these IDs [XXXX:YYYY] by `lsusb` command.
#ups_vender_id: XXXX
#ups_product_id: YYYY
```

