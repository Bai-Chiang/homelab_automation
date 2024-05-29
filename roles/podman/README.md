Install [podman](https://wiki.archlinux.org/title/Podman) and set up rootless containers with [Quadlet](https://wiki.archlinux.org/title/Podman#Quadlet).
Since containers are running as non-root user, we can run different container under different user to further isolation.

This role should works on Arch Linux and Fedora.

## Tasks
- Install `podman` and `aardvark-dns` packages.
- [Enable lingering](https://wiki.archlinux.org/title/Systemd/User#Automatic_start-up_of_systemd_user_instances) for each user with `{{ enable_lingering }}` set to `true`.
- Create [`podman-system-prune.service`](templates/podman-system-prune.service.j2) and [`podman-system-prune.timer`](templates/podman-system-prune.timer.j2) to automatically cleanup old images and containers.
- Enable `podman-auto-update.timer` to auto-update containers.


## Variables and examples
```yaml
# Time zone, used in LinuxServer.io images
TZ: "US/Eastern"


# Run podman under these users.
# If the user does not exist it will create a new user.
# Here containers are spread under different users as an example, you could
# group them under few users.
podman_users:

  # podman containers under user `tux`
  - name: tux

    # UID of the user
    uid: 10000

    # Enable lingering or not
    enable_lingering: true

    # How often to clean up old podman images/containers.
    # This is the OnCalendar= option in podman-system-prune.timer
    podman_system_prune_timer: daily

    # List of containers that will run under user `tux`
    containers:
      - syncthing

    # Path to store syncthing container config
    syncthing_config_dir: "/path/to/container/config/syncthing"

    # List of directories to map into syncthing container
    syncthing_data_dirs:
      - { src: /path/on/host/machine, dest: /path/in/container }
      - { src: /another/path/on/host, dest: /another/path/in/container }


  # podman containers under user `tux1` for generate letsencrypt certificates
  # with cloudflare DNS challenge
  - name: tux1

    # UID of the user
    uid: 10001

    # Enable lingering or not
    enable_lingering: true

    # How often to clean up old podman images/containers.
    # This is the OnCalendar= option in podman-system-prune.timer
    podman_system_prune_timer: daily

    # List of containers that will run under user `tux1`
    containers:
      - letsencrypt

    # Path to store letsencrypt container config
    letsencrypt_config_dir: "/path/to/container/config/letsencrypt"

    # Email address for letsencrypt expiration notification
    letsencrypt_email: "email@domain.com"

    # Domains contained in letsencrypt certification
    letsencrypt_domains:
      - '*.mydomain.example'


  # podman containers under user `tux2` for reverse proxy
  - name: tux2

    # UID of the user
    uid: 10002

    # Enable lingering or not
    enable_lingering: true

    # How often to clean up old podman images/containers.
    # This is the OnCalendar= option in podman-system-prune.timer
    podman_system_prune_timer: daily

    # List of containers that will run under user `tux2`
    containers:
      - traefik

    # Path to store traefik container config
    traefik_config_dir: "/path/to/container/config/traefik"

    # traefik static config file
    # see example at the end
    traefik_static_config: "files/traefik_static_config.yml"

    # traefik dynamic config file
    # see example at the end
    traefik_dynamic_config: "files/traefik_dynamic_config.yml"

    # Path to store letsencrypt container config
    # If letsencrypt and traefik running as different users, traefik won't be
    # able to access letsencrypt certificates, with advantage being traefik
    # also won't have access to your DNS token.
    # To accommodate this we create a copy-ssl.service running as root and
    # only copy generated certificates to `{{ traefik_config_dir }}`.
    letsencrypt_config_dir: "/path/to/container/config/letsencrypt"

    # firewall rules only allow connection from these ipv4 address
    https_accept_source_ipv4:
      - 192.168.1.0/24
      - 192.168.2.1


  # podman containers under user `tux2` for seeding Linux ISOs.
  - name: tux3

    # UID of the user
    uid: 10003

    # Enable lingering or not
    enable_lingering: true

    # How often to clean up old podman images/containers.
    # This is the OnCalendar= option in podman-system-prune.timer
    podman_system_prune_timer: daily

    # List of containers that will run under user `tux3`
    containers:
      - gluetun
      - transmission
      - qbittorrent

    # gluetun VPN provider env variables, here is a vanilla wireguard example.
    # see https://github.com/qdm12/gluetun-wiki/tree/main/setup/providers
    # and https://github.com/qdm12/gluetun-wiki/blob/main/setup/options/port-forwarding.md
    gluetun_vpn_provider_env:
      - VPN_SERVICE_PROVIDER=custom
      - VPN_TYPE=wireguard
      - VPN_ENDPOINT_IP='1.2.3.4'
      - VPN_ENDPOINT_PORT=51820
      - WIREGUARD_PUBLIC_KEY='xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
      - WIREGUARD_PRIVATE_KEY='xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
      - WIREGUARD_ADDRESSES='ipv4/mask,ipv6/mask'
      - VPN_PORT_FORWARDING_LISTENING_PORT='1234'

    # Optionally, enable gluetun http proxy with default HTTPPROXY_LISTENING_ADDRESS (8888)
    # https://github.com/qdm12/gluetun-wiki/blob/main/setup/options/http-proxy.md
    #gluetun_httpproxy: true

    # Path to store transmission config
    transmission_config_dir: "/path/to/container/config/transmission"

    # Path to transmission download directory
    transmission_downloads_dir: "/path/to/transmission/download/dir"

    # Optionally, specify web UI port (default 9091)
    #transmission_web_port: 9091

    # Optionally, transmisison watch directory
    #transmission_watch_dir: "/path/to/transmission/watch/dir"

    # Optionally, add auth to transmission web UI
    #transmission_user: tux
    #transmission_pass: !unsafe mypassword

    # Path to store qbittorrent config
    qbittorrent_config_dir: "/path/to/container/config/qbittorrent"

    # Path to qbittorrent download directory
    qbittorrent_downloads_dir: "/path/to/qbittorrent/download/dir"

    # Optionally, specify web UI port (default 8090)
    #qbittorrent_web_port: 8090
```


Traefik static configuration file example
```yaml
providers:
  file:
    # Don't change this path.
    # The dynamic configuration file specified in Ansible will be copied and
    # mapped to `/etc/traefik/dynamic_conf.yml` inside the container
    filename: "/etc/traefik/dynamic_conf.yml"

# redirect http to https
entryPoints:
  http:
    address: :80
    http:
      redirections:
        entryPoint:
          to: https
          scheme: https

  https:
    address: :443

# Disable SSL verification between traefik and backends
serversTransport:
  insecureSkipVerify: true
```

Traefik dynamic configuration file example
```yaml
http:

  routers:
    syncthing:
      entryPoints:
        - https
      rule: "Host(`syncthing.mydomain.example`)"
      service: syncthing
      middlewares:
        - secureHeader
      tls:
        options: default
        domains:
          - main: "mydomain.example"
            sans:
              - "*.mydomain.example"

  services:
    syncthing:
      loadBalancer:
        passHostHeader: true
        servers:
          - url: "http://10.0.2.2:8384"

  middlewares:
    secureHeader:
      headers:
        stsSeconds: 15552000
        stsIncludeSubdomains: true
        forceSTSHeader: true
        frameDeny: true
        contentTypeNosniff: true
        browserXssFilter: true
        referrerPolicy: "no-referrer"
        customResponseHeaders:
          X-Robots-Tag: "noindex,nofollow,nosnippet,noarchive,notranslate,noimageindex"


tls:
  certificates:
    - certFile: /etc/traefik/ssl/mydomain.example/fullchain.pem
      keyFile: /etc/traefik/ssl/mydomain.example/privkey.pem
      stores:
        - default
  stores:
    default:
      defaultCertificate:
        certFile: /etc/traefik/ssl/mydomain.example/fullchain.pem
        keyFile: /etc/traefik/ssl/mydomain.example/privkey.pem
  options:
    default:
      minVersion: VersionTLS13
      sniStrict: true
```
