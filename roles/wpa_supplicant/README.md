Set up [wpa_supplicant](https://wiki.archlinux.org/title/Wpa_supplicant) __when using systemd-networkd__.

## Tasks
### Arch Linux
- Install `wpa_supplicant`.
- Copy wpa_supplicant configuration file.
- Enable `wpa_supplicant@interface.service`.

### Fedora
- Install `wpa_supplicant`.
- Create `wpa_supplicant@.service` file.
- Copy wpa_supplicant configuration file.
- Enable `wpa_supplicant@interface.service`.


## Variables
```yaml
# The wpa_supplicant configuration file
wpa_supplicant_config_file: "files/wpa_supplicant.conf"

# wireless NIC name
wireless_interface: wlan0
```

