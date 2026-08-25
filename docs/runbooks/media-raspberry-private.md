# Raspberry Pi Media through Tailscale Serve

## Scope

This deployment is private to the tailnet. It uses its own Compose overlay,
Ansible inventory, and `Deploy Media to Raspberry Pi` action. The public Ubuntu
action and its NGINX/Certbot configuration are not changed by this flow.

## One-time bootstrap

1. Install Docker, Docker Compose, Ansible, Tailscale, and the GitHub Actions
   runner on the Raspberry Pi. Give the runner the labels `linux`, `arm64`, and
   `media`; its service account needs passwordless sudo for the deploy playbook.
2. Join the host to the tailnet and enable HTTPS in the Tailscale admin console
   if it is not already enabled.
3. Confirm `tailscale status` and `tailscale serve status` work as root.
4. Keep persistent application data mounted below `/srv/data/media` on the SSD.

No public DNS, router port forwarding, private CA, split DNS, or dnsmasq setup
is required.

## Deploy

Run **Deploy Media to Raspberry Pi** manually. The action retrieves secrets
from the existing Infisical OIDC paths, renders the Raspberry environment, and
runs the local Ansible inventory. Ansible starts the containers and reconciles
the Tailscale Serve endpoints.

The workflow validates storage before retrieving secrets or changing the
runtime. Choose a storage policy when starting it:

- `require-external` (default) stops unless `/srv` is backed by a filesystem
  different from `/`; use this for the current Raspberry and other hosts with
  real data on an SSD.
- `prefer-external` uses an existing SSD mount but permits `/srv` on the system
  disk; use this for a new host that may not have external storage yet.
- `system-disk` explicitly accepts the filesystem currently backing `/srv`.

`minimum_free_gb` defaults to `20`. The check validates that `/srv` exists, is
writable by root, meets the free-space threshold, and reports the selected
device in the GitHub Actions summary. It never discovers, formats, mounts, or
unmounts disks automatically.

Before choosing `require-external`, mount the intended SSD at `/srv` directly
or through a bind mount whose backing filesystem differs from `/`. Confirm it
with:

```bash
findmnt -T /
findmnt -T /srv
```

Current endpoints:

| Service | Tailnet URL | Local upstream |
| --- | --- | --- |
| CouchDB | `https://raspberry-media-server.tail116b62.ts.net:8443` | `127.0.0.1:5984` |
| Immich | `https://raspberry-media-server.tail116b62.ts.net:8444` | `127.0.0.1:2283` |
| Nextcloud | `https://raspberry-media-server.tail116b62.ts.net:8445` | `127.0.0.1:8081` |
| Bitwarden | `https://raspberry-media-server.tail116b62.ts.net:8446` | `127.0.0.1:8082` |

## Validate

```bash
sudo tailscale serve status
docker compose --env-file /srv/secrets/runtime/media.env \
  -f /srv/apps/media/compose.yml \
  -f /srv/apps/media/compose.raspberry.yml ps
curl -fsS https://raspberry-media-server.tail116b62.ts.net:8444/api/server/ping
```

Application data remains in `/srv/data/media`; redeploying the configuration
does not replace the Immich library, Nextcloud files, CouchDB databases, or
Bitwarden data.

## Recovery

If an endpoint is missing, rerun the Raspberry action or apply the matching
`tailscale serve --bg --https=<port> http://127.0.0.1:<port>` command. Before
removing an endpoint with `tailscale serve`, check `tailscale serve status` so
other services remain published.
