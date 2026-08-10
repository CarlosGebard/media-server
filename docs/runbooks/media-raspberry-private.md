# Private Raspberry Pi Media Runbook

## Scope

This deployment is private: it does not use router configuration, public DNS,
or public ingress. It coexists with the public media deployment; use the
dedicated `Deploy Media to Raspberry Pi` workflow for this host only.

## One-time Bootstrap

1. Install Docker, Docker Compose, Ansible, Tailscale, and the GitHub Actions
   runner on the Raspberry Pi. Add runner labels `linux`, `arm64`, and `media`.
   Its service account needs passwordless sudo for the Ansible tasks.
2. Join the Raspberry Pi to the tailnet and record `tailscale ip -4`.
3. In the Tailscale DNS admin settings, add a Split DNS nameserver for
   `home.carlosjg` pointing to that Tailscale IPv4 address. Do not add
   public DNS records for this private suffix.
4. Create a private CA offline, issue a wildcard certificate for
   `*.home.carlosjg`, and copy only the issued certificate and key to:

   ```text
   /srv/secrets/tls/home.carlosjg/fullchain.pem
   /srv/secrets/tls/home.carlosjg/privkey.pem
   ```

   Use mode `0600` for the key. Install the CA root certificate on every
   client device that will use the services.
5. Ensure the Tailscale ACL permits intended clients to reach the Raspberry Pi
   on TCP `443` and UDP/TCP `53`. Keep SSH restricted separately.

   The deploy adds equivalent UFW allow rules on `tailscale0` when UFW is
   available; it does not add LAN or public-interface rules.

## Deploy

Run the GitHub Actions workflow **Deploy Media to Raspberry Pi** manually. It
uses the existing Infisical OIDC paths `/global`, `/nextcloud`, and
`/bitwarden`, discovers the local Tailscale IPv4 address, then runs Ansible
against the local Raspberry Pi inventory.

The private names are:

```text
immich.home.carlosjg
couchdb.home.carlosjg
cloud.home.carlosjg
vault.home.carlosjg
```

## Validate

On a Tailscale client:

```bash
dig @<raspberry-tailscale-ip> immich.home.carlosjg
curl --cacert private-ca-root.pem https://immich.home.carlosjg/healthz
```

On the Raspberry Pi:

```bash
sudo dnsmasq --test
docker compose --env-file /srv/secrets/runtime/media.env \
  -f /srv/apps/media/compose.yml \
  -f /srv/apps/media/compose.raspberry.yml ps
```

## Recovery and Rollback

If Split DNS is misconfigured, remove the `home.carlosjg` Split DNS rule
in Tailscale; this changes name resolution only. To stop the private stack,
run `docker compose down` with the two Raspberry Compose files. The public
deployment and its workflow are independent and remain unchanged.
