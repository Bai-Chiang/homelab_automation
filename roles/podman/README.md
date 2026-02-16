Install [podman](https://wiki.archlinux.org/title/Podman) and set up rootless containers with [Quadlet](https://wiki.archlinux.org/title/Podman#Quadlet).
Since containers are running as non-root user, we can run different container under different user to further isolation.

This role should works on Arch Linux and Fedora.

## Tasks
- Install `podman` and `aardvark-dns` packages.
- [Enable lingering](https://wiki.archlinux.org/title/Systemd/User#Automatic_start-up_of_systemd_user_instances) for each user with `{{ enable_lingering }}` set to `true`.
- Create [`podman-system-prune.service`](templates/podman-system-prune.service.j2) and [`podman-system-prune.timer`](templates/podman-system-prune.timer.j2) to automatically cleanup old images and containers.
- Enable `podman-auto-update.timer` to auto-update containers.


## Variables and examples
- [Syncthing](#Syncthing)
- [Linux ISOs](#Linux-ISOs)
- [Nextcloud AIO, traefik2 reverse proxy and Letsencrypt running as different users](#Nextcloud-AIO-traefik2-reverse-proxy-and-Letsencrypt-running-as-different-users)
- [Grafana and Prometheus monitoring](#Grafana-and-Prometheus-monitoring)

### Syncthing
```yaml
# Time zone
TZ: "UTC"


# Run podman under these users.
# If the user does not exist it will create a new user.
# Here containers are spread under different users as an example, you could
# group them under few users.
# To manage systemd services under different users add `-M username@` to `systemctl` command,
# for example:
#     sudo systemctl --user -M user1@ status xxxx.service
# To view journal under different user with UID 1001
#     sudo journalctl _UID=1001 _SYSTEMD_USER_UNIT=xxxx.service
podman_users:

  # Run Syncthing under user `tux`
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

    # Syncthing Web UI port
    syncthing_webui_port: 8384

    # Path to store syncthing container config
    syncthing_config_dir: "/path/to/container/config/syncthing"

    # List of directories to map into syncthing container
    syncthing_data_dirs:
      - { src: /path/on/host/machine, dest: /path/in/container }
      - { src: /another/path/on/host, dest: /another/path/in/container }
```

### Linux ISOs
```yaml
# Time zone
TZ: "UTC"

podman_users:
  - name: tux1
    uid: 10001
    enable_lingering: true
    podman_system_prune_timer: daily

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

    # transmission Web UI port
    transmission_webui_port: 9091

    # Path to store transmission config
    transmission_config_dir: "/path/to/container/config/transmission"

    # Path to transmission download directory
    transmission_downloads_dir: "/path/to/transmission/download/dir"

    # Optionally, transmisison watch directory
    #transmission_watch_dir: "/path/to/transmission/watch/dir"

    # Optionally, add auth to transmission Web UI
    transmission_user: tux
    transmission_pass: !unsafe mypassword

    # qbittirrent Web UI port
    qbittorrent_webui_port: 8081

    # Path to store qbittorrent config
    qbittorrent_config_dir: "/path/to/container/config/qbittorrent"

    # Path to qbittorrent download directory
    qbittorrent_downloads_dir: "/path/to/qbittorrent/download/dir"
```


### Nextcloud AIO, traefik2 reverse proxy and Letsencrypt running as different users

```yaml
podman_users:

  # Generate letsencrypt certificates under user `tux2` with cloudflare DNS challenge.
  # This way other user can't access your DNS token.
  - name: tux2
    uid: 10002
    enable_lingering: true
    podman_system_prune_timer: daily

    containers:
      - letsencrypt

    # Path to store letsencrypt container config
    letsencrypt_config_dir: "/path/to/container/config/letsencrypt"
    # Also create `/path/to/container/config/letsencrypt/cloudlfare.ini` that
    # contains single line:
    # dns_cloudflare_api_token = xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

    # Email address for letsencrypt expiration notification
    letsencrypt_email: "email@domain.com"

    # Domains contained in letsencrypt certification
    letsencrypt_domains:
      - '*.mydomain.example'


  # Reverse proxy runs under user `tux3`
  - name: tux3
    uid: 10003
    enable_lingering: true
    podman_system_prune_timer: daily

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

    # Allow traefik connect to these local ports on localhost
    # These ports are added to traefik container with options Network=pasta:--tcp-ns
    traefik_forward_ports:
      - 11000
      - 8088

    # Optionally, add tailscale container.
    # After service started, looking for authentication link in the journal
    # sudo journalctl _UID=10003 _SYSTEMD_USER_UNIT=tailscale-traefik.service
    traefik_tailscale_enable: true

    # Path to store tailscale container config (If tailscale enabled)
    traefik_config_dir: "/path/to/container/config/tailscale"

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


  # Nextcloud AIO runs under user `tux4`
  - name: tux4
    uid: 10004
    enable_lingering: true
    podman_system_prune_timer: daily

    containers:
      - nextcloud

    # The Nextcloud Web UI port
    nextcloud_webui_port: 11000

    # The Nextcloud AIO Web admin port
    nextcloud_web_admin_port: 8088

    # Some optional environment variables pass to nextcloud-aio-mastercontainer
    # https://github.com/nextcloud/all-in-one/blob/main/compose.yaml

    # SKIP_DOMAIN_VALIDATION
    nextcloud_skip_domain_validation: true

    # BORG_RETENTION_POLICY
    nextcloud_backup_retention: "--keep-within=7d --keep-weekly=4 --keep-monthly=0"

    # NEXTCLOUD_MEMORY_LIMIT
    nextcloud_memory_limit: 1024M
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
    nextcloud:
      entryPoints:
        - https
      rule: "Host(`nextcloud.mydomain.example`)"
      service: nextcloud
      middlewares:
        - secureHeader
        - nextcloud-redirectregex
      tls:
        options: default
        domains:
          - main: "mydomain.example"
            sans:
              - "*.mydomain.example"

  services:
    nextcloud:
      loadBalancer:
        passHostHeader: true
        servers:
          - url: "http://localhost:11000"

  middlewares:
    secureHeader:
      headers:
        stsSeconds: 15552000
        stsIncludeSubdomains: true
        forceSTSHeader: true
        customFrameOptionsValue: "SAMEORIGIN"
        contentTypeNosniff: true
        browserXssFilter: true
        referrerPolicy: "strict-origin"
        customResponseHeaders:
          X-Robots-Tag: "noindex,nofollow,nosnippet,noarchive,notranslate,noimageindex"

    nextcloud-redirectregex:
      redirectRegex:
        permanent: true
        regex: "https://(.*)/.well-known/(?:card|cal)dav"
        replacement: "https://${1}/remote.php/dav"


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


### Grafana and Prometheus monitoring

```yaml
podman_users:
  - name: tux5
    uid: 10005
    enable_lingering: true
    podman_system_prune_timer: daily

    containers:
      - grafana_prometheus

    # The Grafana Web UI port
    grafana_webui_port: 3000

    # Path to store Grafana and Prometheus container config
    grafana_prometheus_config_dir: "/path/to/container/config/grafana_prometheus"

    # Prometheus.yml file
    # see example at the end
    prometheus_yml: "files/prometheus.yml"

    # If only monitoring CPU and Mem usage set prometheus_host_mode to false
    # If need to query more host info like network traffic, system processes etc,
    # set prometheus_host_mode to true. This will run prometheus-node-exporter container
    # with more privileges.
    prometheus_host_mode: false
```

`prometheus.yml` file example
```yaml
global:
  scrape_interval: 30s
scrape_configs:
 - job_name: 'node'
   scrape_interval: 30s
   static_configs:
    - targets:
      - localhost:9100
      # If `prometheus_host_mode` is set to `true`
      # then use host.containers.internal:9100 to connect to the node-exporter.
      #- host.containers.internal:9100
```

In Grafana connect to Prometheus data source with URL `http://localhost:9090`
