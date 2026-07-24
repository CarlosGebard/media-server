# ADR 0002: Nextcloud in the Media Stack

## Status

Accepted.

## Context

The personal-media stack needs a self-hosted personal cloud reachable at
`cloud.carlosjg.space`. It already owns the public NGINX edge, TLS lifecycle,
deployment workflow, and host storage conventions.

## Decision

Add Nextcloud to the existing `media` Compose stack as `nextcloud`. Use a
dedicated MariaDB service and dedicated Valkey service; do not share Immich's
Postgres or Valkey instances. Run a separate `nextcloud-cron` container and
place all Nextcloud services on an internal network. NGINX receives a fixed
address on that network and is the only public-edge service connected to it.

Persist Nextcloud files under `/srv/data/media/nextcloud/html` and MariaDB
under `/srv/data/media/nextcloud/mariadb`. GitHub Actions obtains the initial
admin and database credentials from Infisical, writes the existing runtime env
file, and Ansible deploys the extended Compose stack.

The persistent HTML directory is owned by `www-data` (`33:33`), and the cron
service waits for the application health check before starting.

SMTP is deliberately excluded.

## Consequences

- Nextcloud can be upgraded and restored independently of Immich data services.
- The new public DNS record must exist before deployment because Certbot extends
  the shared media certificate to include `cloud.carlosjg.space`.
- Nextcloud backups must include both the HTML/data tree and a consistent
  MariaDB dump.
- The private subnet is a contract: `TRUSTED_PROXIES` is restricted to the
  Nextcloud network CIDR, while Docker assigns the NGINX address dynamically.
